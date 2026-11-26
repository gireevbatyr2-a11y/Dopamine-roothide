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

### Push and build status (success, 2026-11-25)

Write access became available; the branch was pushed at `e81874b`.

- Run: https://github.com/gireevbatyr2-a11y/Dopamine-roothide/actions/runs/45714171508
- Conclusion: success (Build, Upload Artifact, Upload Artifact(TIPA)).
- Artifacts (not expired):
  - `roothide-Dopamine-(3.0.13-30-9617d75)-2026.11.06-UTC-02.17.10.ipa`
  - `roothide-Dopamine-(3.0.13-30-9617d75)-2026.11.06-UTC-02.17.10.tipa`
- The run built commit `e81874b` (button hide, boot logs, kfd migration).

Previous successful runs: `45707510584` (`2fc2cc2`, overlay collapse/boot guard),
`45701419608` (`3a20cf7`, panic fix/logging), `45696416257` (`6ef26bf`, cleanup)
and `45691924997` (`2ff72c3`, process list).

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
