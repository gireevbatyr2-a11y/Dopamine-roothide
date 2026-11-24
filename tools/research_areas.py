import concurrent.futures
import json
import os
import pathlib
import urllib.request

ROOT = pathlib.Path("/home/workspace/Dopamine-roothide-reconstruction-9617d75f-20261124T024805Z")
SRC = ROOT / "evidence/source/upstream-9617d75f476423fdfd33477299c8a1349eb6f375"
OUT = ROOT / "evidence/research/areas"
MODEL = "openai:gpt-6-luna"

AREAS = {
    "application-runtime.md": "Analyze only the exact target checkout at {src}. Scope: Application/Dopamine app lifecycle, UI, shared Xcode project/schemes, app-side jailbreak orchestration, IPC/XPC/launchd integration, resources and bundle assembly. Identify each relevant file path, purpose, main interfaces/callers/callees, dependencies, lifecycle/runtime sequence, Xcode target and final artifact. Trace evidence to exact source paths and line numbers. Check the complete directory listing for this scope and report file counts and any unreadable/unmapped files. Do not inspect any user-owned repository, old attempt, unrelated project, key/certificate contents, or files outside the exact source checkout and this scope. Do not edit files or spawn agents. Separate facts, inferences, and unknowns; do not claim full coverage unless checked against the tree manifest.",
    "basebin-runtime.md": "Analyze only the exact target checkout at {src}. Scope: BaseBin/libjailbreak, libroothider, jailbreakd, jbctl, launchdhook, hookd, systemhook, watchdoghook, bootstrapper, boomerang, idownloadd, rootlesshooks, roothidehooks, forkfix, and related Makefiles/headers. Identify every relevant file path, purpose, API/ABI boundary, callers/callees, dependency, initialization/runtime flow, target and output. Explain arm64/arm64e conditionals and cross-process/launchd interactions only where source proves them. Check coverage against the target tree manifest and report counts/unreadable files. Do not inspect user-owned repositories, prior attempts, private keys/certificates, or unrelated paths. Do not edit files or spawn agents. Separate facts, inferences, unknowns; cite exact source paths and line numbers.",
    "exploits.md": "Analyze only the exact target checkout at {src}. Scope: Application/Dopamine/Exploits and BaseBin code directly invoking those exploit frameworks/primitives. Cover Titan, kfd, dmaFail, momentarius, badRecovery, weightBufs, multicast_bytecopy, palera1n, ClearSword, DarkSword, and any additional exploit directories actually present. Trace dispatcher/selection conditions, OS/device constraints, entry points, framework outputs, callsites and relevant build settings. Check every file in scope against the exact tree manifest; explicitly list any files Graphify did not index and how they were manually accounted for. Do not read .p12/.pfx/key/certificate contents; do not inspect user-owned repositories or earlier attempts; do not edit files or spawn agents. Cite paths and line numbers; distinguish proven behavior, inference and unknowns.",
    "build-and-packaging.md": "Analyze only the exact target checkout at {src}. Scope: root/BaseBin/Packages/Standalone Makefiles, all nested Makefiles/build scripts/configs/plists/entitlements, .github/workflows, and .gitmodules/submodule declarations. Reconstruct dependency order, outputs, variables/conditions, Xcode/Theos boundary, package assembly, signatures, IPA/TIPA naming and every omission. Enumerate each target and output; explain stale or unmatched submodule declarations only from the exact Git tree. Check the full scope against the manifest. Do not read certificate/key contents; do not inspect user-owned repositories or old attempts; do not edit files or spawn agents. Cite paths/line numbers; separate facts, inferences and unknowns."}


def ask(item):
    filename, template = item
    prompt = template.format(src=SRC)
    request = urllib.request.Request(
        "https://api.zo.computer/zo/ask",
        data=json.dumps({"input": prompt, "model_name": MODEL}).encode(),
        headers={
            "authorization": os.environ["ZO_CLIENT_IDENTITY_TOKEN"],
            "content-type": "application/json",
        },
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=1800) as response:
        result = json.loads(response.read())
    output = result["output"]
    if not isinstance(output, str):
        output = json.dumps(output, ensure_ascii=False, indent=2)
    return filename, prompt, output


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    results = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        futures = [pool.submit(ask, item) for item in AREAS.items()]
        for future in concurrent.futures.as_completed(futures):
            results.append(future.result())
    for filename, prompt, output in sorted(results):
        path = OUT / filename
        path.write_text(output.rstrip() + "\n", encoding="utf-8")
        metadata = {"model": MODEL, "source_checkout": str(SRC), "target_sha": "9617d75f476423fdfd33477299c8a1349eb6f375", "prompt": prompt, "result_file": str(path)}
        path.with_suffix(".json").write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"{filename}\t{len(output)} chars\t{path}")


if __name__ == "__main__":
    main()
