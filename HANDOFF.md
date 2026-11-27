# Kernel R/W handoff

Last updated: 2026-11-27 (after build `46014408252`).
Read this before touching the branch. It is intentionally short; deep history is in
`docs/kernel-rw/AGENT_JOURNAL.md`.

## 1. Goal and hard constraints

Repurpose Dopamine-roothide into a **kernel R/W provider only**:

- base tree: `9617d75f476423fdfd33477299c8a1349eb6f375`
- branch: `kernel-rw-only`
- keep exploit/device coverage unchanged (ClearSword / Titan PPL, iOS 16.x)
- obtain kernel R/W in the current boot, in-process, with zeroed `extmod`
- do **not** reboot, do **not** enter jailbreak state, do **not** run jailbreakd
- minimal UI: one button that gets kernel R/W
- no jailbreak payload/session/boot management, no roothide cleanup button
- rename user-visible Dopamine -> FFKRW is only partial; bundle id is
  `com.ffkrw.FFKRW`, code names still say Dopamine

Test device used for evidence: iPhone13,2 (iPhone 12), iOS 16.6 (20G75).

## 2. Current state

- HEAD: `04a62bc` — + exploit matrix simulation + CI job
- Latest build: **`46014408252` — success** (`.ipa` + `.tipa` uploaded)
- Previous success: `45953263580` (`9c2fd20`) — fixed the `xpf` relaunch crash
- Previous success from the other AI: `45907696779` (`2bc2792`)
- First launch on device: PPL works, process connect works.
- `launchd stash failed` is still logged. **lara persistence is not actually working.**
- After force-quit, the current build now allows a fresh PPL run instead of showing
  "reboot required". This is built but not yet device-validated.

Do not claim persistence across force-quit yet. The current recovery is:
try lara `recover_krw_primitives()`, then fall back to re-running the in-process PPL.

## 2b. 2026-11-27 device run: what the logs showed

`FFKRW.log` + `panic-full-2026-11-27-133421.000.ips` from build `45957452107`:

- first launch: `patchfinding -> exploitation -> physrw -> ready`, kread/kwrite work,
  `process: connected to 34 (nfcacd), extmod zeroed=yes`, pinned extmod offset 0x438;
- `launchd stash failed` (lara RemoteCall path, offsets still 0);
- force-quit, relaunch (`main: launch pid=630`), second tap on the button;
- kernel panic: `GFX NMI: GFXEndpoint2: send msg=0x83000000000000 error=0xe00002db`,
  panicked task `pid 64: backboardd` (RTBuddy / IOGPUFamily in the backtrace).
  FFKRW is not a jetsam victim and has no thread in the backtrace.

Conclusion: the second ClearSword/Titan run in the same boot is what kills the
device. Force-quitting alone did not panic. So the app must never re-exploit
after a successful run in the same boot, and recovery has to work instead.

## 2c. What was changed for that (build 45987649525)

- `persistence.m`: the kread/kwrite transport is two sockets whose kernel objects
  are leaked on purpose (`so_usecount`), so the primitive survives process death;
  only the fds die. The sockets are now also converted with `fileport_makeport`
  and registered as `com.ffkrw.krw.control` / `com.ffkrw.krw.rw` in the app's
  bootstrap namespace (the app has `com.apple.private.security.no-sandbox`), with
  kernel base/slide in NSUserDefaults. Recovery does `bootstrap_look_up` +
  `fileport_makefd` and verifies `kread32(kernel_base) == 0xFEEDFACF`.
  lara's launchd `RemoteCall` path is still tried second as a fallback.
- `LaraPersistence.m`: lara logs with `printf`, which goes nowhere on iOS. It is
  now routed into `DOKRWLog` (`[lara]` lines in the app log).
- `DOJailbreaker.m`: if recovery fails and the exploit already ran this boot,
  return an error instead of re-running PPL (that is the panic path).

Open question for the next device run: whether `bootstrap_register` from the app
namespace survives process exit. The log now prints the `kern_return` of every
step, so one run answers it.

## 2d. Coverage across the supported matrix

Upstream support statement (ellekit.space/dopamine): arm64 A8-A11 and arm64e
A12-A17/M1-M2; iOS 15.0-17.3.1 for A14-A17/M1-M2; iOS 15.0-18.7.1 and
26.0-26.0.1 for A8-A13.

Which kernel exploit runs is decided by `DPFlavorPriority` in the exploit
Info.plists, and only some transports can be resumed after process death:

| iOS | exploit chosen by priority | transport resumable |
|---|---|---|
| 15.0-15.1.1 (A10+) | multicast_bytecopy 950 | no |
| 15.0-15.1.1 (A8/A9) | ClearSword 895 | yes |
| 15.0-15.7.3, 16.0-16.3.1 | kfd physpuppet 1000 | no |
| 15.7.4-18.7.1, 19.0-26.0.1 | ClearSword 895 | yes |

`orderedKernelExploits` now tries an explicit user pick first, then exploits with
`DPPersistentTransport` (ClearSword, DarkSword), then the rest by priority, and
`doExploitation` walks the whole list instead of giving up on the first failure.
Effect: on 15.0-16.3.1 ClearSword is attempted before kfd, so those devices get
persistence if ClearSword works there; if it does not run, kfd still gets R/W
(without persistence). Unverified on hardware: 15.x, 16.0-16.3.1, arm64, 26.x.

Correction: `DPSupportInclude` is only consulted when the device is *not* already
supported (upstream: `_supported ? Exclude : Include`), so it whitelists extra
builds and never disables one. ClearSword therefore also covers 23B5044l /
23B5059e / 23B5064e, and DarkSword never wins by priority - it is only a fallback
if ClearSword fails to run.

`tools/exploit-matrix/matrix.py` reproduces `DOExploit.isSupported`,
`DOEnvironmentManager.isSupported` and `orderedKernelExploits` over the real
Info.plists and prints the selection for every CPU family / iOS combination in the
official matrix (`docs/kernel-rw/EXPLOIT_MATRIX.md`, regenerated by the
"exploit matrix" workflow, which also fails when a supported device would be routed
onto a non-resumable exploit). Result on this tree: 412 supported combinations, all
412 selecting a resumable exploit, 0 coverage holes.

ClearSword's own range (15.0-18.7.1, 19.0-26.0.1, every device) is wider than the
app's support, because the ceiling is the PPL/PAC bypass, not the kernel exploit:
`isPPLBypassRequired` is true on every arm64e device, Titan covers 16.1-17.3.1 and
A14-A17 only, momentarius covers 15.0-26.0.1 but only A12/A13, dmaFail 15.0-16.5.1,
badRecovery 15.0-15.4.1. That is why `versionSupportString` reports 15.0-17.3.1 for
A14+ and 15.0-18.7.1 / 26.0-26.0.1 for A12/A13. Removing the other kernel exploits
would not widen support; keeping them as a silent fallback does keep R/W working
where ClearSword does not run.

## 3. Runtime flow (what is wired to what)

```
DOMainViewController startKernelRW
  -> DOJailbreaker obtainKernelRW
       -> if !_kernelRWReady:
            gatherSystemInformation        (libxpf + kernelcache; real libxpf)
            lara_offsets_init()             (offsets_shim -> current gSystemInfo)
            gPrimitives.kreadbuf/kwritebuf = clearsword_*
            recover_krw_primitives()        (lara: read launchd memory, rebuild sockets)
       -> if still not ready:
            obtainKernelRWInProcess()
              -> gatherSystemInformation
              -> doExploitation()           (ClearSword + Titan PPL)
              -> buildPhysRWPrimitive()     (pte)
              -> cleanUpExploits()
              -> gPrimitives live in this process
       -> after success:
            transfer_krw_to_launchd_ios16() (lara stash; currently fails)
            control_socket/rw_socket/kernel_base/kernel_slide copied out of g_ctx
```

The app deliberately does not start a helper. An earlier helper caused an IOSurface
panic; it was removed. PPL is in-process only.

## 4. Key files

- `Application/Dopamine/UI/DOMainViewController.m`
  - button title / visibility; `startKernelRW`; UI success/failure.
  - relaunch gate removed: button is visible again after force-quit.
- `Application/Dopamine/Jailbreak/DOJailbreaker.m/.h`
  - `obtainKernelRW`, `obtainKernelRWInProcess`, `gatherSystemInformation`,
    `buildPhysRWPrimitive`, `cleanUpExploits`.
  - lara calls: `lara_offsets_init`, `recover_krw_primitives`,
    `transfer_krw_to_launchd_ios16`.
  - boot-state flags `DOKRWExploitRan` / `DOKRWExploitStarted` still exist but no
    longer block a new process.
- `Application/Dopamine/LaraPersistence/`
  - `LaraPersistence.m` — single translation unit aggregator. It includes lara
    headers first, then `TaskRop/*.m`, then shims, `utils.m`, `persistence.m`.
  - `darksword_shim.m` — maps lara `ds_*`/globals onto `g_ctx`/`gPrimitives`
    (`control_socket`, `rw_socket`, `kernel_base`, `kernel_slide`).
  - `offsets_shim.m` — maps lara `off_*` names onto current `libjailbreak`
    `info.h` fields. Many fields are set to 0 because current `info.h` lacks them.
  - `utils.m` — lara utils; local `xpaci`/`pac_mask`; real `xpf` calls;
    `xpf_gett1szboot` stub.
  - `persistence.m` — `RemoteCall` based launchd stash/recover.
  - `TaskRop/` — lara RemoteCall/thread/pac/exc/vm/findcachedataoff.
  - `offsets.m` — full lara offset resolver; **not compiled**. It needs
    `xpf.h`/`libgrabkernel2.h`/`vnode.h` and was not ported.
- `Application/Dopamine.xcodeproj/project.pbxproj`
  - `LaraPersistence.m` is in the **Dopamine** target Sources, not momentarius.
  - `HEADER_SEARCH_PATHS` include:
    - `$(SRCROOT)/Dopamine/LaraPersistence`
    - `$(SRCROOT)/Dopamine/LaraPersistence/TaskRop`

## 5. What was tried / fixed (chronology, short)

1. Removed roothide cleanup button and `removeRoothideLeftovers` /
   `startRoothideCleanup`.
2. Removed helper from the button; restored in-process PPL.
3. Ported lara TaskRop/persistence into `LaraPersistence/`.
4. Build failures, in order:
   - missing lara headers -> added header search paths;
   - `RemoteCall.m` could not see `ds_*`/`off_*` -> include headers before `.m`
     in `LaraPersistence.m`;
   - `offsets_shim` used wrong `info.h` field names -> remapped to current fields
     (`proc.list_next`, `proc.pid`, `task.itk_space`, `ipc_space.table`,
     `ipc_entry.object`, `ipc_port.kobject`, etc.);
   - `xpf_gett1szboot` missing at link time -> local stub returning 0.
5. Device crash on "Get Kernel R/W":
   - `.ips` stack:
     `_platform_strcmp -> xpf_supported_16up_no_sptm -> xpf_set_is_supported ->
      -[DOJailbreaker gatherSystemInformation]`
   - root cause: my `utils.m` stub
     `int xpf_start_with_kernel_path(const char *path)` shadowed the real 3-arg
     `libxpf` symbol. `xpf_start` returned 0 without initializing libxpf, then
     real `xpf_set_is_supported` hit a NULL kernel version.
   - fix: removed that stub; declare/call real
     `xpf_start_with_kernel_path(kernelPath, sptmPath, txmPath)`.
     Keep only `xpf_gett1szboot` stub because that symbol is absent.
6. Device relaunch behavior:
   - first launch: PPL works, process connect works, `launchd stash failed`;
   - force-quit + reopen: new process had no primitives, but old boot flags made
     the UI hide the button and log "already acquired; reboot required";
   - fix: removed the boot-state gate in `obtainKernelRW` /
     `obtainKernelRWInProcess` and the hide-button branch in `viewWillAppear`.
     New process now tries recovery, then re-runs PPL.
7. `JetsamEvent-2026-11-27-101420.ips` does **not** contain FFKRW as a victim;
   largest process was WebKit. The app was not jetsam-killed; it was gated.

## 6. Known broken / root causes

- **lara launchd stash does not work.** Log says `launchd stash failed`.
  `recover_krw_primitives`/`RemoteCall` need offsets that are currently 0:
  `off_proc_p_name`, `off_thread_t_tro`, `off_thread_ro_*`,
  `off_thread_machine_upcb`, `off_thread_ctid`, `off_thread_options`,
  `off_thread_mutex_lck_mtx_data`, `off_socket_*`, `off_inpcb_*`,
  `off_task_task_exc_guard`.
  With those zeroed, RemoteCall cannot build the launchd task/port path.
- `offsets.m` (full lara resolver) is not compiled. That is the clean way to get
  the missing offsets, but it needs xpf/libgrabkernel2/vnode headers and porting.
- `xpf_gett1szboot` stub returns 0; lara `T1SZ_BOOT` is not real. Not fatal for
  current PPL, but do not trust lara offset math that depends on it.
- `info.h` field names can collide with SDK macros
  (`VM_PAGE_PACKED_PTR_SHIFT`, `VM_PAGE_PACKED_PTR_BASE`, `TFRO_PLATFORM`).
  If that error comes back, `#undef` those before including
  `<libjailbreak/info.h>` in the shims.
- Rename is incomplete: UI says FFKRW, many code paths still say Dopamine.
- No device validation yet of build `45957452107` (relaunch re-exploit path).

## 7. Next steps, in order

1. Device-test `45957452107`:
   - first launch -> Get Kernel R/W -> connect to a process;
   - force-quit -> reopen -> button visible -> Get Kernel R/W -> connect again.
2. If relaunch re-exploit works: decide whether to keep or remove the lara stash.
   - Keep: fix `offsets_shim`/port `offsets.m` until `launchd stash failed`
     disappears and `recover_krw_primitives` succeeds.
   - Remove: delete lara stash calls and leave clean in-process re-exploit.
3. If relaunch re-exploit fails: capture `FFKRW.log` + `.ips`; check whether
   `gatherSystemInformation`/`xpf` or `doExploitation` fails on second run.
4. Only after that: finish rename, remove dead jailbreak code, update docs.
5. Do not add a helper back without a separate investigation; the previous helper
   caused an IOSurface panic.

## 8. Test checklist

- [ ] first launch: `obtainKernelRW: start -> patchfinding done -> exploitation
      -> physrw -> ready`
- [ ] process connect: `process: connected ..., extmod zeroed=yes`
- [ ] force-quit, reopen: button `Get Kernel R/W` visible
- [ ] second tap: no "reboot required"; PPL runs again
- [ ] process connect again
- [ ] `launchd stash failed` present or gone? record it
- [ ] no FFKRW `.ips` / no jetsam victim

## 9. Evidence and commands

Repo root currently has untracked device evidence (do not commit unless asked):
`FFKRW.log`, `FFKRW.state`, `FFKRW-*.ips`, `JetsamEvent-*.ips`,
`awdd-*.metriclog*`.

Builds:
```bash
gh run list --branch kernel-rw-only --limit 5
gh run view <id> --log-failed | grep -E "error:|Undefined symbols|BUILD FAILED"
```
Known noise in logs (not real failures): `install_name_tool: no LC_RPATH ...
@loader_path/present`, `-multiply_defined is obsolete`,
`search path '.../Exploits' not found`.
Transient failures seen and fixed by rerun: `xcodebuild` NSDate assertion,
clang segfault during link.

Sync with the other AI:
```bash
git pull --rebase origin kernel-rw-only
```
The other AI has pushed commits before; always rebase before pushing.

## 10. Gotchas / do not repeat

- Do **not** define `xpf_start_with_kernel_path` in app code. It shadows real
  libxpf and recreates the `xpf_set_is_supported` crash.
- Do **not** compile `TaskRop/*.m` as separate target files; include them through
  `LaraPersistence.m` after the lara headers.
- Do **not** put `LaraPersistence.m` in the momentarius target.
- Do **not** use `gPrimitives`/`g_ctx` across a process restart; they are
  process-local. Recovery must rebuild them.
- Do **not** re-enable the boot-state gate; a new process has no primitives even
  if the previous run set `DOKRWExploitRan`.
- Do **not** commit `.ips`, logs, `.p12`, or secrets.
- Keep the canonical base SHA `9617d75f476423fdfd33477299c8a1349eb6f375`.

## 11. Open decisions

- Is true launchd-stash persistence still required, or is "reopen and tap again"
  acceptable? The current code re-exploits; the stash is not working.
- If persistence is required: port full lara `offsets.m` or compute the missing
  offsets from `gSystemInfo`/xpf, then validate `RemoteCall` in a test process.
- Should the UI auto-run `obtainKernelRW` on launch instead of requiring a tap?
- How far to take the Dopamine -> FFKRW rename without touching exploit code.
