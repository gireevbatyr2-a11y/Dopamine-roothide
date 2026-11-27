# Project Guide

- Canonical source: `https://github.com/roothide/Dopamine-roothide/tree/9617d75f476423fdfd33477299c8a1349eb6f375`; never substitute another SHA.
- This directory is the persistent home. Store reports, manifests, raw target-run evidence, diagrams and attempt records here, not only in conversation scratch.
- Treat `evidence/original-artifacts/raw/` as immutable. Its SHA-256 values must continue to match the run's GitHub artifact metadata.
- Use the exact tree and recursively pinned submodule commits recorded in `evidence/source/`. The `.gitmodules` entry for `Application/Dopamine/Dopamine/Exploits/kfd/kfd` is declared but is not a gitlink in this target tree.
- The Graphify graph is a partial AST index, not a complete project map. The Git-tree-derived `repository-map.html` and `tree-manifest.tsv` are the complete path inventory.
- Do not inspect or reuse user-owned repositories or workspace folders the user marked as failed. Do not copy code from an earlier implementation attempt. Research evidence may inform a new plan, but each implementation attempt must be written in a newly created empty directory.
- Never open, hash or copy certificate/key material such as `.p12`; use no original CI secrets. Preserve all required upstream and dependency license notices in any distributed result.
- For the reproducible build, use the original workflow's complete sequence in an isolated GitHub Actions repository/branch. The current host is Linux and cannot substitute for the original macOS/Xcode runner.
- Keep these eight status documents current: `REPOSITORY_INVENTORY.md`, `ARCHITECTURE.md`, `DEPENDENCIES.md`, `HISTORY_AND_DECISIONS.md`, `BUILD_SPECIFICATION.md`, `TOOLS_AND_SKILLS.md`, `ATTEMPTS.md`, and `FINAL_VERIFICATION.md`.

## Kernel R/W work — start here

- The implementation lives on branch `kernel-rw-only`.
- Read `HANDOFF.md` first: runtime flow, file map, fixes, known failures, next steps.
- Last successful build: `45957452107` (commit `ab10177`).
- First launch works. After force-quit the app now re-runs PPL instead of blocking on "reboot required".
- `launchd stash failed`: lara persistence is not actually working yet.
- Do not shadow `xpf_start_with_kernel_path`; it recreates the `xpf_set_is_supported` crash.
