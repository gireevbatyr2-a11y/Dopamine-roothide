import json
import pathlib
import subprocess

root = pathlib.Path(__file__).resolve().parents[1]
graph = root / "evidence/source/graphify/graph.json"
out = root / "evidence/source/graphify/queries.md"
questions = [
    "How does the app launch path connect main.m, app/scene delegates, the jailbreak UI action, and DOJailbreaker runJailbreak?",
    "How does DOJailbreaker select and initialize kernel, PAC, and PPL exploit components, and where do XPF patch findings enter?",
    "How do privilege elevation, fake root setup, bootstrap, trust cache, launchdhook Mach port handoff, and cleanup connect?",
    "How does the BaseBin Makefile build and package basebin.tar, and which targets depend on one another?",
    "How do UI controllers start the jailbreak and receive state, progress, logs, and errors?",
]
lines = ["# Graphify query evidence", "", "Graphify query is a local traversal of the saved AST graph; it does not prove behavior where the extractor missed source or symbols.", ""]
for index, question in enumerate(questions, 1):
    result = subprocess.run(
        ["/root/.local/bin/graphify", "query", question, "--graph", str(graph), "--budget", "5000", "--depth", "3"],
        text=True,
        capture_output=True,
    )
    lines.extend([f"## Q{index}", "", f"**Question:** {question}", "", f"**Exit code:** {result.returncode}", "", "```text", result.stdout.rstrip(), "```", ""])
    if result.stderr.strip():
        lines.extend(["**stderr**", "", "```text", result.stderr.rstrip(), "```", ""])
    if result.returncode not in {0, 3, 4}:
        raise SystemExit(f"unexpected Graphify exit code {result.returncode} for Q{index}")
god = subprocess.run(["/root/.local/bin/graphify", "god-nodes", "--top", "30", "--json", "--graph", str(graph)], text=True, capture_output=True)
lines.extend(["## Most connected nodes", "", f"**Exit code:** {god.returncode}", "", "```json", god.stdout.rstrip(), "```", ""])
if god.returncode != 0:
    raise SystemExit(f"Graphify god-nodes failed: {god.stderr}")
out.write_text("\n".join(lines), encoding="utf-8")
print(json.dumps({"output": str(out), "queries": len(questions), "god_nodes": 30, "status": "saved"}, indent=2))
