#!/usr/bin/env python3
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


def parse_tree(repo, prefix=""):
    raw = git(repo, "ls-tree", "-r", "-l", "-z", "--full-tree", "HEAD")
    items = []
    for record in raw.split(b"\0"):
        if not record:
            continue
        meta, rel = record.split(b"\t", 1)
        fields = meta.decode().split()
        mode, obj_type, oid = fields[:3]
        size = None if len(fields) < 4 or fields[3] == "-" else int(fields[3])
        path = (prefix + rel.decode("utf-8", "surrogateescape")).replace("\\", "/")
        items.append({"path": path, "mode": mode, "object_type": obj_type, "git_oid": oid, "git_size": size})
    return items


def kind_for(entry):
    if entry["object_type"] == "commit":
        return "gitlink"
    if entry["mode"] == "120000":
        return "symlink"
    return "file"


def category_for(path):
    p = pathlib.PurePosixPath(path)
    name = p.name.lower()
    ext = p.suffix.lower()
    if ext in {".p12", ".pfx", ".key", ".pem", ".p8", ".mobileprovision", ".provisionprofile", ".cer", ".crt", ".der", ".p7b", ".p7c"}:
        return "signing material (not read or hashed)"
    if name in {"makefile", "package.swift", "project.yml", "theos.mk"} or ext in {".mk", ".xcconfig", ".pbxproj", ".plist", ".entitlements", ".xcscheme", ".xcworkspacedata", ".yml", ".yaml", ".json", ".toml"}:
        return "build/configuration"
    if ext in {".c", ".h", ".m", ".mm", ".cc", ".cpp", ".cxx", ".swift", ".s", ".asm", ".x", ".xmi", ".inc"}:
        return "source"
    if ext in {".strings", ".stringsdict"} or ".lproj/" in path:
        return "localization"
    if ext in {".png", ".jpg", ".jpeg", ".gif", ".pdf", ".car", ".storyboard", ".xib", ".svg", ".xcassets"}:
        return "resource"
    if ext in {".deb", ".dylib", ".a", ".framework", ".tar", ".zst", ".zip", ".ipa", ".tipa"}:
        return "binary/package"
    if ext in {".md", ".rst", ".txt", ".html"}:
        return "documentation"
    return "other"


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def tree_payload(repo):
    root = pathlib.Path(repo).resolve()
    head = git(root, "rev-parse", "HEAD").decode().strip()
    if head != TARGET_SHA:
        raise SystemExit(f"wrong HEAD: {head}")
    tree_oid = git(root, "rev-parse", "HEAD^{tree}").decode().strip()
    entries = parse_tree(root)
    repos = [{"path": "", "sha": head, "tree": tree_oid, "kind": "root"}]
    status = git(root, "submodule", "status", "--recursive").decode().splitlines()
    for line in status:
        line = line.rstrip("\n")
        if len(line) < 42:
            continue
        marker = line[0]
        sha = line[1:41]
        subpath = line[42:].split(" (", 1)[0]
        if marker != " ":
            raise SystemExit(f"submodule is not at pinned commit: {subpath} ({marker})")
        actual = git(root / subpath, "rev-parse", "HEAD").decode().strip()
        if actual != sha:
            raise SystemExit(f"submodule mismatch {subpath}: expected {sha}, got {actual}")
        sub_tree = git(root / subpath, "rev-parse", "HEAD^{tree}").decode().strip()
        repos.append({"path": subpath, "sha": sha, "tree": sub_tree, "kind": "submodule"})
        entries.extend(parse_tree(root / subpath, subpath.rstrip("/") + "/"))
    by_path = {}
    for item in entries:
        previous = by_path.get(item["path"])
        if previous and previous["object_type"] != item["object_type"]:
            raise SystemExit(f"conflicting tree entries: {item['path']}")
        by_path[item["path"]] = item
    entries = []
    missing = []
    for item in by_path.values():
        full = root / item["path"]
        kind = kind_for(item)
        size = item["git_size"]
        digest = None
        sensitive = full.suffix.lower() in {".p12", ".pfx", ".key", ".pem", ".p8", ".mobileprovision", ".provisionprofile", ".cer", ".crt", ".der", ".p7b", ".p7c"}
        if kind == "file":
            if not full.is_file():
                missing.append(item["path"])
            else:
                size = full.stat().st_size
                if sensitive:
                    item["git_oid"] = None
                    item["content_hash_status"] = "not-read-or-hashed: signing material"
                else:
                    digest = sha256_file(full)
        elif kind == "symlink":
            if not full.is_symlink():
                missing.append(item["path"])
            else:
                if sensitive:
                    item["git_oid"] = None
                    item["content_hash_status"] = "not-read-or-hashed: signing material"
                else:
                    target = os.readlink(full).encode()
                    size = len(target)
                    digest = hashlib.sha256(target).hexdigest()
        item.update({"kind": kind, "bytes": size, "sha256": digest, "category": category_for(item["path"])})
        entries.append(item)
    if missing:
        raise SystemExit("missing checked-out paths: " + ", ".join(missing[:20]))
    paths = {x["path"] for x in entries}
    dirs = set()
    for path in paths:
        parent = pathlib.PurePosixPath(path).parent
        while str(parent) not in {".", ""}:
            dirs.add(str(parent))
            parent = parent.parent
    for path in dirs:
        if path not in paths:
            entries.append({"path": path, "kind": "directory", "mode": "040000", "object_type": "tree", "git_oid": None, "git_size": None, "bytes": None, "sha256": None, "category": "directory"})
    entries.sort(key=lambda x: (x["path"].lower(), x["kind"], x["path"]))
    counts = collections.Counter(x["kind"] for x in entries)
    categories = collections.Counter(x["category"] for x in entries if x["kind"] in {"file", "symlink"})
    return {
        "repository": SOURCE_URL,
        "commit": head,
        "root_tree": tree_oid,
        "submodules": repos[1:],
        "gitmodules_declared_but_not_pinned": ["Application/Dopamine/Dopamine/Exploits/kfd/kfd"],
        "entry_counts": dict(counts),
        "file_categories": dict(categories),
        "entries": entries,
    }


def build_html(data, out):
    embedded = json.dumps(data, ensure_ascii=True, separators=(",", ":")).replace("</", "<\\/")
    project_link = lambda path, label: f'<a class="link" href="{html.escape(path)}">{html.escape(label)}</a>'
    cards = []
    for label, value in (("Файлы", data["entry_counts"].get("file", 0)), ("Каталоги", data["entry_counts"].get("directory", 0)), ("Git submodules", data["entry_counts"].get("gitlink", 0)), ("Корневой commit", data["commit"][:12])):
        cards.append(f'<div class="card"><b>{html.escape(str(value))}</b><span>{html.escape(label)}</span></div>')
    links = [
        ("README.md", "Project status"),
        ("REPOSITORY_INVENTORY.md", "Inventory"),
        ("ARCHITECTURE.md", "Architecture"),
        ("DEPENDENCIES.md", "Dependencies"),
        ("BUILD_SPECIFICATION.md", "Build specification"),
        ("HISTORY_AND_DECISIONS.md", "History"),
        ("TOOLS_AND_SKILLS.md", "Tools and skills"),
        ("ATTEMPTS.md", "Attempts"),
        ("FINAL_VERIFICATION.md", "Verification"),
        ("maps/build-flow-9617d75-verified.png", "Build flow"),
        ("maps/exploit-flow-9617d75-verified.png", "Exploit flow"),
        ("maps/launchd-xpc-flow-9617d75-verified.png", "Launchd/XPC flow"),
        ("evidence/source/graphify/GRAPH_TREE.html", "AST map (partial; see coverage)"),
        ("evidence/source/tree-manifest.tsv", "Download exact manifest"),
    ]
    nav = "".join(project_link(path, label) for path, label in links)
    page = f'''<!doctype html>
<html lang="ru"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Dopamine-roothide exact tree — {data['commit'][:12]}</title>
<style>
:root{{color-scheme:light dark;font:14px/1.45 system-ui,sans-serif;background:#10131a;color:#e8edf6}}body{{max-width:1440px;margin:auto;padding:24px}}h1{{margin:.2em 0}}.muted{{color:#a5b2c5}}.cards{{display:grid;grid-template-columns:repeat(auto-fit,minmax(140px,1fr));gap:10px;margin:18px 0}}.card{{background:#1a2230;border:1px solid #354258;border-radius:10px;padding:12px}}.card b,.card span{{display:block}}.card b{{font-size:18px}}.card span{{color:#a5b2c5}}.toolbar{{display:flex;flex-wrap:wrap;gap:8px;margin:12px 0}}input,button,.link{{background:#1a2230;color:#e8edf6;border:1px solid #46566f;border-radius:8px;padding:8px 10px;text-decoration:none}}input{{flex:1;min-width:220px}}button,.link{{cursor:pointer}}.tree{{padding-left:18px}}.entry{{list-style:none;margin:3px 0}}details>summary{{cursor:pointer}}.name{{font-weight:600}}.meta{{color:#a5b2c5;margin-left:8px;font-size:12px}}.file-row{{display:flex;flex-wrap:wrap;align-items:baseline;gap:4px}}.badges{{color:#91a7c8;font-size:11px}}.path{{overflow-wrap:anywhere}}.warning{{border-left:3px solid #e9a742;padding:8px 12px;background:#211c15}}[hidden]{{display:none!important}}code{{overflow-wrap:anywhere}}@media(max-width:600px){{body{{padding:12px}}}}
</style><body><h1>Dopamine-roothide — точное дерево commit</h1><div class="muted">Источник: <code>{html.escape(SOURCE_URL)}</code> · commit <code>{data['commit']}</code> · tree <code>{data['root_tree']}</code></div>
<div class="cards">{''.join(cards)}</div><p class="warning">Дерево ниже построено из Git objects целевого commit и 7 закреплённых gitlink commits. Graphify AST-карта намеренно отмечена как частичная: она не заменяет эту полную файловую карту.</p>
<div class="toolbar"><input id="search" type="search" placeholder="Фильтр по пути, типу или origin…" aria-label="Filter tree"><button id="expand">Развернуть всё</button><button id="collapse">Свернуть всё</button>{nav}</div>
<div id="root" aria-label="Полное дерево репозитория"></div><script>const DATA={embedded};
const root=document.getElementById('root');const nodes=new Map();const dirs=new Map([['',root]]);const entries=DATA.entries;
for(const x of entries){{if(x.kind==='directory'||x.kind==='gitlink'){{const li=document.createElement('li');li.className='entry '+x.kind;li.dataset.path=x.path;li.dataset.search=(x.path+' '+x.kind+' '+(x.git_oid||'')).toLowerCase();const d=document.createElement('details');const s=document.createElement('summary');s.className='name path';s.textContent=x.path.split('/').pop()+(x.kind==='directory'?'/':' ↳ gitlink '+(x.git_oid||'').slice(0,10));d.appendChild(s);const ul=document.createElement('ul');ul.className='tree';d.appendChild(ul);li.appendChild(d);nodes.set(x.path,li);dirs.set(x.path,ul)}}}}
for(const x of entries){{if(x.kind==='directory'||x.kind==='gitlink')continue;const li=document.createElement('li');li.className='entry file';li.dataset.path=x.path;const origin=x.git_oid?('git '+x.git_oid.slice(0,10)):'';const q=[x.path,x.kind,x.category,origin].join(' ').toLowerCase();li.dataset.search=q;const row=document.createElement('div');row.className='file-row';const name=document.createElement('span');name.className='path';name.textContent=x.path.split('/').pop();const meta=document.createElement('span');meta.className='meta';meta.textContent=[x.kind,x.category,x.bytes===null?'':x.bytes+' B',x.sha256?'sha256 '+x.sha256.slice(0,16):'',origin].filter(Boolean).join(' · ');row.append(name,meta);li.appendChild(row);nodes.set(x.path,li)}}
const all=[...entries].sort((a,b)=>a.path.split('/').length-b.path.split('/').length||a.path.localeCompare(b.path));for(const x of all){{const li=nodes.get(x.path);const parent=x.path.includes('/')?x.path.slice(0,x.path.lastIndexOf('/')):'';const list=dirs.get(parent);if(!list)throw new Error('Missing parent directory: '+parent);list.appendChild(li)}}
document.getElementById('expand').onclick=()=>document.querySelectorAll('details').forEach(x=>x.open=true);document.getElementById('collapse').onclick=()=>document.querySelectorAll('details').forEach(x=>x.open=false);
const search=document.getElementById('search');search.oninput=()=>{{const q=search.value.trim().toLowerCase();const allNodes=[...document.querySelectorAll('.entry')];if(!q){{allNodes.forEach(x=>x.hidden=false);return}}const visible=new Set();for(const n of allNodes)if(n.dataset.search.includes(q)){{let p=n;while(p&&p.classList.contains('entry')){{visible.add(p);p=p.parentElement?.closest('.entry')}}}}for(const n of allNodes)n.hidden=!visible.has(n);for(const n of visible){{const d=n.querySelector(':scope > details');if(d)d.open=true}}}};
</script></body></html>'''
    (out / "repository-map.html").write_text(page, encoding="utf-8")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    out = pathlib.Path(args.out).resolve()
    out.mkdir(parents=True, exist_ok=True)
    data = tree_payload(args.repo)
    (out / "repository-tree.json").write_text(json.dumps(data, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")
    rows = ["path\tkind\tcategory\tmode\tbytes\tgit_oid\tsha256\tcontent_hash_status"]
    for x in data["entries"]:
        rows.append("\t".join(str(x.get(k) if x.get(k) is not None else "") for k in ("path", "kind", "category", "mode", "bytes", "git_oid", "sha256", "content_hash_status")))
    (out / "tree-manifest.tsv").write_text("\n".join(rows) + "\n", encoding="utf-8")
    build_html(data, out.parent)
    source_files = data["entry_counts"].get("file", 0) + data["entry_counts"].get("symlink", 0)
    summary = f'''# Repository inventory\n\n- Source: {SOURCE_URL}\n- Exact commit: `{data['commit']}`\n- Root tree object: `{data['root_tree']}`\n- Root files: {source_files}; directories inferred from committed paths: {data['entry_counts'].get('directory', 0)}; gitlinks: {data['entry_counts'].get('gitlink', 0)}.\n- Pinned submodules: {len(data['submodules'])}; declared but not pinned path: `Application/Dopamine/Dopamine/Exploits/kfd/kfd` (stale `.gitmodules` entry; no gitlink in target tree).\n- Content hashes: SHA-256 recorded for ordinary files and symlink targets; `.p12` signing-material files are inventoried but not opened or hashed.\n- The complete path/metadata table is `evidence/source/tree-manifest.tsv`; exact Git objects and full metadata are in `evidence/source/repository-tree.json`; interactive map is `repository-map.html`.\n\n## Categories\n\n| Category | Entries |\n|---|---:|\n'''
    summary += "".join(f"| {k} | {v} |\n" for k, v in sorted(data["file_categories"].items()))
    (out.parent / "REPOSITORY_INVENTORY.md").write_text(summary, encoding="utf-8")
    print(json.dumps({"commit": data["commit"], "root_tree": data["root_tree"], "counts": data["entry_counts"], "categories": data["file_categories"], "submodules": len(data["submodules"]), "out": str(out)}, indent=2))


if __name__ == "__main__":
    main()
