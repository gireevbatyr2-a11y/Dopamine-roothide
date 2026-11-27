# Project memory — Dopamine-roothide workspace

## What this workspace is
- Clone of `gireevbatyr2-a11y/Dopamine-roothide` (reconstruction/audit mirror of
  upstream `roothide/Dopamine-roothide@9617d75f476423fdfd33477299c8a1349eb6f375`).
- `main` = audit + byte-identical CI reproduction of the upstream `.tipa`
  (runs 45343537230, 45345681667). Verdict recorded in `FINAL_VERIFICATION.md`:
  build reproduced, identity partial (UUID/CDHash/mtimes are non-deterministic).
- `kernel-rw-only` branch (63 commits ahead of main) = separate product:
  Dopamine repurposed as a **kernel R/W utility** ("FFKRW"), no jailbreak state.
  Hand-off journal: `docs/kernel-rw/AGENT_JOURNAL.md` (read this first).

## Facts worth keeping
- GitHub Actions is the only real build path; this Linux host cannot build
  Xcode/Theos targets. Push to a branch -> run `*** build ipa/tipa file ***`.
- Artifact naming is hardcoded in the workflow to
  `roothide-<APP>-(3.0.13-30-9617d75)-2026.11.06-UTC-02.17.10.{ipa,tipa}`.
- `gh` CLI is NOT authenticated in this container; use
  `curl -H "Authorization: Bearer $GITHUB_TOKEN" https://api.github.com/...`.
- Local clone is shallow; `git fetch --depth=1 origin <branch>` works.
- `evidence/original-artifacts/raw/` is empty in this clone (artifacts not
  committed); the SHA-256 comparison was done out-of-band.
- AGENTS.md requires 8 status docs at repo root; only `REPOSITORY_INVENTORY.md`
  and `FINAL_VERIFICATION.md` are there, the other six live in `docs/` under
  different names (`ARCHITECTURE_OVERVIEW.md`, `BUILD_PIPELINE.md`, ...).
- Device-side evidence comes only from `/var/mobile/Documents/DopamineKernelRW.log`;
  no device logs are stored in the repo yet.

## Handoff (as of 2026-11-27, after `git pull`)
- `HANDOFF.md` at repo root (also on `kernel-rw-only`) is the short, authoritative
  brief; `docs/kernel-rw/AGENT_JOURNAL.md` is the deep history.
- Branch tip `9ff6575` = code of `ab10177` + docs only (HANDOFF.md, AGENTS.md).
  Last green build `45957452107` corresponds to `ab10177`.
- Known blocker: lara launchd stash fails. `offsets_shim.m` leaves ~109 offsets
  at 0 because `libjailbreak/info.h`'s KERNEL_STRUCTS_ITERATE set has no
  `proc.p_name`, `thread.t_tro`, `thread_ro.*`, `thread.machine.upcb`, `ctid`,
  `options`, `mutex.lck_mtx_data`, `socket.*`, `inpcb.*`, `task_exc_guard`.
  Offsets come from XPF's xdict (`jbinfo_initialize_dynamic_offsets`), and
  `BaseBin/XPF` is an empty submodule locally.
- lara `offsets.m` (full resolver) is present but not compiled: needs `xpf.h`
  (generated into `BaseBin/.include/xpf` at build) and `vnode.h` (not vendored).
- Device evidence (`FFKRW.log`, `.ips`) exists only on the user's side; not in
  the repo.

## 2026-11-27 device evidence + fix (build 45987649525)
- Panic on the second run is `GFX NMI: GFXEndpoint2 ... error=0xe00002db`,
  panicked task `pid 64: backboardd` (RTBuddy/IOGPUFamily). FFKRW is not a
  jetsam victim and has no thread in the backtrace: the *second* ClearSword/Titan
  run in the same boot is what panics. Force-quit alone is survivable.
- kread/kwrite transport = 2 sockets leaked via `so_usecount`
  (`ClearSword/exploit/socket.c:krw_sockets_leak_forever`), so the kernel
  primitive survives process death; only the fds die. Recovery = new fds.
- Fix: `fileport_makeport` + `bootstrap_register` (`com.ffkrw.krw.control|rw`)
  in the app's own namespace (app has `com.apple.private.security.no-sandbox`),
  base/slide in NSUserDefaults, verify `kread32(base)==0xFEEDFACF`.
- lara logs via `printf` → invisible on iOS; bridged to `DOKRWLog` in
  `LaraPersistence.m`. Careful: `__attribute__((format(printf,...)))` must be
  written as `format(__printf__, ...)` or the macro breaks it.
- CI gotcha: `LaraPersistence.m` needs `#import <Foundation/Foundation.h>` before
  any NSString use (build 45985662495 failed on exactly that).
- Safe gate: after a successful exploit in a boot, recovery failure returns an
  error instead of re-running PPL.

## Supported matrix (upstream ellekit.space/dopamine + this repo's plists)
- Upstream: arm64 A8-A11, arm64e A12-A17/M1-M2; iOS 15.0-17.3.1 for A14-A17/M1-M2;
  iOS 15.0-18.7.1 and 26.0-26.0.1 for A8-A13.
- Kernel exploit selection = highest DPFlavorPriority among supported:
  multicast_bytecopy 950 (15.0-15.1.1, excl A8/A9), kfd physpuppet 1000
  (15.0-15.7.3 + 16.0-16.3.1), kfd landa 880, kfd smith 600, ClearSword 895
  (15.0-18.7.1 + 19.0-26.0.1, all devices), DarkSword 890, weightBufs 800,
  palera1n 0 (arm64).
- DPSupportInclude/Exclude are *toggle* lists (match -> flip _supported), not filters.
- DPExploitRequirements is parsed but never used.
- Only ClearSword/DarkSword have a resumable transport (leaked sockets + 2 fds).
  kfd/palera1n/multicast_bytecopy cannot be resumed (per-process objects, freed).
- doExploitation had no fallback; added orderedKernelExploits + retry loop.

## Exploit matrix simulation (no hardware needed)
- `tools/exploit-matrix/matrix.py` mirrors DOExploit.isSupported +
  DOEnvironmentManager.isSupported + orderedKernelExploits over the real plists;
  prints chosen exploit per CPU family x iOS; `--strict` fails on coverage holes;
  exit 2 on ordering/reference violations. Doc: docs/kernel-rw/EXPLOIT_MATRIX.md.
- CI job "exploit matrix" (.github/workflows/exploit-matrix.yml) runs it on push.
- Current result: 412 supported combos, all ClearSword (resumable), 0 holes.
- Gotcha: `DPSupportInclude` is only applied when the device is NOT supported
  (`_supported ? Exclude : Include`), so it whitelists builds; it never disables.
  The 23B50xx builds do NOT disable ClearSword, DarkSword never wins by priority.

## Emulating iOS kernel exploits (asked 2026-11-27)
- Not possible with anything I can reach: iOS Simulator runs the macOS kernel (no
  XNU-iOS, no exploit surface, hw.cpufamily/kern.osversion come from the host);
  device farms (BrowserStack/Sauce/AWS Device Farm/Firebase) give real devices but
  no root and forbid jailbreak exploits; Corellium is the only ARM service with real
  iOS firmware but needs a paid account, lacks real PPL/SEP, and its ToS restricts
  this use.
- What substitutes: tools/exploit-matrix (selection), plus source scan of
  @available branches. ClearSword pe(): iOS <16 / 16-18 / 19+ and arm64 vs arm64e
  paths, so 15.x and arm64 are intended; A18 (iPhone17,*) pe_v2 is unimplemented.
- One physical device on 15.x or 16.0-16.3.1 settles the whole slice; the exploit
  code is version-branched, not per-device.

## Xcode project gotchas (this repo)
- The Dopamine app target uses classic PBXFileReference entries; only the ClearSword
  framework targets use PBXFileSystemSynchronizedRootGroup. A new .m in
  Application/Dopamine/... is NOT compiled until it is added to project.pbxproj:
  PBXBuildFile + PBXFileReference + children of the right PBXGroup (path = UI for
  Application/Dopamine/UI, NOT the Log subgroup) + the Sources build phase.
  Symptom of a missing reference: undefined _Symbol at link; symptom of the wrong
  group: "Build input file cannot be found: .../UI/Log/X.m".
- Application/Makefile recipes are tab-indented; string replacements that assume
  spaces silently do nothing. Verify with `grep -n ... | cat -A`.
- The workflow's VERSION string and artifact names are hardcoded (fixed date); the
  only reliable build identifier in a tester report is Info.plist `DOKRWForkSHA`,
  stamped from `git rev-parse --short HEAD` by Application/Makefile.

## Public evidence on DarkSword/ClearSword (2026-11-27)
- CVE-2025-43520 (race in cluster_write_contig/cluster_read_contig): affects every iOS
  below 18.7.2 and below 26.1, fixed in 18.7.2 / 26.1 -> matches this fork's matrix upper
  bounds (18.7.1, 26.0.1).
- Upstream of our Exploits/ClearSword is TheRealClarity/ClearSword (C port of DarkSword).
  Its utils.c picks offsets by version with one catch-all `else` for 15.x/16.x/17.0 and
  TODO comments; this fork replaced those with koffsetof() (XPF patchfinder), so upstream
  results do not transfer to our build.
- opa334/darksword-kexploit is the only public claim of DarkSword running on 15.x
  ("offsets hardcoded for 15.x", fixes "to make it work on IOS 15"); its 15.x constants
  (so_count 0x228, icmp6filt 0x150) differ from 16.x (0x22c) -> tables are not portable.
- rooootdev/lara publishes: 17.0-18.7.1 and 26.0-26.0.1 supported, 16.x "possible, offsets
  not found", 16.7.2 tested on A12, no 15.x entry at all.
- No public data on persisting kernel R/W across app relaunch for any iOS version.
- PPL bypasses in this tree are arm64e only: momentarius A12/A13 15.0-26.0.1, dmaFail
  A14/A15 15.0-16.5.1, Titan A14-A17 16.1-17.3.1, badRecovery (PAC) 15.0-15.4.1.
  So A8-A11 fail for lack of a PPL bypass, not because of ClearSword.

## GitHub Actions quota (learned the hard way)
- Runs that finish in ~3 s with conclusion `failure`, empty step list and a
  `BlobNotFound` log URL are account-level: no runner was allocated. A trivial
  `echo alive` workflow fails identically, so it is not the workflow file.
- Most likely cause on this account: private repo + free plan, macOS runners billed at
  10x; ~8 Xcode builds/day at ~15 min each burns the monthly 2000 minutes.
- Repo is private (gireevbatyr2-a11y/Dopamine-roothide); making it public gives free
  Actions minutes, but that is the user's decision.
