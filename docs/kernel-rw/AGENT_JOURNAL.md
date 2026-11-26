# Kernel-RW-only: Agent Journal

Last updated: 2026-11-25
Branch: `kernel-rw-only`
Canonical base tree: `9617d75f476423fdfd33477299c8a1349eb6f375`

This file is the hand-off log. Read it first, then `git log --oneline -10` and
`git status`. It records *why* things look the way they do, so a new agent can
continue without re-deriving the design.

---

## 0. TL;DR (RU)

Цель: превратить `Dopamine-roothide` из джейлбрейка в утилиту, которая в
**текущем буте** даёт kernel R/W (kread/kwrite) и примитивы для зануления
`task->extmod_statistics`. Никакого джейлбрейка, состояния, сессии или
перезагрузки бут — пайплайн останавливается сразу после `physrw`.

Сделано: `DOJailbreaker` переписан в провайдер kernel R/W; UI переведён на
кнопку «Kernel R/W»; джейлбрейк-настройки вычищены; добавлен файловый лог
`/var/mobile/Documents/DopamineKernelRW.log`; добавлен resolver offset'а
`extmod_statistics` (кэш per-build + runtime discovery + pinned table);
добавлен helper-режим процесса для perturbation счётчиков.

Осталось: собрать в GitHub Actions, проверить, что `posix_spawn` helper'а и
`task_for_pid` проходят на устройстве, и заполнить pinned table реальными
offset'ами (или дать resolver'у выучить их на каждом билде).

---

## 1. Goal and hard constraints

- Remove the jailbreak entirely: no jailbreak state, session, boot management,
  bootstrap, trustcache upload, launchd hook, fakelib, app duplication.
- Keep exploit coverage and device support unchanged: same exploits, same
  device/iOS matrix, same XPF patchfinding sets.
- Provide kernel R/W (`kread/kwrite`) plus the primitives needed to zero
  `extmod` (physrw, `kcall` when available, `kalloc/kmap` when available).
- Do not reboot, respring, or enter any jailbreak state from the kernel-RW
  flow.
- Build must be produced by the upstream GitHub Actions workflow
  (`.github/workflows/main.yml`, macOS runner). The current Linux host cannot
  substitute for Xcode.

## 2. Current state

### Branch and commits

- `kernel-rw-only` — local branch, based on `main`.
- Previous commit (from the earlier session):
  `8fe24ef` — "kernel-rw: repurpose DOJailbreaker into a kernel R/W provider".
- The changes described below are committed on `kernel-rw-only`; the current
  head is `2ff72c3` (process list tab included).

### Files that matter

| File | Role |
| --- | --- |
| `Application/Dopamine/Jailbreak/DOJailbreaker.h` | Public kernel-RW API, logger, extmod API |
| `Application/Dopamine/Jailbreak/DOJailbreaker.m` | Pipeline, primitives, extmod resolver, logger |
| `Application/Dopamine/UI/DOMainViewController.m` | Main button + flow + UI logging |
| `Application/Dopamine/UI/Settings/DOSettingsController.m` | Settings cleanup |
| `Application/Dopamine/main.m` | `krw-perturb-helper` child mode |
| `docs/kernel-rw/AGENT_JOURNAL.md` | This file |

Exploit sources (`Titan`, `DarkSword`, `ClearSword`, `kfd`, `dmaFail`,
`badRecovery`, `momentarius`, ...) are untouched. Xcode project, Makefiles and
the workflow are untouched.

### What is verified

- Static only: brace/paren/bracket balance, no leftover removed selectors,
  primitive signatures checked against `BaseBin/libjailbreak/src/primitives.h`.
- `task->extmod_statistics` is an **inline** struct of **6 x int64** (48 bytes)
  in current XNU and in xnu-8020.101.4. `task_info(TASK_EXTMOD_INFO)` returns
  `struct task_extmod_info { uuid[16]; vm_extmod_statistics; }`, so the stats
  start at offset 16 of the 64-byte output.

### What is NOT verified

- No compile on Linux (needs macOS/Xcode + iPhoneOS SDK + Theos).
- No runtime on device. In particular these are untested:
  - `posix_spawn` of the app's own executable on iOS.
  - `task_for_pid` from the helper child to the parent, and from the parent to
    other same-uid processes.
  - Whether the learned extmod offset is unique on every build.

## 3. Pipeline (stop after physrw)

`obtainKernelRW` (`DOJailbreaker.m`):

1. `gatherSystemInformation`
   - kernelcache path from `DOEnvironmentManager.accessibleKernelPath`
   - `xpf_start_with_kernel_path`
   - XPF sets: `translation`, `trustcache`, `sandbox`, `physmap`, `struct`,
     `physrw`, `IOSurface`, plus `devmode`, `badRecovery`, `arm64kcall`,
     `perfkrw` when supported
   - `jbinfo_initialize_boot_constants`
   - `jbinfo_initialize_dynamic_offsets`
2. `doExploitation`
   - kernel exploit (`EXPLOIT_TYPE_KERNEL`)
   - PAC bypass when `isPACBypassRequired`
   - PPL/SPTM bypass when `isPPLBypassRequired`
   - `translation_init`
   - `IOSurface_primitives_init`
   - `arm64_kcall_init` for non-arm64e
3. `buildPhysRWPrimitive`
   - `libjailbreak_physrw_pte_init` when `device_supports_physrw_pte()`
   - else `libjailbreak_physrw_init`
4. `cleanUpExploits`
   - `DOExploitManager.cleanUpExploits`
   - `IOSurface_map_cleanup`

Then `_kernelRWReady = YES` and return. No `elevatePrivileges`, no
`loadBasebinTrustcache`, no `injectLaunchdHook`, no `applyProtection`, no
`prepareBootstrap`, no `finalize`, no `removeJailbreak`.

The log file records every stage, so a device run produces a trace even if the
UI is not visible.

## 4. kcall: what it is, when it is missing, how Dopamine worked

### What `kcall` is

`kcall` ("kernel call") invokes an arbitrary kernel function with up to 8
arguments from userland. It is implemented on top of the exploit's ability to
control a kernel thread:

- `arm64_kcall` (`BaseBin/libjailbreak/src/kcall_arm64.c`) for non-arm64e.
  `arm64_kcall_init()` sets `gPrimitives.kcall = arm64_kcall`.
- `fugu15_kcall` (`Application/Dopamine/Exploits/badRecovery/badRecovery.m`)
  for arm64e; it is installed by the PAC/PPL bypass.
- `fugu14_kcall` (`BaseBin/libjailbreak/src/kcall_Fugu14.c`) for Fugu14-era
  devices.

`DOJailbreaker.isKcallAvailable` is just `gPrimitives.kcall != NULL`.
`kcall(&result, func, argc, argv)` returns 0 on success and writes the return
value to `result`.

### What breaks when kcall is unavailable

- `kcall` itself returns 0 and `isKcallAvailable` is `NO`.
- Kernel functions cannot be called directly. In libjailbreak this affects:
  - `pmap_enter_options_addr` / `pmap_remove_options` (`kernel.c`), which are
    used by `pmap_expand_range` (`util.c`) to grow page tables.
  - `mac_label_set`, `ml_sign_thread_state` (`kernel.c`, `util.c`).
- `pmap_expand_range` has a non-kcall fallback that edits page tables directly
  with `physwrite*`, so the jailbreak path still worked without kcall.
- **`physrw` and `physrw_pte` do not use kcall** (verified by grep: no
  `kcall`/`pmap_enter` in `physrw.c`/`physrw_pte.c`). Therefore `kread`/
  `kwrite` work without kcall.
- `kalloc`/`kmap` are IOSurface-based and may hit `pmap_expand_range`; they are
  best-effort when kcall is unavailable. Extmod zeroing only needs `kwrite`,
  so it does **not** depend on kcall.

### How Dopamine-roothide worked without kcall

Dopamine's jailbreak flow is built on `physrw` + XPF offsets + `kwrite`:
trustcache upload, launchd hook injection, and protection patching are all
kernel-memory writes, not kernel function calls. Where a kernel function was
needed (page-table expansion, MAC labels, thread-state signing), libjailbreak
either had a direct page-table fallback or only used it on devices where the
bypass provided `kcall`. So "no kcall" never meant "no kernel R/W"; it meant
"some convenience operations are unavailable".

For this tool: kernel R/W and extmod zeroing are designed to work without
kcall. `kcall` is exposed for callers that need it and is reported in the log.

## 5. extmod offset: problem and solution

### Problem

`task->extmod_statistics` is an inline struct (6 x int64, 48 bytes), but its
offset depends on the kernel build. XPF's `struct` set currently exports
`task.map`, `task.threads`, `task.itk_space`, `task.flags`,
`task.task_can_transfer_memory_ownership`, `task.mach_trap_filter_mask`,
`task.mach_kobj_filter_mask`, `task.security_config` — **not**
`task.extmod_statistics`. So `koffsetof(task, extmod_statistics)` is not
available.

The supported matrix is large (iOS 15.0-18.7.1 and 26.0-26.0.1 for A12/A13;
15.0-17.3.1 for other arm64e; plus SPTM/TXM devices), so a hand-written table
is not practical.

### Solution in this tree

`DOJailbreaker` resolves the offset in this order:

1. **Learned cache**:
   `/var/mobile/Documents/kernelrw_extmod_offsets.plist`
   (`kern.osversion` -> offset). Verified read-only before use.
2. **Pinned table**: `kDOKRWExtmodOffsets` in `DOJailbreaker.m`. Empty by
   default; add verified `{ "22F76", 0xNNN }` entries here when you have them.
3. **Runtime discovery** (device-agnostic):
   - `task_info(mach_task_self(), 19, ...)` reads our own 6 counters.
   - Counters only change when *another* task touches us
     (`extmod_statistics_incr_*` returns early when target == caller), so we
     perturb:
     - try `task_for_pid` on other same-uid processes found by walking the
       `proc` list (`koffsetof(proc, list_next)`, `koffsetof(proc, pid)`);
     - if that fails, `posix_spawn` our own executable in
       `krw-perturb-helper` mode. The child calls
       `task_for_pid(getppid())`, which bumps the parent's
       `task_for_pid_count`.
   - Read our stats, scan `0x1000` bytes of our `task_t` for the exact 48-byte
     pattern on 8-byte boundaries.
   - Repeat up to 4 times and intersect candidate offsets, so the true offset
     (whose counters change each round) survives and static zero-runs drop out.
   - Save the result to the cache for the current `kern.osversion`.
4. **Refuse**: if no offset is resolved, `zeroExtmodStatisticsForTask:` returns
   `NO` and logs. No blind kernel write.

Public API:

```objc
@property (nonatomic, readonly) uint32_t extmodOffset;
- (BOOL)resolveExtmodOffset;
- (BOOL)zeroExtmodStatisticsForTask:(uint64_t)task; // uses resolved offset
- (BOOL)zeroExtmodStatisticsForPid:(pid_t)pid;      // uses resolved offset
- (BOOL)zeroExtmodStatisticsForTask:(uint64_t)task offset:(uint32_t)offset;
- (BOOL)zeroExtmodStatisticsForPid:(pid_t)pid offset:(uint32_t)offset;
```

The explicit-offset variants remain for callers that already know the offset.

### Known risk

If both `task_for_pid` paths are denied, discovery cannot run on a fresh build.
In that case only the pinned table / cache can supply the offset. The log says
exactly which step failed, so a device run tells you whether to pin an offset.

## 6. File logging

`DOKRWLog(NSString *format, ...)` is declared in `DOJailbreaker.h` and defined
in `DOJailbreaker.m`. It:

- writes to `/var/mobile/Documents/DopamineKernelRW.log` (append);
- creates `/var/mobile/Documents` if missing;
- falls back to the app container `Documents/DopamineKernelRW.log` if the
  system path is not writable;
- mirrors to `NSLog` with the `[KernelRW]` prefix.

The app has `com.apple.private.security.no-sandbox`, so `/var/mobile/Documents`
is expected to be writable. Logged points: UI request, patchfinding, exploit
selection, physrw choice, cleanup, final base/slide/kcall, and every extmod
resolution step (including candidate counts).

The offset cache uses the same directory.

## 7. UI cleanup

`DOMainViewController.m`:

- button is "Get Kernel R/W" / "Kernel R/W Ready";
- success alert shows base/slide/kcall;
- no respring / reboot-userspace / jailbreak-state checks;
- dead `simulateJailbreak` removed.

`DOSettingsController.m` `specifiers` now contains:

- header;
- exploit selection (kernel / PAC / PPL) — kept, it is required for kernel R/W;
- "Kernel R/W" group with Verbose Logs and iDownload;
- customization (theme);
- credits/license.

Removed: tweak injection, app JIT, dyld patch, jetsam multiplier, remove
jailbreak switch, bootstrapped actions (refresh apps, change mobile password,
reinstall package managers, hide/unhide jailbreak), boot-logo customization.

Unused handler methods for the removed specifiers are still present in the
file; they are unreachable from the UI. They can be deleted later without
affecting behaviour.

## 8. Build and CI

- Workflow: `.github/workflows/main.yml`, triggers on push to any branch,
  `macos-latest`, recursive submodules, Theos + iPhoneOS16.5 SDK, `gmake
  NIGHTLY=1`, uploads `.ipa` and `.tipa`.
- Remote: `https://github.com/gireevbatyr2-a11y/Dopamine-roothide.git`.
- Push the branch, then watch the run with `gh run list` / `gh run watch`.
- If the build fails, the most likely spots are the new extern declarations
  (`task_info`, `task_for_pid`), `posix_spawn` on iOS, and the `@synchronized`
  block in `resolveExtmodOffset`. Fix compile errors first; runtime behaviour
  can only be validated on a device.

### Push and build status (success, 2026-11-26)

The app-process PPL + roothide cleanup button is built at `f388db8`.

- Run: https://github.com/gireevbatyr2-a11y/Dopamine-roothide/actions/runs/45868655502
- Conclusion: success (Build, Upload Artifact, Upload Artifact(TIPA)).
- Artifacts (not expired, 47,983,649 bytes):
  - `roothide-FFKRW-(3.0.13-30-9617d75)-2026.11.06-UTC-02.17.10.ipa`
  - `roothide-FFKRW-(3.0.13-30-9617d75)-2026.11.06-UTC-02.17.10.tipa`
- The run built commit `f388db8` (no spawned-helper PPL; app-process
  `obtainKernelRWInProcess`; `Remove roothide leftovers` menu action backed by
  `DOEnvironmentManager deleteBootstrap` + icon cache rebuild).
- Process/display/bundle are `FFKRW` / `FFKRW` / `com.ffkrw.FFKRW`;
  runtime log/socket/state are `FFKRW.log` / `FFKRW.sock` / `FFKRW.state`.

Roothide build `45832341640` (`1fe4353`) is also success, but on-device it
did not persist: after the userspace reboot the app returned to
"Get Kernel R/W" and process connect said "get kernel r/w, then connect to a
process"; the bootstrap asked to set a password. The launchdhook/jailbreakd
did not come up, so the helper path is now the default.

Previous runs: `45868655502` success (`f388db8`). `45860706131` (`08123b3`,
helper argv `krw-helper`) success, but that helper ran Titan PPL and panicked
in `IOSurface` (`panic-full-...202700`: Kernel data abort, IOSurface kext).
`45856197340` (`c5f2014`, helper startup logs) success, but helper fell through
to `UIApplicationMain`. `45854272241` (`dd1edc0`) failed on private
`proc_bsdinfo`; fixed. `45850140545` (`ad53d5a`) success (60 s wait/no second
in-process/release dummy UI/FFKRW). `45842992120` (`b926ce1`, first helper
with dummy UI) success. `45832341640` initially failed before compiling
because the runner could not resolve `raw.githubusercontent.com` while
installing THEOS; rerun succeeded. `45830025017` failed because
`injectLaunchdHook` was missing its closing brace (fixed in `1fe4353`).
`45806453556` (`cb1a0fa`, fork-child SIGBUS workaround, waitpid, theme icons),
`45801834098` (`efeaa21`, no same-boot re-exploit, short helper socket, FFKRW
icons, Sileo/Zebra removed), `45799983758` failed (removed `.deb` still
referenced by the Xcode project), `45792538497` (`a5c4946`, auto re-acquire +
FFKRW boot logo; the auto re-acquire caused the GFX panic),
`45788389040` (`0e5eaeb`, in-process ClearSword + Titan, fork helper),
`45781966540` (`771b5aa`, posix_spawn helper + FFKRW header),
`45776362820` (`3f44da3`, single Builder, kernel-only process connect),
`45770706349` (`e5f9898`, extmod fallback/branding),
`45766775974` (`6de2c57`, action menu restore),
`45714171508` (`e81874b`, button hide/boot logs/kfd migration),
`45707510584` (`2fc2cc2`, overlay collapse/boot guard),
`45701419608` (`3a20cf7`, panic fix/logging), `45696416257` (`6ef26bf`,
cleanup) and `45691924997` (`2ff72c3`, process list).

## 8b. Process list tab (added 2026-11-25)

`DOMainViewController.m` defines `DOProcessListViewController` as a private
class (no `.pbxproj` change). It is reachable from the action menu entry
"Processes".

- Lists pids with `proc_listpids(PROC_ALL_PIDS, ...)` and names with
  `proc_name()` (declared manually; no `libproc.h` dependency).
- Pull-to-refresh plus a Refresh bar button.
- Tapping a row calls `task_for_pid(mach_task_self(), pid, &port)`.
- On success it keeps one task port at a time and calls
  `zeroExtmodStatisticsForPid:` so the target's `task_for_pid_count` (and the
  other five extmod counters) are reset. The alert reports whether zeroing
  succeeded; the log records the reason when it did not.
- Requires `kernelRWReady`; otherwise it asks the user to get kernel R/W first.
- All actions log `process: ...` lines to the same file.

## 8c. Kernel R/W button audit (2026-11-25)

The button no longer touches any jailbreak state:

- `DOEnvironmentManager.isJailbroken` returns `NO` unconditionally; the app
  never reports or enters a jailbreak state, even if the device has roothide.
- `DOJailbreakButton` no longer shows the Sileo/Zebra package manager picker;
  `expandButton:` unlocks immediately and the title is "Kernel R/W".
- Settings no longer contains "Verbose Logs" or "iDownload"; the "Kernel R/W"
  group and its helpers were deleted.
- The contiguous-mapping workaround was removed from the UI and from
  `DOJailbreaker` (`crashBackboardd` / `crashBackboardd_15` /
  `applyContiguousMappingWorkaround`). The button can no longer crash
  backboardd or exit the app.
- `completeJailbreak` was renamed to `completeKernelRW` (it only calls
  `[logView didComplete]`).
- `startKernelRW` goes straight to `lockMutex` -> `obtainKernelRW`; the
  pipeline stops after physrw. No `elevatePrivileges`, `injectLaunchdHook`,
  `prepareBootstrap`, `finalize`, `removeJailbreak`, respring or reboot.

The `UI/PkgManagers/*` picker classes have since been removed (see 8d);
only `PkgManagers.plist` remains for `DOBootstrapper`.

## 8d. Kernel panic diagnosis and fix (2026-11-25)

The user's iPhone13,2 (A14) on iOS 16.6 (20G75) panicked after tapping
Get Kernel R/W. `panic-full-2026-11-25-235533.000.ips`:

- `Kernel data abort`, fault address `0xffffffdff2940000`.
- Probabilistic GZAlloc: zone `semaphores`, element
  `[0xffffffdff293ffc0, 0xffffffdff2940000)` (64 bytes), out-of-bounds,
  1 byte past.
- Panicked task: pid 981 `Dopamine`.

That zone belongs to kfd `landa`, which was the default kernel exploit
(priority 900; `kread_sem_open` / `kwrite_sem_open`). Fix:

- Lowered `kfd` `landa` `DPFlavorPriority` from 900 to 880, so ClearSword
  (895) is the preferred kernel exploit on iOS 16.6. ClearSword uses
  socket/IOSurface primitives and does not touch the `semaphores` zone.
- `kfd` remains selectable in Settings -> Kernel Exploit as a fallback.
- If ClearSword still panics, select DarkSword (890); both are supported on
  15.0-18.7.1.

Logging fix: `DOKRWLog` now tries `/var/mobile/Documents/`,
`/var/mobile/Library/Logs/` and the app container, logs the chosen path via
`NSLog`, writes `main: launch` at startup, and the success alert shows the
log path. The container path is
`.../Containers/Data/Application/<UUID>/Documents/DopamineKernelRW.log`.

Dead jailbreak code removed:

- `UI/PkgManagers/DOPkgManagerPickerView.{h,m}`,
  `DOPkgManagerPickerViewController.{h,m}`, `DOAppSwitch.{h,m}` and their
  pbxproj entries. `PkgManagers.plist` stays because `DOBootstrapper` still
  reads it.
- `main.m`: TrollStore `delete-bootstrap`, legacy `prepare_jbupdate` (which
  called `reboot`) and the `isJailbroken` PATH/TERM block.

## 8e. Post-success UI collapse and boot-session guard (2026-11-26)

The user's log (`DopamineKernelRW.log`) shows ClearSword, DarkSword and kfd
`landa` all completing on a fresh boot. The panic only happened when a second
exploit was started in the same boot after relaunching the app.

Fixes:

- `DOJailbreakButton.collapseButton` removes the log view, title and
  `DODoubleHelixIndicator` (stops the infinite animation), deactivates the
  expanded constraints and reactivates the original ones. The button returns
  to the bottom and the main UI (Settings/Processes/Credits) becomes usable.
- `DOMainViewController.finishKernelRWUI` calls `collapseButton` on both
  success and failure, restores the header transform, re-enables the update
  button and restores the home indicator.
- `DOJailbreaker.obtainKernelRW` now stores `kern.bootsessionuuid` and
  `DOKRWExploitRan` in `NSUserDefaults`. After a successful exploit, a second
  attempt in the same boot returns "Kernel R/W was already acquired in this
  boot. Reboot the device before running the exploit again." instead of
  re-running an exploit over modified kernel state (which panics). A new boot
  UUID clears the flag automatically.

The primitives (physrw, kread/kwrite) live in the app process, so kernel R/W
persists while the app stays alive. If the app is killed, the primitives are
lost; reboot before trying again. A persistent helper/daemon (Serotonin-style)
would be needed to survive app termination.

## 8f. kfd landa instability and UI visibility (2026-11-26)

Log from the device:

- 01:11:45 kfd landa starts, then the app hangs; Jetsam kills Dopamine
  with 10240 open fds (kfd `kread_sem_open` opens `maxfilesperproc - 100`).
- 01:14:55 kfd landa succeeds; 01:15:35/37 extra presses only return
  "kernel R/W ready" (no re-run); 01:16:12 panic
  `shared_region_pager_data_return @vm_shared_region_pager.c:444` in
  kernel_task. That is delayed kfd landa/PTE physrw corruption, not the
  button press. ClearSword and DarkSword are stable.

Fixes:

- `finishKernelRWUI:` hides the jailbreak button on success, so the main
  stack (header, Settings/Processes/Credits) is visible; it logs the
  button frame and stack state. On failure the button stays visible.
- `collapseButton` logs frame and constraint counts.
- Boot guard logs `kern.bootsessionuuid`, last UUID, `DOKRWExploitRan` and
  the Preferences path, and writes `DopamineKernelRW.state` next to the
  log.
- `DOExploitManager` performs a one-time migration that clears a saved
  kfd kernel-exploit preference, so ClearSword becomes the default. kfd
  remains selectable manually.

Recommendation: use ClearSword or DarkSword on 16.6. kfd landa can
exhaust fds and panic the shared-region pager.

## 8g. Persistence across app termination (planned)

Kernel R/W lives in the app process (`gPrimitives`, physrw). If iOS kills
the app, the primitives are gone. Serotonin-style persistence needs a
separate helper that owns the primitives and serves requests. Two options:

1. `posix_spawn` helper from the app: the helper runs the exploit once and
   serves kread/kwrite/zero-extmod over a Unix socket; the app becomes a
   client. The helper can `setsid` to survive app termination, but iOS may
   still kill it.
2. `LaunchDaemon` plist installed via kernel R/W: survives app termination
   and starts at boot; this modifies `/Library/LaunchDaemons` (jailbreak-like).

Not implemented yet; needs a decision on the approach.

## 8h. Empty screen after success and per-boot button (2026-11-26)

The log showed `jailbreakHidden=1`, `stackHidden=0`, `stackAlpha=1.00`, yet
the screen was empty. Cause: the button handler calls `[actionView hide]`
before expanding, and `DOActionMenuView` had only `hide`, no `show`. The
Settings/Processes/Credits menu stayed at alpha 0 with a 0.6 scale, so the
main screen looked empty.

Fixes:

- Added `-show` to `DOActionMenuView` (alpha 1, identity transform,
  interaction enabled) and call it from `finishKernelRWUI:`, so the menu
  returns after success and after failure.
- `exploitRanThisBoot` on `DOJailbreaker` checks the boot UUID and
  `DOKRWExploitRan`. `viewWillAppear` hides the Get Kernel R/W button when
  it is true, so after one successful run the button stays gone for the
  rest of the boot. A reboot changes the UUID, the flag clears and the
  button appears again.
- The success alert still shows base/slide/log path.

## 8i. Process extmod via kernel task; branding (2026-11-26)

Process list: `task_for_pid` returns 5 (`KERN_FAILURE`) for App Store apps
(Textastic, FreeFire, Instagram, ...). `DOJailbreaker` resolves the kernel
task with `proc_find`/`proc_task`, so extmod zeroing does not need a task
port. `connectToPid:` no longer calls `task_for_pid` at all; it calls
`zeroExtmodStatisticsForPid:` directly. 20G75 is pinned to `0x438` in
`kDOKRWExtmodOffsets`, so the offset-discovery helper (the only remaining
`task_for_pid` user, for unknown builds) does not run on this device.

Branding:

- Credits header is "FFKRW - Credits" instead of "Dopamine <version> - Credits".
- Source Code button -> https://t.me/FFCHEATScom, icon `paperplane.fill`,
  label "Telegram Channel".
- Discord button -> https://t.me/FFEXTERNALMOD, icon `person.3.fill`,
  label "Telegram Group".
- The second "BUILDER" came from `.github/workflows/main.yml`
  (`plutil -insert items.4/5`); those lines are removed. The source
  `Credits.plist` has one "Builder" with Slinger (https://t.me/abcdfdkjd);
  `roothider` is in Developers.
- `Credits_Made_By` now includes Slinger in every localization.

## 8j. Persistent helper and FFKRW header (2026-11-26)

The first helper design ran `obtainKernelRWInProcess` in a `posix_spawn`
child. On 20G75 it failed at Titan: `exploitation failed: Failed to bypass
PPL`. Titan's `gfx_reset` needs `[UIApplication sharedApplication]`, and a
plain `posix_spawn` child has no UIApplication.

The current design runs the exploit in the app process (where UIKit exists)
and then forks:

- `obtainKernelRW` first reconnects to an existing helper. If none exists it
  runs `obtainKernelRWInProcess` in the app (ClearSword + Titan PPL works),
  then `DOKRWHelperFork` creates the helper.
- `DOKRWHelperFork` binds a Unix socket in `NSTemporaryDirectory()`, calls
  `fork()`, and the child inherits the ready `gPrimitives`, `gSystemInfo`,
  `g_ctx` sockets and the resolved extmod offset.
- The child (`DOKRWHelperServeForked`) only uses `accept`/`read`/`write`,
  ClearSword's socket-based `kreadbuf`/`kwritebuf`, and
  `proc_find`/`proc_task`/`proc_rele`. It does not touch ObjC, libdispatch,
  malloc or stdio after fork.
- The app proxies `zeroExtmodStatisticsForPid:`/`kread`/`kwrite` to the
  child and reconnects in `viewWillAppear` after a relaunch.
- The boot guard records `DOKRWExploitStarted` before the exploit. If the
  child dies, the app requires a reboot instead of running a second exploit
  in the same boot.
- No jbroot, no launchd hook, no jailbreak state, no reboot. The fork child
  is detached and survives app termination, but iOS can still kill it; then a
  reboot is required.

The main header logo is rendered at runtime as a white heavy rounded "FFKRW"
wordmark via `+[DOHeaderView ffkrwLogo]`, replacing the `Dopamine` image.

Device result: the first fork attempt logged `helper fork failed; in-process
only`; the fork child was not created. The app now clears the boot guard after
a completed exploit and auto re-acquires on relaunch (`Re-acquire Kernel
R/W`). This restores kernel R/W in a new app process but is not persistence; a
force-quit still loses the primitives and a failed re-acquire requires reboot.

## 8l. Logo cleanup (2026-11-26)

- `DOTheme` boot logo now uses `[DOHeaderView ffkrwLogo]` instead of
  `DopamineLogo`; the `roothide` text in the Dopamine theme boot logo is gone.
- Main header already uses `ffkrwLogo`.
- `DopamineLogo`/`Dopamine` image assets are no longer referenced.
- App icon assets still contain the old artwork; if the home screen icon is
  meant, a separate FFKRW icon has to be generated.

## 8m. Same-boot panic and cleanup (2026-11-26)

`panic-full-2026-11-26-125725.000.ips` shows
`GFX NMI: GFXEndpoint2 ... error=0xe00002db`. The app had auto re-acquired
after the user force-quit it, so Titan/IOGPU ran a second time in the same
boot. Re-running the exploit in one boot is unsafe.

- Auto re-acquire is removed. After a force-quit the button stays hidden and
  the log says `UI: kernel R/W already acquired this boot; reboot required`.
  No second exploit, no GFX panic.
- `helper: bind failed errno=48 Address already in use` was caused by the long
  socket path being truncated in `sockaddr_un.sun_path`. The helper socket is
  now `/tmp/DopamineKernelRW.sock`.
- The previous `posix_spawn` helper (pid 374) survived app termination and held
  the old socket, which is why `bind` failed. A successful fork child should
  survive the same way; this build tests that.
- Home screen icons: all `AppIcon*` sets now contain generated FFKRW artwork.
- Sileo/Zebra/roothideapp `.deb` files, assets, licenses and bootstrap installs
  are removed; `PkgManagers.plist` is empty; Xcode resource references are
  removed. App artifact size dropped from ~55 MB to ~44.5 MB.
- True roothide persistence (if the fork child still dies) means restoring the
  original `DOJailbreaker` launchd pipeline: `prepareBootstrap` ->
  `injectLaunchdHook` -> `finalizeBootstrap`, then a userspace reboot. The
  repo still contains `BaseBin/launchdhook`, `jailbreakd` and
  `DOBootstrapper`, but the original `DOJailbreaker` injection methods would
  have to be ported back. That enters roothide jailbreak state.

## 8n. Fork child SIGBUS and theme icons (2026-11-26)

`Dopamine-2026-11-26-134845.ips` is the **fork child** (pid 351, parent 295),
not the app: `EXC_BAD_ACCESS/SIGBUS KERN_PROTECTION_FAILURE at
0x102330844`, backtrace `DOKRWHelperFork`. The child died immediately after
fork; the app then waited 120 s in `DOKRWHelperWaitReady`, which looked like a
never-ending PPL step.

- `gDOKRWHelperReady` is now set before `fork`, so the child no longer writes
  that global; the child only runs `DOKRWHelperServeForked`.
- `DOKRWHelperWaitReady` now calls `waitpid(..., WNOHANG)` and returns at once
  if the child died (`helper: exited status=0x...`). Timeout reduced from
  120 s to 15 s.
- If the child still crashes, the in-process kernel R/W remains usable and the
  app no longer hangs; after a force-quit the boot guard still requires reboot.
- Icons: regenerated from the actual theme backgrounds:
  `Background_Green.jpg` for Dopamine/`AppIcon`, `Background_ElleKit.jpg` for
  ElleKit, plus Blue/Purple/Red. The home screen icon now matches the in-app
  theme colors.
- `External-iOS-App` was inspected: it only has `SpawnRoot` (`posix_spawn` as
  root) and `UIBackgroundModes`; no launchd/daemon persistence. It does not
  provide an unkillable process.

## 8o. Roothide launchd persistence (2026-11-26)

The fork child still died with `SIGBUS` (`helper: exited status=0xa`) even
after the pre-fork `gDOKRWHelperReady` change. The in-process kernel R/W kept
working (`process: connected ... extmod zeroed=yes`) but no helper survived the
app. The helper path is abandoned.

The original roothide pipeline was ported from
`9617d75.../Application/Dopamine/Jailbreak/DOJailbreaker.m`:

- `runWithError:didRemoveJailbreak:showLogs:`
- `injectLaunchdHook` (boomerang + `jbctl` + `opainject`)
- `elevatePrivileges`, `showNonDefaultSystemApps`, `ensureDevModeEnabled`
- `loadBasebinTrustcache`, `removeJailbreak`, `finalizeBootstrapIfNeeded`
- `cleanUpPostExploitation`, `finalize` (userspace reboot)
- missing `JBErrorCode` cases, imports and C declarations

`DOJailbreaker` now treats an existing roothide jailbreak as
`kernelRWReady`, and the UI `startKernelRW` calls `runWithError:` and then
`finalize` instead of `obtainKernelRW`. The duplicate
`@implementation DOMainViewController` that shadowed the new code was removed.
`viewWillAppear` hides the button when `isJailbroken`.

Build notes:

- `BaseBin` `install_name_tool -delete_rpath` errors are non-fatal (`|| true`);
  the app target still builds.
- `45830025017` failed on the missing closing brace of `injectLaunchdHook`.
- `45832341640` first failed on runner DNS (`raw.githubusercontent.com`),
  rerun succeeded.
- Final: `45832341640` success, commit `1fe4353`.

App icon note: the home screen uses alternate icons; the app switcher/primary
icon uses `AppIcon`/snapshot. Changing the theme only changes the home screen.
After the roothide jailbreak, `uicache`/a respring should refresh the primary
icon cache. The primary `AppIcon` is currently generated from
`Background_Green.jpg`.

## 8p. Helper persistence restored + roothide device result (2026-11-26)

Roothide build `45832341640` (`1fe4353`) installed, but on-device behaviour:

- the roothide steps ran and the userspace reboot happened;
- the bootstrap asked to set a password (`prep_bootstrap.sh`);
- after reboot the app went back to "Get Kernel R/W" and process connect said
  "get kernel r/w, then connect to a process";
- `isJailbroken` was false, so `launchdhook`/`jailbreakd` did not come up.

Restored the `posix_spawn` helper path (the old separate process survived app
termination; only the fork child crashed):

- `DOKRWHelperSpawn` uses `posix_spawn` with `POSIX_SPAWN_SETSID`, the app
  binary, argument `DOKRWHelper` and `/tmp/DopamineKernelRW.sock`.
- `DOKRWHelperStartIfNeeded` spawns the helper before the in-process fallback;
  no `fork` child is used.
- UI `startKernelRW` uses `obtainKernelRW` again.
- `gfx_reset` falls back to a dummy `UIWindow`/`DONavigationController` when
  there is no connected scene, so Titan PPL can run in the helper.

Build `45842992120` success (`b926ce1`), artifacts 47,984,153 bytes.

Research:

- `lara` (`rooootdev/lara`) has `lara/kexploit/persistence.m` with
  `transfer_krw_to_launchd_ios16`: it bootstrap-registers the exploit's
  control/rw socket fileports into launchd and stores sandbox extension
  tokens in `NSUserDefaults`; `recover_krw_primitives` restores them after an
  app restart. This is a lighter launchd stash than roothide. lara officially
  targets iOS 17.0-18.7.1; iOS 16.7.2 is tested; iOS 16.6 is not listed, but
  the iOS 16 persistence path exists.
- `cyanide` (`0xjohnnydev/cyanide`) is a DarkSword tweak runner; it has no
  launchd stash/persistence.
- Background Modes do not survive force-quit; the helper or launchd stash is
  the only practical no-jailbreak persistence.

## 8q. Helper timing fix, Jetsam and FFKRW rename (2026-11-26)

`DopamineKernelRW.log` from the rebooted device showed:

- `18:22:55 helper: spawned pid=357` and `main: launch pid=357 argc=3`;
- helper in-process exploit started at `18:23:16` (21 s after spawn);
- the app's `DOKRWHelperWaitReady(20000)` timed out about 1 s earlier, so the
  app also ran its own in-process exploit and then logged
  `obtainKernelRW: helper fork failed; in-process only`;
- process connect worked via the helper/in-process; app relaunch at
  `18:23:52` logged `UI: kernel R/W already acquired this boot; reboot
  required`, and process connect said `get kernel r/w`;
- Jetsam event at `18:24:07`; the dummy helper UI plus the app/helper double
  exploit likely caused the helper/app loss after close.

Fixes in `ad53d5a`:

- `DOKRWHelperWaitReady` timeout is 60 s; helper takes ~21 s to start.
- If `gDOKRWHelperPid` is alive after `DOKRWHelperStartIfNeeded`, the app
  returns "helper is still starting" instead of running a second in-process
  exploit.
- The helper drops its dummy `UIWindow`/`DONavigationController` after the
  PPL succeeds, reducing Jetsam pressure.
- Renamed user-visible/build names to FFKRW:
  - product/process/display `FFKRW`, bundle `com.ffkrw.FFKRW`;
  - runtime `FFKRW.log`, `FFKRW.sock`, `FFKRW.state`;
  - prefs/error/license/idownloadd names `FFKRW`;
  - Makefile/workflow artifacts `roothide-FFKRW-...`.
- Build `45850140545` success (`ad53d5a`), artifacts 47,983,676 bytes.

If the helper still dies after force-quit, the robust path is the `lara`
launchd stash: `Application/Dopamine/Exploits/ClearSword/exploit/common.h`
already exposes `g_ctx.control_socket` and `g_ctx.rw_socket`, and
`lara/kexploit/persistence.m` has `transfer_krw_to_launchd_ios16`
(`RemoteCall` into launchd + `fileport_makeport` + `bootstrap_register` +
sandbox extension tokens in `NSUserDefaults`; `recover_krw_primitives` calls
`bootstrap_look_up`/`fileport_makefd`). That keeps the sockets alive in
launchd without a full jailbreak. lara officially targets iOS 17-18.7.1;
iOS 16.7.2 tested; iOS 16.6 is not listed, but the iOS 16 persistence code
exists. `cyanide` has no launchd stash.

## 8r. Helper exits before serving; startup diagnostics (2026-11-26)

`FFKRW.log` from the 18:53 device run:

- `18:53:02 main: launch pid=325 argc=1` (app);
- `18:53:06 helper: spawned pid=338` and `main: launch pid=338 argc=3`;
- helper never logged `helper: listening`;
- `18:54:08 UI: kernel R/W failed: ... helper is still starting`;
- Jetsam events at `18:53:08` and `18:54:16` are about TikTok; no `FFKRW`
  process is killed in them.

So the helper exits/crashes during its own startup (before socket/bind/listen)
or `DOKRWHelperMain` is not reached; the app's `kill(pid,0)` treated a
zombie/reused pid as alive and waited the full 60 s.

Fixes in `c5f2014`:

- `DOKRWHelperMain` logs `main start`, `setsid`, `socket`, `bind`, `listen`
  and errno at each step.
- `DOKRWHelperProcessAlive` uses `proc_name == FFKRW` instead of only
  `kill(pid, 0)`; private `proc_bsdinfo` was removed after a compile failure.
- `DOKRWHelperWaitReady` handles `waitpid` `ECHILD` and aborts when the helper
  is not alive and the socket is not connectable, clearing the pid.
- Build `45856197340` success (`c5f2014`), artifacts 47,984,017 bytes.

The next device log will show whether `DOKRWHelperMain` is reached and whether
`setsid`/`socket`/`bind`/`listen` fails. If the helper is still killed by the
OS at startup, the launchd stash (lara `transfer_krw_to_launchd_ios16`) is the
fallback, now with the ClearSword `g_ctx.control_socket`/`rw_socket` sockets.

## 8s. Helper argv mismatch; roothide leftovers (2026-11-26)

`FFKRW.log` at 19:32 showed again only `main: launch pid=349 argc=3` for the
helper. `JetsamEvent-...193419.ips` lists `PROC 349 FFKRW rpages 200
states ['daemon']` — the helper was alive as a **second app instance**.

Cause: `DOKRWHelperSpawn` passed argv[1] `"DOKRWHelper"`, but `main.m` only
recognized `"krw-helper"`:

```objc
if (argc >= 3 && !strcmp(argv[1], "krw-helper")) {
    return DOKRWHelperMain(argv[2]);
}
```

So the helper fell through to `UIApplicationMain`, never opened
`/tmp/FFKRW.sock`, and the app waited 60 s.

Fixed in `08123b3`:

- `DOKRWHelperSpawn` sends `"krw-helper"`;
- `main.m` accepts both `krw-helper` and legacy `DOKRWHelper`;
- build `45860706131` success, artifacts 47,984,175 bytes.

Roothide leftovers from the `1fe4353` device test (code inspected):

- `DOBootstrapper prepareBootstrap` extracts the bundled bootstrap to `/`,
  creates the `/var/jb` symlink to `JBROOT_PATH`, extracts `basebin.tar` into
  `JBROOT_PATH/basebin`, then `finalizeBootstrap` runs
  `prep_bootstrap.sh` (the password prompt), installs `launchctl`, `libroot`,
  `libkrw`, `basebin-link.deb`.
- `runWithError:` also loads the basebin trustcache, injects
  `launchdhook.dylib`, starts/uses `jailbreakd`, applies dyld/exec patches,
  sets jailbroken and userspace-reboots.
- `removeJailbreakEnabled` defaults to NO, so no `removeJailbreak`/
  `deleteBootstrap` ran.
- A simple reboot clears in-memory launchdhook/dyld/exec/trustcache, but the
  `/var/jb` symlink, preboot jbroot, bootstrap, `basebin` (launchdhook,
  jailbreakd, basebin.tc), `prep_bootstrap.sh` and the root password remain.
- Cleanup: old app Settings -> Remove Jailbreak (`removeJailbreakEnabled`),
  or `DOBootstrapper deleteBootstrap` (line ~607), which removes the
  bootstrap/basebin/`/var/jb`; then `uicache`/respring and remove old
  Sileo/Zebra leftovers. The roothide userspace reboot did not persist, so
  the launchdhook/jailbreakd are not active after a full reboot; the files
  and root password are what remain.

If the helper still fails after `08123b3`, the lara launchd stash remains the
fallback; `cyanide` has no stash, and Background Modes do not survive
force-quit.

## 8t. Helper PPL panic; in-process PPL and cleanup button (2026-11-26)

`panic-full-2026-11-26-202700` is a `Kernel data abort` in `IOSurface`
(`com.apple.iokit.IOSurface` in the backtrace). The spawned helper ran its own
Titan PPL with the dummy UIWindow and panicked. The app-process PPL worked
earlier (18:22), so `f388db8` removes the helper from `obtainKernelRW` and
returns to `obtainKernelRWInProcess`. The helper code remains unused.

Also added a `Remove roothide leftovers` action to the main menu:

- calls `DOEnvironmentManager deleteBootstrap`;
- if not jailbroken and uid != 0, that uses the TrollStore
  `delete-bootstrap` action; otherwise it runs as root/unsandboxed;
- `DOBootstrapper deleteBootstrap` makes `/private/preboot` writable and
  removes the jbroot parent plus `/var/jb` (bootstrap, basebin,
  launchdhook/jailbreakd, `prep_bootstrap.sh`, root password inside);
- then `rebuildIconCache` and `rebootUserspace`.

Caveat: if the app is not installed through TrollStore and has no root, the
TrollStore action is the only path; if that fails, `/var/jb`/bootstrap cannot
be removed from the app sandbox. The old roothide app Settings -> Remove
Jailbreak, or a root shell, remains a fallback.

Build `45868655502` (`f388db8`) success, artifacts 47,983,649 bytes.

The persistence path remains lara's launchd stash: the app-process PPL gives
`g_ctx.control_socket`/`rw_socket`; `transfer_krw_to_launchd_ios16` +
`fileport_makeport` + `bootstrap_register` + sandbox tokens, and
`recover_krw_primitives` on relaunch. `cyanide` has no stash; Background
Modes do not survive force-quit.

## 8k. Research: unkillable process without jailbreak (2026-11-26)

Public projects and docs agree that a true persistent daemon needs a
jailbreak/launchd hook:

- TrollStore README: "Spawning a launch daemon (Would need
  `CS_PLATFORMIZED`)" is listed under "Things that are not possible using
  TrollStore" (https://github.com/opa334/TrollStore).
- Serotonin README: it replaces launchd and requires a userspace reboot
  (https://github.com/SerotoninApp/Serotonin).
- roothide Bootstrap/Dopamine: bootstrap + launchd hook
  (https://github.com/roothide/Bootstrap,
  https://github.com/roothide/Dopamine-roothide).
- LiveContainer runs apps inside a host app; killing the host stops them
  (https://github.com/LiveContainer/LiveContainer).

A detached `posix_spawn`/`fork` child, `setsid`, ignoring `SIGHUP`, or
`beginBackgroundTask`/background modes do not make a process immune to
launchd/Jetsam `SIGKILL`. RunningBoard/`BKProcessAssertion` and
`os_transaction` are private/entitled and still not a guarantee. Kernel R/W
could patch launchd/AMFI to load a daemon, but that is a jailbreak-like
modification and normally needs a reboot. Therefore the fork helper is the
best-effort maximum without jailbreak state.

## 9. Next steps

1. Commit and push `kernel-rw-only`; trigger the Actions build; fix compile
   errors until the `.ipa`/`.tipa` artifacts are produced.
2. On a device, run once and read
   `/var/mobile/Documents/DopamineKernelRW.log`.
3. If `extmod: resolved offset 0x...` appears, the cache now has the entry.
   Copy it into `kDOKRWExtmodOffsets` if you want it pinned for that build.
4. If `extmod: perturbed ...` never appears, the `task_for_pid` paths are
   denied; pin offsets from another source or extend XPF with a
   `task.extmod_statistics` finder.
5. Optional: delete the now-unused jailbreak handler methods and
   `DOJailbreaker.fadeToBlack`/`crashBackboardd` helpers if you want a smaller
   diff.

## 10. How to continue

```bash
cd /workspace/project/Dopamine-roothide
git log --oneline -10
git status
# inspect the current API
sed -n '1,120p' Application/Dopamine/Jailbreak/DOJailbreaker.h
# check the pipeline
grep -n "obtainKernelRW\|gatherSystemInformation\|doExploitation\|buildPhysRWPrimitive\|cleanUpExploits" Application/Dopamine/Jailbreak/DOJailbreaker.m
# check the extmod resolver
grep -n "extmod" Application/Dopamine/Jailbreak/DOJailbreaker.m
```

Do not reintroduce `elevatePrivileges`, `injectLaunchdHook`, `prepareBootstrap`,
`finalize`, `removeJailbreak`, or any respring/reboot call into the kernel-RW
path. If a future change needs them, it belongs in a separate opt-in tool, not
in `obtainKernelRW`.

- 2026-11-26: cleanup button removed; next is lara launchd stash.
