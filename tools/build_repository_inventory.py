import argparse
import collections
import hashlib
import html
import json
import os
import pathlib
import subprocess

SOURCE_URL = "https://github.com/roothide/Dopamine-roothide"
TARGET_SHA = "9617d75f476423fdfd33477299c8a1349eb6f375"


def git(repo, *args):
    return subprocess.check_output(["git", *args], cwd=repo)


def parse_tree(repo, scope, prefix=""):
    raw = git(repo, "ls-tree", "-r", "-l", "-z", "--full-tree", "HEAD")
    items = []
    for record in raw.split(b"\0"):
        if not record:
            continue
        metadata, raw_path = record.split(b"\t", 1)
        fields = metadata.decode().split()
        mode, obj_type, oid = fields[:3]
        size = None if len(fields) < 4 or fields[3] == "-" else int(fields[3])
        rel = raw_path.decode("utf-8", "surrogateescape")
        items.append({
            "path": (prefix + rel).replace("\\", "/"),
            "scope": scope,
            "relative_path": rel,
            "mode": mode,
            "object_type": obj_type,
            "git_oid": oid,
            "git_size": size,
        })
    return items


def parse_submodules(root):
    repos = [{
        "path": "",
        "sha": git(root, "rev-parse", "HEAD").decode().strip(),
        "tree": git(root, "rev-parse", "HEAD^{tree}").decode().strip(),
        "url": git(root, "remote", "get-url", "origin").decode().strip().removesuffix(".git"),
        "status": " ",
    }]
    for line in git(root, "submodule", "status", "--recursive").decode().splitlines():
        if not line:
            continue
        marker = line[0]
        rest = line[1:].strip()
        sha, path_field = rest.split(" ", 1)
        path = path_field.split(" (", 1)[0].rstrip()
        local = pathlib.Path(root) / path
        actual = git(local, "rev-parse", "HEAD").decode().strip()
        if marker != " " or actual != sha:
            raise RuntimeError(f"submodule not at pinned commit: {path} marker={marker!r} expected={sha} actual={actual}")
        repos.append({
            "path": path,
            "sha": sha,
            "tree": git(local, "rev-parse", "HEAD^{tree}").decode().strip(),
            "url": git(local, "remote", "get-url", "origin").decode().strip().removesuffix(".git"),
            "status": marker,
        })
    return repos


def category(path):
    p = pathlib.PurePosixPath(path)
    ext = p.suffix.lower()
    name = p.name.lower()
    if ext in {".p12", ".pfx", ".key", ".pem", ".p8", ".mobileprovision", ".provisionprofile", ".cer", ".crt", ".der", ".p7b", ".p7c"}:
        return "signing material (not read or hashed)"
    if ext in {".c", ".h", ".m", ".mm", ".cc", ".cpp", ".cxx", ".swift", ".s", ".asm", ".x", ".xmi", ".inc"}:
        return "source"
    if name in {"makefile", "package.swift", "project.yml", "theos.mk"} or ext in {".mk", ".xcconfig", ".pbxproj", ".plist", ".entitlements", ".xcscheme", ".xcworkspacedata", ".yml", ".yaml", ".json", ".toml"}:
        return "build/configuration"
    if ext in {".sh", ".py", ".pl", ".rb", ".applescript"}:
        return "script"
    if ext in {".strings", ".stringsdict"} or ".lproj/" in path:
        return "localization"
    if ext in {".png", ".jpg", ".jpeg", ".gif", ".pdf", ".car", ".storyboard", ".xib", ".svg", ".xcassets"}:
        return "resource"
    if ext in {".deb", ".dylib", ".a", ".framework", ".tar", ".zst", ".zip", ".ipa", ".tipa", ".p12"}:
        return "binary/package/signing material"
    if ext in {".md", ".rst", ".txt", ".html"}:
        return "documentation"
    return "other"


def sha256_path(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def choose_scope(path, repos):
    matches = [r for r in repos if not r["path"] or path == r["path"] or path.startswith(r["path"] + "/")]
    return max(matches, key=lambda r: len(r["path"]))


def tree_data(repo):
    root = pathlib.Path(repo).resolve()
    head = git(root, "rev-parse", "HEAD").decode().strip()
    if head != TARGET_SHA:
        raise RuntimeError(f"wrong target commit: {head}")
    repos = parse_submodules(root)
    if repos[0]["sha"] != TARGET_SHA:
        raise RuntimeError("root checkout is not the requested commit")
    entries = parse_tree(root, "")
    declared_gitmodules = sorted(line.split("=", 1)[1].strip() for line in (root / ".gitmodules").read_text(encoding="utf-8").splitlines() if line.strip().startswith("path ="))
    root_gitlinks = sorted(item["relative_path"] for item in entries if item["object_type"] == "commit")
    gitmodules_validation = {
        "declared_paths": declared_gitmodules,
        "root_tree_gitlinks": root_gitlinks,
        "declared_but_not_pinned": sorted(set(declared_gitmodules) - set(root_gitlinks)),
        "gitlinks_not_declared": sorted(set(root_gitlinks) - set(declared_gitmodules)),
    }
    for sub in repos[1:]:
        entries.extend(parse_tree(root / sub["path"], sub["path"], sub["path"].rstrip("/") + "/"))
    by_path = {}
    for item in entries:
        if item["path"] in by_path:
            raise RuntimeError(f"duplicate tracked path: {item['path']}")
        by_path[item["path"]] = item
    submodule_validation = []
    gitlinks = {(x["scope"], x["relative_path"]): x["git_oid"] for x in entries if x["object_type"] == "commit"}
    for sub in repos[1:]:
        parent_candidates = [r for r in repos if r["path"] != sub["path"] and (not r["path"] or sub["path"].startswith(r["path"] + "/"))]
        parent = max(parent_candidates, key=lambda r: len(r["path"]))
        rel = sub["path"][len(parent["path"].rstrip("/")) + (1 if parent["path"] else 0):]
        expected = gitlinks.get((parent["path"], rel))
        if expected != sub["sha"]:
            raise RuntimeError(f"gitlink mismatch: {sub['path']} parent={parent['path']!r} expected={expected} actual={sub['sha']}")
        submodule_validation.append({"path": sub["path"], "parent": parent["path"], "gitlink_sha": expected, "checked_out_sha": sub["sha"], "match": True})
    missing = []
    for item in entries:
        path = root / item["path"]
        if item["object_type"] == "commit":
            item.update({"kind": "gitlink", "bytes": None, "sha256": None, "content_hash_status": "not-applicable"})
            scope = next((r for r in repos if r["path"] == item["scope"]), repos[0])
            item["origin"] = f"{scope['path'] or 'root'}@{scope['sha']}"
            item["source_url"] = scope["url"] + "/tree/" + scope["sha"] + "/" + item["relative_path"]
        elif item["mode"] == "120000":
            if not path.is_symlink():
                missing.append(item["path"])
                continue
            sensitive = path.suffix.lower() in {".p12", ".pfx", ".key", ".pem", ".p8", ".mobileprovision", ".provisionprofile", ".cer", ".crt", ".der", ".p7b", ".p7c", ".jks", ".keystore"}
            if sensitive:
                item["git_oid"] = None
                item.update({"kind": "symlink", "bytes": item["git_size"], "sha256": None, "content_hash_status": "not-read-or-hashed: signing material"})
            else:
                target = os.readlink(path).encode("utf-8", "surrogateescape")
                item.update({"kind": "symlink", "bytes": len(target), "sha256": hashlib.sha256(target).hexdigest(), "content_hash_status": "hashed-link-target"})
            scope = next(r for r in repos if r["path"] == item["scope"])
            item["origin"] = f"{scope['path'] or 'root'}@{scope['sha']}"
            item["source_url"] = None if sensitive else scope["url"] + "/blob/" + scope["sha"] + "/" + item["relative_path"]
        else:
            if not path.is_file():
                missing.append(item["path"])
                continue
            size = path.stat().st_size
            if item["git_size"] is not None and size != item["git_size"]:
                raise RuntimeError(f"working-copy size differs from Git tree: {item['path']}")
            scope = next(r for r in repos if r["path"] == item["scope"])
            sensitive = path.suffix.lower() in {".p12", ".pfx", ".key", ".pem", ".p8", ".mobileprovision", ".provisionprofile", ".cer", ".crt", ".der", ".p7b", ".p7c", ".jks", ".keystore"}
            if sensitive:
                item["git_oid"] = None
            digest = None if sensitive else sha256_path(path)
            item.update({
                "kind": "file",
                "bytes": size,
                "sha256": digest,
                "content_hash_status": "not-read-or-hashed: signing material" if sensitive else "hashed",
                "origin": f"{scope['path'] or 'root'}@{scope['sha']}",
                "source_url": None if sensitive else scope["url"] + "/blob/" + scope["sha"] + "/" + item["relative_path"],
            })
        item["category"] = category(item["path"])
    if missing:
        raise RuntimeError("missing checkout paths: " + ", ".join(missing[:20]))
    paths = set(by_path)
    directories = set()
    for path in paths:
        parent = pathlib.PurePosixPath(path).parent
        while str(parent) not in {".", ""}:
            directories.add(str(parent))
            parent = parent.parent
    for path in directories - paths:
        scope = choose_scope(path, repos)
        rel = path[len(scope["path"].rstrip("/")) + (1 if scope["path"] else 0):]
        entries.append({
            "path": path,
            "kind": "directory",
            "mode": "040000",
            "object_type": "tree",
            "git_oid": None,
            "git_size": None,
            "bytes": None,
            "sha256": None,
            "category": "directory",
            "scope": scope["path"],
            "relative_path": rel,
            "origin": f"{scope['path'] or 'root'}@{scope['sha']}",
            "source_url": scope["url"] + "/tree/" + scope["sha"] + ("/" + rel if rel else ""),
        })
    entries.sort(key=lambda x: (x["path"].casefold(), x["kind"], x["path"]))
    counts = collections.Counter(x["kind"] for x in entries)
    categories = collections.Counter(x["category"] for x in entries if x["kind"] in {"file", "symlink"})
    root_tree = repos[0]["tree"]
    return {
        "repository": SOURCE_URL,
        "commit": head,
        "root_tree": root_tree,
        "submodules": repos[1:],
        "submodule_validation": submodule_validation,
        "entries": entries,
        "entry_counts": dict(counts),
        "file_categories": dict(categories),
    }


def build_html(data, out):
    embedded = json.dumps(data, ensure_ascii=True, separators=(",", ":")).replace("</", "<\\/")
    cards = []
    for label, value in (("Файлы", data["entry_counts"].get("file", 0)), ("Каталоги", data["entry_counts"].get("directory", 0)), ("Gitlinks", data["entry_counts"].get("gitlink", 0)), ("Submodules", len(data["submodules"]))):
        cards.append(f'<div class="card"><b>{html.escape(str(value))}</b><span>{html.escape(label)}</span></div>')
    links = [
        ("REPOSITORY_INVENTORY.md", "Инвентаризация"),
        ("ARCHITECTURE.md", "Архитектура"),
        ("BUILD_SPECIFICATION.md", "Спецификация сборки"),
        ("HISTORY_AND_DECISIONS.md", "История"),
        ("maps/build-flow-9617d75-verified.png", "Сборка"),
        ("maps/exploit-flow-9617d75-verified.png", "Exploit flow"),
        ("maps/launchd-xpc-flow-9617d75-verified.png", "Launchd/XPC"),
        ("evidence/source/graphify/GRAPH_TREE.html", "AST-карта (частичная)"),
        ("evidence/source/tree-manifest.tsv", "TSV-манифест"),
    ]
    nav = "".join(f'<a class="link" href="{html.escape(p, quote=True)}">{html.escape(label)}</a>' for p, label in links)
    page = f'''<!doctype html><html lang="ru"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Dopamine-roothide exact Git tree — {data['commit'][:12]}</title>
<style>
:root{{color-scheme:light dark;font:14px/1.45 system-ui,sans-serif;background:#10131a;color:#e8edf6}}body{{max-width:1500px;margin:auto;padding:24px}}h1{{margin:.2em 0}}.muted{{color:#a5b2c5}}.cards{{display:grid;grid-template-columns:repeat(auto-fit,minmax(140px,1fr));gap:10px;margin:18px 0}}.card{{background:#1a2230;border:1px solid #354258;border-radius:10px;padding:12px}}.card b,.card span{{display:block}}.card b{{font-size:18px}}.card span{{color:#a5b2c5}}.toolbar{{display:flex;flex-wrap:wrap;gap:8px;margin:12px 0}}input,button,.link{{background:#1a2230;color:#e8edf6;border:1px solid #46566f;border-radius:8px;padding:8px 10px;text-decoration:none}}input{{flex:1;min-width:220px}}button,.link{{cursor:pointer}}.tree{{padding-left:18px}}.entry{{list-style:none;margin:3px 0}}details>summary{{cursor:pointer}}.name{{font-weight:600}}.meta{{color:#a5b2c5;margin-left:8px;font-size:12px}}.row{{display:flex;flex-wrap:wrap;align-items:baseline;gap:4px}}.path{{overflow-wrap:anywhere}}.kind{{color:#9db5d7;font-size:11px}}a.source{{color:#8bc2ff;text-decoration:none}}a.source:hover{{text-decoration:underline}}.warning{{border-left:3px solid #e9a742;padding:8px 12px;background:#211c15}}[hidden]{{display:none!important}}code{{overflow-wrap:anywhere}}@media(max-width:600px){{body{{padding:12px}}}}
</style><body><h1>Dopamine-roothide — точное дерево commit</h1><div class="muted">Источник: <code>{html.escape(SOURCE_URL)}</code> · commit <code>{data['commit']}</code> · root tree <code>{data['root_tree']}</code></div>
<div class="cards">{''.join(cards)}</div><p class="warning">Состав сверён с Git tree целевого commit и 7 закреплёнными submodule commits. AST-карта Graphify неполная из-за неподдерживаемых типов/синтаксиса; полное дерево ниже не зависит от Graphify.</p>
<div class="toolbar"><input id="search" type="search" placeholder="Фильтр: путь, тип, категория, origin…" aria-label="Фильтр дерева"><button id="expand">Развернуть всё</button><button id="collapse">Свернуть всё</button>{nav}<a class="link" href="evidence/source/repository-tree.json" download>JSON</a></div><ul id="root" class="tree" role="tree" aria-label="Полное дерево репозитория"></ul>
<script>const DATA={embedded};const root=document.getElementById('root');const nodes=new Map();const lists=new Map([['',root]]);const entries=DATA.entries;
for(const x of entries){{if(x.kind!=='directory'&&x.kind!=='gitlink')continue;const li=document.createElement('li');li.className='entry '+x.kind;li.dataset.path=x.path;li.dataset.search=[x.path,x.kind,x.origin,x.git_oid].filter(Boolean).join(' ').toLowerCase();const d=document.createElement('details');const s=document.createElement('summary');s.className='name path';s.textContent=x.path.split('/').pop()+(x.kind==='gitlink'?' ↳ gitlink '+(x.git_oid||'').slice(0,10):'/');d.appendChild(s);const ul=document.createElement('ul');ul.className='tree';d.appendChild(ul);li.appendChild(d);nodes.set(x.path,li);lists.set(x.path,ul)}}
for(const x of entries){{if(x.kind==='directory'||x.kind==='gitlink')continue;const li=document.createElement('li');li.className='entry '+x.kind;li.dataset.path=x.path;li.dataset.search=[x.path,x.kind,x.category,x.origin,x.git_oid].filter(Boolean).join(' ').toLowerCase();const row=document.createElement('div');row.className='row';const a=document.createElement('a');a.className='source path';a.href=x.source_url||'#';a.target='_blank';a.rel='noopener';a.textContent=x.path.split('/').pop();const meta=document.createElement('span');meta.className='meta';meta.textContent=[x.kind,x.category,x.bytes===null?'':x.bytes+' B',x.sha256?'sha256 '+x.sha256.slice(0,16):x.content_hash_status||'',x.git_oid?'git '+x.git_oid.slice(0,12):'',x.origin].filter(Boolean).join(' · ');row.append(a,meta);li.appendChild(row);nodes.set(x.path,li)}}
for(const x of entries){{const li=nodes.get(x.path);if(!li)continue;const parent=x.path.includes('/')?x.path.slice(0,x.path.lastIndexOf('/')):'';const list=lists.get(parent);if(!list)throw new Error('Missing parent path: '+parent);list.appendChild(li)}}
document.getElementById('expand').onclick=()=>document.querySelectorAll('details').forEach(d=>d.open=true);document.getElementById('collapse').onclick=()=>document.querySelectorAll('details').forEach(d=>d.open=false);const search=document.getElementById('search');search.oninput=()=>{{const q=search.value.trim().toLowerCase();const all=[...document.querySelectorAll('.entry')];if(!q){{all.forEach(n=>n.hidden=false);return}}const visible=new Set();for(const n of all)if(n.dataset.search.includes(q)){{let p=n;while(p&&p.classList.contains('entry')){{visible.add(p);p=p.parentElement?.closest('.entry')}}}}for(const n of all)n.hidden=!visible.has(n);for(const n of visible){{const d=n.querySelector(':scope > details');if(d)d.open=true}}}};
</script></body></html>'''
    (out / "repository-map.html").write_text(page, encoding="utf-8")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", required=True)
    parser.add_argument("--out", required=True)
    args = parser.parse_args()
    out = pathlib.Path(args.out).resolve()
    root = pathlib.Path(args.repo).resolve()
    out.mkdir(parents=True, exist_ok=True)
    data = tree_data(root)
    (out / "repository-tree.json").write_text(json.dumps(data, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")
    rows = ["path\tkind\tcategory\tmode\tbytes\tgit_oid\tsha256\torigin\tcontent_hash_status"]
    rows.extend("\t".join(str(x.get(k) or "") for k in ("path", "kind", "category", "mode", "bytes", "git_oid", "sha256", "origin", "content_hash_status")) for x in data["entries"])
    (out / "tree-manifest.tsv").write_text("\n".join(rows) + "\n", encoding="utf-8")
    validation = {
        "target_commit": data["commit"],
        "root_tree": data["root_tree"],
        "submodule_count": len(data["submodules"]),
        "submodule_validation": data["submodule_validation"],
        "all_pinned_submodules_match": all(x["match"] for x in data["submodule_validation"]),
        "entry_counts": data["entry_counts"],
        "file_categories": data["file_categories"],
        "all_tracked_regular_files_present": True,
        "signing_material_opened_or_hashed": False,
    }
    (out / "tree-validation.json").write_text(json.dumps(validation, indent=2) + "\n", encoding="utf-8")
    project_root = out.parent.parent
    build_html(data, project_root)
    file_count = data["entry_counts"].get("file", 0) + data["entry_counts"].get("symlink", 0)
    summary = f"""# Repository inventory

- Upstream: {SOURCE_URL}
- Exact commit: `{data['commit']}`; root tree: `{data['root_tree']}`.
- Tracked regular files/symlinks across the root and pinned submodules: {file_count}.
- Directories inferred from committed paths: {data['entry_counts'].get('directory', 0)}.
- Gitlink entries (root plus nested submodules): {data['entry_counts'].get('gitlink', 0)}.
- Recursive pinned submodule checkouts: {len(data['submodules'])}; each checked-out SHA matched the parent tree gitlink.
- SHA-256 is recorded for ordinary files and non-sensitive symlink targets. Signing-sensitive paths remain in the inventory with size only; their contents, hashes, Git object IDs and direct source links are omitted.
- The complete per-path manifest is `evidence/source/tree-manifest.tsv`; full Git and source metadata is `evidence/source/repository-tree.json`; validation is `evidence/source/tree-validation.json`; the interactive tree is `repository-map.html`.

## File categories

| Category | Entries |
|---|---:|
"""
    summary += "".join(f"| {name} | {count} |\n" for name, count in sorted(data["file_categories"].items()))
    (project_root / "REPOSITORY_INVENTORY.md").write_text(summary, encoding="utf-8")
    print(json.dumps({"commit": data["commit"], "root_tree": data["root_tree"], "counts": data["entry_counts"], "categories": data["file_categories"], "submodules": len(data["submodules"]), "out": str(out)}, indent=2))


if __name__ == "__main__":
    main()
