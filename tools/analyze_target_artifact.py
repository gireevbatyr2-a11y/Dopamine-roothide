import argparse
import hashlib
import json
import os
import pathlib
import plistlib
import re
import stat
import subprocess
import zipfile

MAGICS = {
    bytes.fromhex(x)
    for x in ("feedface", "cefaedfe", "feedfacf", "cffaedfe", "cafebabe", "bebafeca", "cafebabf", "bfbafeca")
}

SENSITIVE_SUFFIXES = {".p12", ".pfx", ".key", ".pem", ".p8", ".mobileprovision", ".provisionprofile", ".cer", ".crt", ".der", ".p7b", ".p7c", ".jks", ".keystore", ".spc", ".p7m", ".p7s", ".pkcs12"}


def digest_stream(stream):
    h = hashlib.sha256()
    size = 0
    while True:
        block = stream.read(1024 * 1024)
        if not block:
            break
        h.update(block)
        size += len(block)
    return size, h.hexdigest()


def is_sensitive_path(path):
    return pathlib.PurePosixPath(str(path)).suffix.lower() in SENSITIVE_SUFFIXES


def extract_safe(zf, destination):
    root = destination.resolve()
    destination.mkdir(parents=True, exist_ok=True)
    skipped_sensitive = []
    for info in zf.infolist():
        rel = pathlib.PurePosixPath(info.filename)
        if rel.is_absolute() or any(part in {"", ".", ".."} for part in rel.parts):
            raise RuntimeError(f"unsafe archive path: {info.filename!r}")
        target = destination.joinpath(*rel.parts)
        if not target.resolve().is_relative_to(root):
            raise RuntimeError(f"archive path escapes extraction root: {info.filename!r}")
        mode = (info.external_attr >> 16) & 0xFFFF
        if info.is_dir():
            target.mkdir(parents=True, exist_ok=True)
            continue
        if is_sensitive_path(info.filename):
            skipped_sensitive.append(info.filename)
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        data = zf.read(info)
        if stat.S_ISLNK(mode):
            link = os.fsdecode(data)
            resolved = (target.parent / link).resolve()
            if not resolved.is_relative_to(root):
                raise RuntimeError(f"symlink escapes extraction root: {info.filename!r} -> {link!r}")
            if target.exists() or target.is_symlink():
                target.unlink()
            target.symlink_to(link)
        else:
            target.write_bytes(data)
            permissions = stat.S_IMODE(mode)
            if permissions:
                target.chmod(permissions)
    return skipped_sensitive


def parse_ipsw_output(result):
    record = {"returncode": result.returncode, "stderr": result.stderr.strip()}
    if result.returncode == 0:
        try:
            parsed = json.loads(result.stdout)
            loads = parsed.get("loads", [])
            record.update({
                "header": parsed.get("header", {}),
                "uuids": [x for x in loads if x.get("load_cmd") == "LC_UUID"],
                "build_versions": [x for x in loads if x.get("load_cmd") in {"LC_BUILD_VERSION", "LC_VERSION_MIN_IPHONEOS"}],
                "code_signatures": [x for x in loads if x.get("load_cmd") == "LC_CODE_SIGNATURE"],
                "encryption": [x for x in loads if x.get("load_cmd", "").startswith("LC_ENCRYPTION_INFO")],
                "load_command_count": len(loads),
            })
        except json.JSONDecodeError:
            record["stdout"] = result.stdout[:4000]
    return record


def run_ipsw(binary, path, magic, file_type):
    fat_magics = {bytes.fromhex(x) for x in ("cafebabe", "bebafeca", "cafebabf", "bfbafeca")}
    is_fat = magic in fat_magics
    arches = list(dict.fromkeys(re.findall(r"arm64e|arm64", file_type.lower()))) if is_fat else [None]
    if is_fat and not arches:
        return {"returncode": 1, "stderr": "file(1) did not report universal slice names", "slices": []}
    slices = []
    for arch in arches:
        cmd = [binary, "macho", "info", "--json"]
        if arch:
            cmd.extend(["--arch", arch])
        cmd.append(str(path))
        result = subprocess.run(cmd, text=True, capture_output=True, timeout=60)
        parsed = parse_ipsw_output(result)
        parsed["requested_arch"] = arch
        slices.append(parsed)
    record = {
        "returncode": 0 if all(x["returncode"] == 0 for x in slices) else 1,
        "stderr": "; ".join(x["stderr"] for x in slices if x.get("stderr")),
        "architectures": [x.get("requested_arch") or x.get("header", {}).get("subcpu") for x in slices],
        "slices": slices,
    }
    if slices:
        first = slices[0]
        for key in ("header", "uuids", "build_versions", "code_signatures", "encryption", "load_command_count"):
            if key in first:
                record[key] = first[key]
    record["total_load_command_count"] = sum(x.get("load_command_count", 0) for x in slices)
    return record


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--ipa", required=True)
    parser.add_argument("--tipa", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--ipsw", required=True)
    args = parser.parse_args()
    out = pathlib.Path(args.out).resolve()
    ipa = pathlib.Path(args.ipa).resolve()
    tipa = pathlib.Path(args.tipa).resolve()
    out.mkdir(parents=True, exist_ok=True)
    summary = {"artifacts": [], "comparison": {}, "members": [], "machos": []}
    archives = {}
    for path in (ipa, tipa):
        with path.open("rb") as f:
            size, sha = digest_stream(f)
        with zipfile.ZipFile(path) as zf:
            members = []
            for info in zf.infolist():
                sensitive = not info.is_dir() and is_sensitive_path(info.filename)
                if info.is_dir():
                    digest = ""
                    actual_size = 0
                    content_hash_status = "directory"
                elif sensitive:
                    digest = ""
                    actual_size = info.file_size
                    content_hash_status = "not-read-or-hashed: signing material"
                else:
                    with zf.open(info) as stream:
                        actual_size, digest = digest_stream(stream)
                    content_hash_status = "hashed"
                mode = (info.external_attr >> 16) & 0xFFFF
                members.append({
                    "path": info.filename,
                    "size": actual_size,
                    "sha256": digest,
                    "crc32": "" if sensitive else f"{info.CRC:08x}",
                    "compression": info.compress_type,
                    "unix_mode": oct(mode),
                    "symlink": stat.S_ISLNK(mode),
                    "sensitive": sensitive,
                    "content_hash_status": content_hash_status,
                })
            sensitive_paths = [x["path"] for x in members if x["sensitive"]]
            archives[path.name] = members
            summary["artifacts"].append({
                "path": str(path),
                "bytes": size,
                "sha256": sha,
                "zip_members": len(members),
                "uncompressed_bytes": sum(x["size"] for x in members),
                "sensitive_member_count": len(sensitive_paths),
                "sensitive_member_paths": sensitive_paths,
                "zip_test": "PASS for all non-sensitive members; signing-material contents skipped" if sensitive_paths else "PASS for all files",
            })
    by_name = {a["path"].split("/")[-1]: a for a in summary["artifacts"]}
    ipa_members = archives[ipa.name]
    tipa_members = archives[tipa.name]
    summary["comparison"] = {
        "same_sha256": by_name[ipa.name]["sha256"] == by_name[tipa.name]["sha256"],
        "same_member_count": len(ipa_members) == len(tipa_members),
        "same_member_paths_and_sizes": [(x["path"], x["size"]) for x in ipa_members] == [(x["path"], x["size"]) for x in tipa_members],
        "same_non_sensitive_member_paths_and_hashes": [(x["path"], x["sha256"]) for x in ipa_members if not x["sensitive"]] == [(x["path"], x["sha256"]) for x in tipa_members if not x["sensitive"]],
        "same_sensitive_member_pathset": [x["path"] for x in ipa_members if x["sensitive"]] == [x["path"] for x in tipa_members if x["sensitive"]],
    }
    summary["members"] = ipa_members
    tree_rows = ["path\tbytes\tsha256\tcrc32\tcompression\tunix_mode\tsymlink\tsensitive\tcontent_hash_status"]
    tree_rows.extend("\t".join(str(x[k]) for k in ("path", "size", "sha256", "crc32", "compression", "unix_mode", "symlink", "sensitive", "content_hash_status")) for x in ipa_members)
    (out / "ipa-members.tsv").write_text("\n".join(tree_rows) + "\n", encoding="utf-8")
    extract_dir = out / "ipa-extracted"
    if extract_dir.exists():
        import shutil
        shutil.rmtree(extract_dir)
    with zipfile.ZipFile(ipa) as zf:
        summary["sensitive_paths_not_extracted"] = extract_safe(zf, extract_dir)
    app = extract_dir / "Payload" / "Dopamine.app"
    info_path = app / "Info.plist"
    info = plistlib.loads(info_path.read_bytes()) if info_path.exists() else {}
    summary["app_info"] = {
        key: info.get(key) for key in ("CFBundleIdentifier", "CFBundleExecutable", "CFBundleShortVersionString", "CFBundleVersion", "MinimumOSVersion", "DTPlatformVersion", "DTSDKName", "LSRequiresIPhoneOS")
    }
    frameworks = sorted(p.name for p in (app / "Frameworks").iterdir() if p.is_dir()) if (app / "Frameworks").exists() else []
    summary["frameworks"] = frameworks
    for path in sorted(app.rglob("*")):
        if is_sensitive_path(path) or not path.is_file() or path.is_symlink():
            continue
        try:
            with path.open("rb") as f:
                magic = f.read(4)
        except OSError:
            continue
        if magic not in MAGICS:
            continue
        file_result = subprocess.run(["file", "-b", str(path)], text=True, capture_output=True, timeout=10)
        file_type = file_result.stdout.strip()
        info_record = run_ipsw(args.ipsw, path, magic, file_type)
        with path.open("rb") as f:
            size, sha = digest_stream(f)
        summary["machos"].append({
            "path": path.relative_to(app).as_posix(),
            "bytes": size,
            "sha256": sha,
            "file_type": file_result.stdout.strip(),
            "ipsw": info_record,
        })
    (out / "macho-inventory.json").write_text(json.dumps(summary["machos"], indent=2, ensure_ascii=True) + "\n", encoding="utf-8")
    rows = ["path\tbytes\tsha256\tfile_type\tslices\ttype\ttotal_load_commands\tipsw_status"]
    for item in summary["machos"]:
        header = item["ipsw"].get("header", {})
        slice_arches = ",".join(f"{s.get('header', {}).get('cpu', '')}/{s.get('header', {}).get('subcpu', '')}" for s in item["ipsw"].get("slices", []))
        rows.append("\t".join(str(x) for x in (
            item["path"], item["bytes"], item["sha256"], item["file_type"], slice_arches, header.get("type", ""), item["ipsw"].get("total_load_command_count", ""), item["ipsw"].get("returncode", "")
        )))
    (out / "macho-inventory.tsv").write_text("\n".join(rows) + "\n", encoding="utf-8")
    main_binary = app / str(info.get("CFBundleExecutable", "Dopamine"))
    ent = subprocess.run([args.ipsw, "macho", "info", "--ent", str(main_binary)], text=True, capture_output=True, timeout=60)
    (out / "main-entitlements.txt").write_text(ent.stdout + ("\n" + ent.stderr if ent.stderr else ""), encoding="utf-8")
    summary["entitlements_status"] = {"returncode": ent.returncode, "stderr": ent.stderr.strip()}
    summary["macho_count"] = len(summary["machos"])
    summary["member_count"] = len(summary["members"])
    summary.pop("members")
    (out / "artifact-analysis.json").write_text(json.dumps(summary, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")
    print(json.dumps({k: summary[k] for k in ("artifacts", "comparison", "app_info", "frameworks", "macho_count", "member_count", "entitlements_status")}, indent=2))


if __name__ == "__main__":
    main()
