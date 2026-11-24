# Dopamine-roothide clean-room reconstruction

**Scope:** exact upstream state `roothide/Dopamine-roothide@9617d75f476423fdfd33477299c8a1349eb6f375`.

**Status:** research in progress. The upstream commit and its original successful Actions run are verified. The independent implementation has not started, no reconstruction attempt has failed, and no reconstructed build or byte-identity claim exists.

This directory is the durable project home in `/home/workspace`; research evidence must not remain only in conversation scratch space. The authoritative path manifest, Git tree IDs, file hashes, submodule SHAs and validated interactive tree are generated from a fresh checkout of the exact upstream commit. Original Actions logs and raw `.ipa`/`.tipa` files are preserved under `evidence/`. The raw artifact files are read-only references: do not replace or repackage them.

## Navigation

- [`REPOSITORY_INVENTORY.md`](REPOSITORY_INVENTORY.md) — complete tracked tree and categories.
- [`ARCHITECTURE.md`](ARCHITECTURE.md) — runtime and build architecture.
- [`DEPENDENCIES.md`](DEPENDENCIES.md) — pinned and floating dependencies.
- [`HISTORY_AND_DECISIONS.md`](HISTORY_AND_DECISIONS.md) — verified commit history and evidence-backed inferences.
- [`BUILD_SPECIFICATION.md`](BUILD_SPECIFICATION.md) — exact target workflow, runner and outputs.
- [`TOOLS_AND_SKILLS.md`](TOOLS_AND_SKILLS.md) — tools and skills actually used.
- [`ATTEMPTS.md`](ATTEMPTS.md) — reconstruction attempt ledger.
- [`FINAL_VERIFICATION.md`](FINAL_VERIFICATION.md) — current verification state and remaining gates.
- [`repository-map.html`](repository-map.html) — interactive full file tree for the target SHA.

## Durable layout

- `evidence/source/` — exact commit/submodule tree manifest, source hashes, license index and Graphify AST graph (explicitly partial).
- `evidence/actions/run-42149352138/` — original full Actions log and run/job/artifact metadata.
- `evidence/original-artifacts/raw/` — immutable raw artifacts downloaded from that run and checked against GitHub SHA-256 metadata.
- `evidence/original-artifacts/analysis/` — extracted copies and per-file/binary analysis; never substitutes for the raw originals.
- `maps/` — verified diagrams.
- `tools/` — reproducible inventory and evidence-generation scripts; never jailbreak implementation sources.
- `implementation/attempts/` — reserved for newly written attempts; create a new empty directory for each attempt.

## Clean-room rules

1. Use only the named public upstream commit and its verified pinned submodules as the specification. Do not inspect or reuse the user's unrelated repositories or folders marked as failed work.
2. Keep upstream source used for study separate from `implementation/`. Never copy source, generated files, object files or binaries from a failed implementation attempt.
3. Preserve all source/research evidence and the original target artifacts across attempt resets. Never read or copy `.p12` signing material; no CI secrets or private keys are part of the reconstruction.
4. The target build needs macOS/Xcode. Local Linux results are static analysis only; the requested comparable build must run in GitHub Actions on an isolated repository/branch after the implementation is complete.
5. Independent source, functional equivalence and byte-identical output are separate claims. Report the exact one proven; do not infer identity from a green build.
