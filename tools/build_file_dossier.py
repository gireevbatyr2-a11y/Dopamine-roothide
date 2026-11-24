import collections
import csv
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCE = ROOT / "evidence/source/upstream-9617d75f476423fdfd33477299c8a1349eb6f375"
EVIDENCE = ROOT / "evidence/source"
MANIFEST = EVIDENCE / "tree-manifest.tsv"
GRAPH = EVIDENCE / "graphify/graph.json"
OUTPUT = EVIDENCE
SENSITIVE_SUFFIXES = {".p12", ".pfx", ".key", ".pem", ".p8", ".mobileprovision", ".provisionprofile", ".cer", ".crt", ".der", ".p7b", ".p7c", ".jks", ".keystore"}
TEXT_EXTENSIONS = {".c", ".h", ".m", ".mm", ".cc", ".cpp", ".cxx", ".swift", ".s", ".asm", ".x", ".xmi", ".inc", ".sh", ".py", ".pl", ".rb", ".js", ".ts"}
IMPORT_RE = re.compile(r"^\s*#\s*(?:include|import)\s*[<\"]([^>\"]+)[>\"]")
MODULE_IMPORT_RE = re.compile(r"^\s*(?:@import|import)\s+([A-Za-z_][A-Za-z0-9_.]*)")
CONDITION_RE = re.compile(r"^\s*#\s*(?:if|ifdef|ifndef|elif)\b.*")
MODULE_PREFIXES = [
    ("BaseBin/XPF/external/img4lib/lzfse", "LZFSE"),
    ("BaseBin/XPF/external/img4lib", "img4lib"),
    ("BaseBin/XPF/external/ChOma", "XPF vendored ChOma"),
    ("BaseBin/_external/modules/litehook", "litehook"),
    ("BaseBin/ChOma", "ChOma"),
    ("BaseBin/XPF", "XPF"),
    ("BaseBin/opainject", "opainject"),
    ("Application/Dopamine/Exploits", "Dopamine exploit frameworks"),
    ("Application/Dopamine", "Dopamine app"),
    ("BaseBin/libjailbreak", "libjailbreak"),
    ("BaseBin/libroothider", "libroothider"),
    ("BaseBin/launchdhook", "launchdhook"),
    ("BaseBin/", "BaseBin runtime"),
    ("Packages", "Deb packages"),
    ("Standalone", "Standalone tooling"),
]
LANGUAGES = {
    ".c": "C", ".h": "C/Objective-C header", ".m": "Objective-C", ".mm": "Objective-C++",
    ".cc": "C++", ".cpp": "C++", ".cxx": "C++", ".swift": "Swift", ".s": "assembly",
    ".asm": "assembly", ".S": "preprocessed assembly", ".x": "Logos", ".xmi": "Logos/metadata",
    ".inc": "include fragment", ".sh": "shell", ".py": "Python", ".js": "JavaScript", ".ts": "TypeScript",
    ".plist": "property list", ".entitlements": "entitlements plist", ".pbxproj": "Xcode project",
    ".xcscheme": "Xcode scheme", ".mk": "Make", ".yml": "YAML", ".yaml": "YAML", ".json": "JSON",
    ".strings": "Apple strings", ".stringsdict": "Apple stringsdict", ".png": "PNG image", ".jpg": "JPEG image",
    ".jpeg": "JPEG image", ".pdf": "PDF", ".deb": "Debian package", ".dylib": "Mach-O dynamic library",
    ".a": "Mach-O static archive", ".ipa": "iOS application archive", ".tipa": "TrollStore IPA archive",
}


def module_for(path):
    for prefix, name in MODULE_PREFIXES:
        if path == prefix or path.startswith(prefix.rstrip("/") + "/"):
            return name
    return path.split("/", 1)[0] if "/" in path else "repository root"


def language_for(path, kind):
    p = pathlib.PurePosixPath(path)
    if kind == "gitlink":
        return "Git submodule"
    if kind == "directory":
        return "directory"
    if kind == "symlink":
        return "symbolic link"
    return LANGUAGES.get(p.suffix, "extensionless/other")


def purpose_for(path, kind, category, module):
    if kind == "directory":
        return "Directory in the committed repository tree."
    if kind == "gitlink":
        return f"Pinned external source repository for {module}; its exact commit is in repository-tree.json."
    if pathlib.PurePosixPath(path).suffix.lower() in SENSITIVE_SUFFIXES:
        return "Signing or credential material path; contents and hashes intentionally omitted."
    if category == "source":
        return f"Source/interface file assigned to the {module} module; use symbols.tsv, file-dependency-edges.tsv and the source file for exact behavior."
    if category == "build/configuration":
        return f"Build or platform configuration for {module}; see BUILD_SPECIFICATION.md and the containing build target."
    if category == "script":
        return f"Build or maintenance script in {module}."
    if category == "localization":
        return f"Localized user-facing strings or localization metadata for {module}."
    if category == "resource":
        return f"Application or build resource for {module}."
    if category == "documentation":
        return f"Documentation, license, or notice for {module}."
    if category == "binary/package/signing material":
        return f"Committed binary or package input for {module}; see the file type and containing build rules."
    return f"Repository data or support file in {module}; exact role is not inferred from the filename alone."


def read_source(path):
    p = pathlib.PurePosixPath(path)
    if p.suffix.lower() in SENSITIVE_SUFFIXES or p.suffix not in TEXT_EXTENSIONS:
        return None
    full = SOURCE / path
    if not full.is_file() or full.is_symlink():
        return None
    try:
        return full.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return None


def build_files_for(path, all_paths):
    p = pathlib.PurePosixPath(path)
    parents = [str(p.parent)]
    parents.extend(str(parent) for parent in p.parents[1:] if str(parent) not in {".", ""})
    found = []
    for parent in parents:
        for name in ("Makefile", "makefile", "GNUmakefile", "CMakeLists.txt", "Package.swift"):
            candidate = f"{parent}/{name}" if parent != "." else name
            if candidate in all_paths:
                found.append(candidate)
    if path.startswith("Application/"):
        for candidate in ("Application/Makefile", "Application/Dopamine.xcodeproj/project.pbxproj", "Application/Dopamine.xcodeproj/xcshareddata/xcschemes/Dopamine.xcscheme"):
            if candidate in all_paths:
                found.append(candidate)
    if path.startswith("BaseBin/") and "BaseBin/Makefile" in all_paths:
        found.append("BaseBin/Makefile")
    if path.startswith("Packages/") and "Packages/Makefile" in all_paths:
        found.append("Packages/Makefile")
    if path.startswith("Standalone/") and "Standalone/Makefile" in all_paths:
        found.append("Standalone/Makefile")
    return sorted(set(found), key=lambda x: (x.count("/"), x))


def main():
    with MANIFEST.open(newline="", encoding="utf-8") as f:
        entries = list(csv.DictReader(f, delimiter="\t"))
    by_path = {x["path"]: x for x in entries}
    all_paths = set(by_path)
    graph = json.loads(GRAPH.read_text(encoding="utf-8"))
    nodes = graph.get("nodes", [])
    links = graph.get("links", [])
    node_by_id = {x.get("id"): x for x in nodes if x.get("id")}
    graph_by_file = collections.defaultdict(list)
    for node in nodes:
        source_file = node.get("source_file")
        if source_file:
            graph_by_file[source_file].append(node)
    graph_edges = collections.Counter()
    graph_edge_examples = {}
    for edge in links:
        src = node_by_id.get(edge.get("source"), {})
        dst = node_by_id.get(edge.get("target"), {})
        source_file = edge.get("source_file") or src.get("source_file")
        target_file = dst.get("source_file")
        if source_file in all_paths and target_file in all_paths:
            key = (source_file, target_file, edge.get("relation", ""))
            graph_edges[key] += 1
            graph_edge_examples.setdefault(key, (edge.get("source_location", ""), edge.get("context", "")))
    file_rows = []
    local_edges = collections.Counter()
    conditions_by_path = {}
    for entry in entries:
        path = entry["path"]
        category = entry.get("category", "")
        kind = entry.get("kind", "")
        module = module_for(path)
        text = read_source(path)
        includes = []
        external_imports = []
        conditions = []
        if text is not None:
            for line in text.splitlines():
                match = IMPORT_RE.match(line)
                module_match = MODULE_IMPORT_RE.match(line)
                if match:
                    token = match.group(1).strip()
                    candidates = [pathlib.PurePosixPath(path).parent / token, pathlib.PurePosixPath(token)]
                    resolved = next((str(c) for c in candidates if str(c) in all_paths), None)
                    if resolved:
                        includes.append({"token": token, "resolved_path": resolved})
                        local_edges[(path, resolved, "include")] += 1
                    else:
                        external_imports.append(token)
                elif module_match:
                    external_imports.append(module_match.group(1))
                if CONDITION_RE.match(line):
                    conditions.append(line.strip())
        conditions = sorted(set(conditions))
        conditions_by_path[path] = conditions
        graph_nodes = graph_by_file.get(path, [])
        graph_labels = sorted({x.get("label", "") for x in graph_nodes if x.get("label")})
        incoming = sum(count for (src, dst, _), count in graph_edges.items() if dst == path and src != path)
        outgoing = sum(count for (src, dst, _), count in graph_edges.items() if src == path and dst != path)
        module_build_files = build_files_for(path, all_paths)
        file_rows.append({
            "path": path,
            "kind": kind,
            "category": category,
            "language": language_for(path, kind),
            "module": module,
            "purpose_inference": purpose_for(path, kind, category, module),
            "bytes": entry.get("bytes", ""),
            "sha256": entry.get("sha256", ""),
            "content_hash_status": entry.get("content_hash_status", ""),
            "git_oid": entry.get("git_oid", ""),
            "origin": entry.get("origin", ""),
            "build_definitions": module_build_files,
            "local_imports": sorted(includes, key=lambda x: (x["resolved_path"], x["token"])),
            "external_imports": sorted(set(external_imports)),
            "preprocessor_conditions": conditions,
            "graph_node_count": len(graph_nodes),
            "graph_symbols": graph_labels,
            "graph_incoming_file_edges": incoming,
            "graph_outgoing_file_edges": outgoing,
            "semantic_review": "module-level inference; source behavior requires manual review" if category == "source" else "path/type metadata; no semantic claim",
        })
    file_path = OUTPUT / "file-inventory.tsv"
    columns = list(file_rows[0]) if file_rows else []
    with file_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=columns, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        for row in file_rows:
            writer.writerow({key: json.dumps(value, ensure_ascii=True, sort_keys=True) if isinstance(value, (list, dict)) else value for key, value in row.items()})
    symbol_path = OUTPUT / "graphify-symbols.tsv"
    with symbol_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f, delimiter="\t", lineterminator="\n")
        writer.writerow(["source_file", "label", "type", "source_location", "origin", "community", "external"])
        for node in sorted(nodes, key=lambda x: (x.get("source_file", ""), x.get("source_location", ""), x.get("label", ""))):
            if node.get("source_file") in all_paths:
                writer.writerow([node.get("source_file", ""), node.get("label", ""), node.get("type", ""), node.get("source_location", ""), node.get("_origin", ""), node.get("community", ""), node.get("external", "")])
    edge_path = OUTPUT / "file-dependency-edges.tsv"
    with edge_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f, delimiter="\t", lineterminator="\n")
        writer.writerow(["source_file", "target_file", "relation", "count", "source_location", "context", "edge_origin"])
        combined = collections.Counter(graph_edges)
        combined.update(local_edges)
        for key, count in sorted(combined.items()):
            location, context = graph_edge_examples.get(key, ("", ""))
            writer.writerow([*key, count, location, context, "graphify" if location or context else "text import scan"])
    source_paths = {x["path"] for x in entries if x.get("category") == "source" and x.get("kind") in {"file", "symlink"}}
    graph_paths = set(graph_by_file)
    summary = {
        "target_commit": graph.get("built_at_commit"),
        "manifest_entry_count": len(entries),
        "graph_node_count": len(nodes),
        "graph_link_count": len(links),
        "graph_source_file_count": len(graph_paths),
        "source_category_file_count": len(source_paths),
        "source_files_without_graph_nodes": sorted(source_paths - graph_paths),
        "graph_files_not_in_source_category": sorted(graph_paths - source_paths),
        "directory_counts_by_category": dict(collections.Counter(x.get("category", "") for x in entries if x.get("kind") == "directory")),
        "file_counts_by_language": dict(collections.Counter(x["language"] for x in file_rows if x["kind"] in {"file", "symlink"})),
        "module_counts": dict(collections.Counter(x["module"] for x in file_rows)),
        "file_inventory_semantic_status": "complete path inventory; imports and Graphify edges are extracted; purpose text is rule-based and not a manual behavioral review of every file",
        "sensitive_file_policy": "Sensitive signing/key container extensions are not opened or hashed; their Git object IDs are also omitted by the upstream manifest generator.",
    }
    (OUTPUT / "file-inventory-summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")
    print(json.dumps({"files": str(file_path), "symbols": str(symbol_path), "edges": str(edge_path), "summary": str(OUTPUT / 'file-inventory-summary.json'), "manifest_entries": len(entries), "source_graph_files": len(graph_paths), "source_files": len(source_paths), "missing_graph_sources": len(source_paths - graph_paths)}, indent=2))


if __name__ == "__main__":
    main()
