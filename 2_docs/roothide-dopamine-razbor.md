# roothide Dopamine 3.0.13-30 — глубокий разбор

Коммит: `9617d75f476423fdfd33477299c8a1349eb6f375` («3.0.13-30»).
Карта кода: построена graphify-картой (`graphify extract . --code-only`) —
**3849 узлов, 7318 рёбер, 223 сообщества**. Граф сохранён в
`/home/.z/workspaces/con_jsHhhOFyuekrRvbb/roothide-map/graphify-out/`.

Это не конспект README. Ниже — механика каждого слоя, как он связан и почему
работает, с путями к файлам.

---

## 1. Карта репозитория

```
Application/Dopamine/     — джейлбрейк-приложение (TrollStore-installed .ipa)
  ├─ Jailbreak/           — DOJailbreaker, DOExploitManager, DOEnvironmentManager
  ├─ Exploits/            — 10 эксплойтов как XPC-подобных бандлов (dlopen'ятся по Info.plist)
  │   kfd, ClearSword, DarkSword, Titan, badRecovery, dmaFail,
  │   momentarius, multicast_bytecopy, weightBufs, palera1n
  └─ UI/, Extensions/, Dependencies/, Headers/
BaseBin/
  ├─ dopamine/            — CLI-двоичник dopamane (install|activate), Corellium-вариант
  ├─ libjailbreak/        — ЯДРО: krw-примитивы, physrw, trustcache, offsets, jbserver client
  ├─ jailbreakd/          — демон (сервер примитивов, узкий: принимает порт из initPorts[2])
  ├─ launchdhook/         — инжект в launchd: jbserver (локальный), spawn/xpc/ipc/jetsam hooks
  ├─ systemhook/          — DYLD_INSERT_LIBRARIES для инжекта твиков в обычные приложения
  ├─ dyldhook/            — патчи в dyld (fake lib / lv_bypass / spinlock fix)
  ├─ roothidehooks/       — хуки в lsd, cfprefsd, springboard, runningboardd, palera1n, pathhook
  ├─ libroothider/        — blacklist процессов, jailbreakd-launcher, unsandbox
  ├─ boomerang/, forkfix/, jbctl/, opainject/, hookd/, idownloadd/
  ├─ XPF/, ChOma/, MachOMerger/   — патчфайндер, мачо-парсер, мерджер dyld_shared_cache
  └─ _external/           — elk-подобные фреймворки
Packages/                 — deb-пакеты bootstrap (libkrw-provider, libroot, basebin-link)
Standalone/Corellium/     — сборка для Corellium VM
.github/workflows/main.yml — CI
```

---

## 2. Точка входа и общий поток

**`Application/Dopamine/main.m` → UI → `DOJailbreaker`**. Пайплайн
(`DOJailbreaker.m`):

1. **gatherSystemInformation** — найти kernelcache через
   `accessibleKernelPath` (интернет/IPSW, кэш в /var), скачать SPTM/TXM при
   надобности, запустить **XPF** (`xpf_start_with_kernel_path`) и построить
   xdict оффсетов: наборы `translation, trustcache, sandbox, physmap, struct,
   physrw, IOSurface` + опциональные `devmode, badRecovery, arm64kcall, perfkrw`.
   Десериализация → `gSystemInfo` (`libjailbreak/src/info.c`).
2. **doExploitation** — DOExploitManager выбирает Kernel/PAC/PPL эксплойт по
   приоритету (`DPFlavorPriority`), делает `dlopen` + `exploit_init(flavor)`.
3. **buildPhysRWPrimitive** — `physrw_pte_init` (или `physrw_init`).
4. **elevatePrivileges** — kwrite в proc/ucred: uid/gid 0, un-sandbox через
   `mac_label_set(label, 1, -1)`, `CS_PLATFORM_BINARY` + roothide добавляет
   `CS_INSTALLER`; проверка на второй активный джейлбрейк.
5. **launchdhook инжект** — boomerang-сервер в приложении; jbctl пишет порт в
   launchd initPorts[2]; opainject тянет launchdhook.dylib в launchd; jbserver
   в launchd стартует, вытянув krw из приложения по boomerang-каналу.
6. **bootstrap** — `ensureJailbreakRootExists` (случайная папка в
   /private/preboot/<bootManifestHash>/dopamine-<6 random>), basebin,
   trustcache, LaunchDaemons.

**Главное отличие от обычного Dopamine**: jbserver поднимается **внутри
launchd**, а не как отдельный демон — используется ранняя инжекция через
`opainject` и boomerang (handoff примитивов из Dopamine-приложения).

---

## 3. Слой эксплойтов (таблица из Info.plist)

| Эксплойт         | Тип   | Приоритет | iOS          | Devices           |
|------------------|-------|-----------|--------------|-------------------|
| kfd `physpuppet` | Kernel| 1000      | 15.0–15.7.3, 16.0–16.3.1 | все |
| kfd `landa`      | Kernel| 900       | 15.0–15.8.6, 16.0–16.6.1 | все |
| kfd `smith`      | Kernel| 600       | 15.0–15.7.6, 16.0–16.5   | все |
| multicast_bytecopy|Kernel| 950       | 15.0–15.1.1  | без A8/A9/iPad13  |
| weightBufs       | Kernel| 800       | 15.2–15.5    | только arm64e     |
| badRecovery      | PAC   | 1000      | 15.0–15.4.1  | все (beta builds) |
| dmaFail          | PPL   | 1000      | 15.0–16.5.1  | все, искл. A15/A16@20F75 |
| Titan            | PPL   | 999       | 16.1–17.3.1  | A14,A15,A16,A17   |
| momentarius      | PPL   | 999       | 15.0–26.0.1  | A12,A13           |
| ClearSword       | Kernel| 895       | 15.0–18.7.1, 19.0–26.0.1 | beta-билды (23B50xx) |
| DarkSword        | Kernel| 890       | 15.0–18.7.1, 19.0–26.0.1 | beta-билды |
| palera1n         | Kernel| 0         | 15.0–18.999  | arm64 checkm8     |

Механика выбора (`DOExploit.m:isSupported`):
- `DPSupportedRanges` — числовой диапазон версий;
- `DPSupportedDevices` — фильтр по `hw.machine` / `hw.cpufamily` (A8…A17);
- `DPSupportExclude` / `DPSupportInclude` — вкл/выкл по билдам или устройствам
  (тут живут бета-билды и исключения по конкретным CPU).

**Ключевой контракт**: каждый эксплойт экспортирует
`int exploit_init(const char *flavor)` и `int exploit_deinit(void)`. Внутри
`exploit_init` заполняет `gPrimitives.kreadbuf / kwritebuf` (и опционально
`physwritebuf` у Titan/momentarius). Дальше libjailbreak ничего про эксплойт
не знает — чистый ABI.

**Порядок приоритета**: Kernel → PAC (только если нужен: A12–A16, где
arm64e kcall без PAC невозможен) → PPL (если `isPPLBypassRequired`,
`isSPTM` проверяет наличие `SPTMArgs` через xpf).

**Titan** (`Exploits/Titan/exploit/*` — IOGPUDevice.c, gfx.m, ipc_port.c) —
ppl bypass на базе AGX-драйвера (alfie, 2026). Даёт
`titan_physwritebuf`, снимает PPL-ro-защиту на physwrite — это и есть путь
к unrestricted kernel write на 16.1–17.3.1.

---

## 4. libjailbreak — ядро примитивов

`primitives_external.h`:
```c
struct kernel_primitives {
    kreadbuf, kwritebuf, physreadbuf, physwritebuf,
    krwMinSafeReadSize,
    kcall, kexec, kalloc_global, kalloc_local, kfree_global,
    kmap, physaccess_mapped, vtophys, phystokv
};
```

**physrw_pte** (`physrw_pte.c`) — флагманский слой:
- Выделяется «magic page table» на `MAGIC_PT_ADDRESS` через
  `pmap_expand_range(pmap, MAGIC_PT_ADDRESS, L2_BLOCK_SIZE)`;
- Роутинг: physread/write через *PTE-окно*: эксплойт даёт kread/kwrite,
  physrw_pte ставит PTE (PERM_KRW_URW, NON_GLOBAL, OUTER_SHAREABLE, LEVEL3),
  мапит целевую физическую страницу в userland-окно и читает/пишет через
  memcpy + `dmb sy`;
- **flush_tlb**: подмена ASID/sw_asid на 0xFFFF, `usleep(0)` (context switch),
  восстановление — чтобы не ловить спинлок-паники;
- `physrw_pte_handoff(pid, &asidPtr)` — boomerang-хэндофф: jbd/launchdhook
  получает *своё* PTE-окно в отдельном процессе (каждый процесс живёт со своим
  magic PT, это главный трюк по сравнению с физическим доступом через
  один большой мап).

**physrw** (fallback) — через полный `phystokv` мап, когда PTE-трюк
недоступен (старые A9/A10 и т.п.).

**translation.c** — `kvtophys/vtophys_lvl` через TTE-парсинг по уровням.

**kcall**:
- arm64e: **kcall_Fugu14** (PAC-байпас через kexec-оркестрацию);
- arm64: **kcall_arm64** — требует *реальный* arm64-путь исполнения в ядре.

**trustcache** (`trustcache.c/fs`) — SQLite-подобные static trustcache:
- `trustcache_file_v1` на диске, `upload_with_uuid(uuid)` — отдельные кэши
  (DYLD_TRUSTCACHE_UUID и т.п.); вручную собирает cdhash из мачо через
  ChOma (`file_collect_untrusted_cdhashes`).

**info.c / offsets** — динамические оффсеты из XPF + **hardcoded**
(jitbox-подстройка на A15+/M2+, с добавками 0x10/0x18/0x20 по darwinVersion
22/24.4).

---

## 5. jbserver (launchdhook) — домены

`jbserver_domains.h`:

- **JBS_DOMAIN_SYSTEMWIDE (1)**: get_jbroot, get_boot_uuid, **trust_file**,
  process_checkin, fork_fix, cs_revalidate, jbsettings_get, persona_fix.
- **JBS_DOMAIN_PLATFORM (2)**: set_process_debugged, stage_jailbreak_update,
  jbsettings_set, set_systemwide_domain_enabled.
- **JBS_DOMAIN_WATCHDOG (3)**: intercept_userspace_panic (roothide-специфично
  перенесён под userspace reboot handling).
- **JBS_DOMAIN_ROOT (4)**: get_physrw, sign_thread, get_sysinfo,
  steal_ucred, set_mac_label, trustcache_*.
- **JBS_DOMAIN_DOPAMINE (5)**: is_jailbroken, get_root, drop_root.
- **JBS_DOMAIN_ROOTHIDE (6)**: jailbroken_check, palehide_present,
  **blacklist_check**, **jailbreakd_lookup**, jailbreakd_checkin,
  get_alternative_port, trust_library/executable_recurse,
  dyld_patch_enabled get/set.

**trust_file** (`jbdomain_systemwide.c:103`): берет fd, собирает
`file_collect_untrusted_cdhashes` → `jb_trustcache_add_cdhashes` — это
динамическое добавление cdhash в kextcache-память через krw. Работает для
любого процесса (не только root) — за счёт audit_token.

**process_checkin** (`jbdomain_systemwide.c:205`): каждый процесс при старте
(через systemhook/dyldhook) делает XPC-вызов → получает jbroot, boot uuid,
sandbox extensions, fully_debugged (если `markAppsAsDebugged`), force_cs_adhoc
(для SPTM), затем `cs_allow_invalid(proc, fullyDebugged)` — **клиентский
AMFI-bypass**.

---

## 6. roothide-специфика

### 6.1 Случайный jbroot
`DOEnvironmentManager.m:ensureJailbreakRootExists` — путь
`/private/preboot/<bootManifestHash>/dopamine-<6 random alnum>/procursus`.
`gSystemInfo.jailbreakInfo.rootPath` — единственный источник.
`jbroot.c` → `jbinfo(rootPath)`. Всё остальное строится от JBROOT_PATH().
**Миграция** с jb-<UUID> (Dopamine 1.x) и dopamine-<15> (2.x).

### 6.2 Blacklist процессов
`libroothider/src/blacklist.cpp` — множество pid'ов, для которых хуки не
применяются (это «hidden» процессы — банковские приложения и прочие,
подозрительные на детект). Управление через jbserver (ROOTHIDE domain).
Хуки спрашивают `isBlacklistedProcess(pid)` перед инжектом.

### 6.3 ElleKit вместо Substrate
Флаг `.this_is_ellekit_not_substrate` — используется ElleKit (fork
CFLite-based hooking). `BaseBin/_external/frameworks` содержит локально
собранный ElleKit. Он ловит macho-загрузку и патчит через interpose-хуки.

### 6.4 dyldhook / fakelib
`dyldhook/src/main.c` — «fake lib» в /usr/lib: подмена системных фреймворков
(с symlinks на fakelib-mount). `lv_bypass.c`, `spinlock_fix.c` — обёртки.
`MachOMerger` генерирует мачо-файл, добавляющий twiddle-хендлеры в общий
dyld_shared_cache.

### 6.5 spinlock panic fix
`dyldhook/src/spinlock_fix.c` — iOS 15 arm64e только: перечисляет
dsc-мапинги вручную (обход `__dsc_file_enumerate_mappings`), чтобы не
попасть в спинлок в dyld при старте процессов (это была известная паника
на 15.0–15.4.1 arm64e).

---

## 7. launchdhook → boomerang → jailbreakd

**Поток примитивов**: Dopamine-приложение держит krw → запускает jbctl
(«launchd_stash_port»), он через `task_for_pid(1)` достаёт task-порт
launchd, через `mach_ports_lookup/register` кладёт в initPorts[2] порт
boomerang-сервера. launchd получает этот порт в initPorts → launchdhook
инжектится через opainject (task-порт launchd) → в launchdhook поднимается
jbserver (глобальный) → каждый процесс при старте checkin'ится → получает
jbroot/AMFI-bypass → если просят, boomerang-механика (`boomerang_get_physrw`)
выдаёт physrw-«окно» клиенту через PTE-handoff (как у jbd в обычном Dopamine).

**jailbreakd** (`jailbreakd/src/main.m`) — в roothide это *тонкий* демон,
не хранит примитивы. Получает boomerang-порт из `mach_ports_lookup()[2]`,
делает `jbclient_initialize_primitives()` (после чего он становится ещё
одним клиентом с physrw-PTE-окном) и живёт как supervisory daemon
(jetsam limit 50 MB). Все операции amfid-подобного сервиса уже покрыты
jbserver-доменами launchdhook.

---

## 8. Ветки-ответвления: forkfix, opainject, hookd, idownloadd

- **forkfix** — обёртка вокруг fork() для процессов с CS_PLATFORMIZED
  (чтобы память/`__thid` не деградировали);
- **opainject** — инжектор dylib в произвольный процесс через task-порт;
- **hookd** — форк jailbreakd для hooking-демонов (замена substrate-daemon);
- **idownloadd** — фон-загрузчик bootstrap-архивов.

---

## 9. Почему это работает и где ломается

### 9.1 Почему работает
- **Чистый ABI эксплойтов** → подмена kfd ↔ DarkSword ↔ ClearSword не
  ломает ничего выше.
- **physrw-через-PTE** — работает независимо от того, как получен kread/kwrite;
  16+ (jitbox/SPTM) требует либо Titan, либо dmaFail, иначе physwrite
  ограничен; roothide легко ставит Titan поверх kfd на 16.1–17.3.1.
- **jbserver в launchd** — это позволяет быть рут-сервером в момент,
  когда ничего другого ещё не поднято (раньше, чем amfid).
- **trust_file поверх audit_token** — bypass AMFI для произвольного процесса
  без рут-чека (за счёт audit_token_to_pid + proc_pidfdinfo).

### 9.2 Где ломается (issues с GitHub)
- **#169 Battery drain** — постоянный physrw polling + blacklist-lookup
  на каждый sysctl вызывает лишние wakeups;
- **#166 Автологаут** — периодические userspace reboots из-за watchdog
  interplay (JBS_DOMAIN_WATCHDOG + jetsam_hook);
- **#163 Tailscale/VPN** — network-extensions не получают sandbox-extensions
  от process_checkin;
- **#164/152/144 детекты** — детект по `csops(CS_OPS_STATUS)` — у
  roothide-приложений CS_INSTALLER/CS_DEBUGGED остаются в csflags и это
  видно; по pathhook остаются следы; «MB Bank/Sacombank» — банковские
  anti-tamper через sysctl/proc-шардинг;
- **#137/146 iOS 17–18.x** — arm64 ветка (не arm64e) всё ещё без
  kfd-фреймворка для 17+; для arm64e 17+ нужен Titan или ClearSword/DarkSword
  с beta-билдами;
- **#170 spinlock** — переполнение буфера dsc-мапингов на iOS 15 arm64e,
  fix в dyldhook/spinlock_fix.c — это свежая правка 3.0.13-30.

### 9.3 Для нашего проекта (External)
Что напрямую портируется в наш iOS-KernelExternal:
1. **physrw_pte** — работает у нас уже, алгоритм идентичен (мы сравнили
   строка-в-строку: magic PT, PERM_KRW_URW, flush_tlb через ASID swap —
   всё как в Dopamine 2.x).
2. **DOExploit-таблица (Info.plist DPSupportedRanges)** — это готовый
   роутинг эксплойтов: мы берём как есть для 15.0–17.3.1:
   - 15.0–16.6.1: kfd (physpuppet → landa → smith по приоритету);
   - 16.1–17.3.1 arm64e A14–A17: Titan (PPL) поверх kfd (нужно и то и то);
   - 15.x A12/A13: momentarius (PPL);
   - 15.0–16.5.1: dmaFail (PPL) если A15/A16 не 20F75;
   - beta-билды 17.x/18.x: ClearSword/DarkSword.
3. **trust_file / cs_allow_invalid** — не нужно: у нас один процесс и мы
   делаем extmod-counter обнуление напрямую.
4. **task_for_pid** — в roothide через `jbctl launchd_stash_port` +
   initPorts[2], у нас проще: task_for_pid напрямую + обнуление extmod.
5. **Архитектура jbserver-в-launchd** нам НЕ нужна — у нас нет bootstrap,
   нет launchd-hook: всё живёт внутри приложения.

---

## 10. Критика по коду

- `jbserver_domains.h` JBS_DOMAIN_ROOTHIDE (6) — отсутствует в
  `gGlobalServer[]` порядковый индекс, реализуется через массив
  `gGlobalServer[DOMAIN_INDEX]` — порядок критичен, ломается при вставке
  нового домена в середину.
- `physrw_pte.c flush_tlb` — iOS 27 HACK через два `usleep(80)` — костыль,
  будет медленным (но iOS 27 нам не интересен).
- `systemwide_trust_file` — open() по пути из proc_pidfdinfo — TOCTOU
  между proc_pidfdinfo и open (можно подменить файл между вызовами).
- `blacklist.cpp` — pidversion-кэширование без учёта zombie-pids, возможны
  ложные совпадения по pid после быстрой смерти процесса.
- `libjailbreak/src/info.c jbinfo_initialize_hardcoded_offsets` — длинный
  if-else по darwinVersion, растёт линейно с каждой версией XNU.

---

## 11. Что взять для нашего External (детально)

Наш контекст: приложение-экстернал (без джейлбрейка), kernel access через
kfd, задача — task_for_pid на чужие процессы + обнуление extmod-счётчика.

### Прямой перенос (без изменений)
- `Exploits/kfd/kfd.m` (файл целиком — 320 строк, у нас он уже есть и
  работает; перепроверить `pmap_to_hint` для 16.5.1: 0x58 — совпадает).
- `Exploits/Titan/exploit/*` — ppl bypass для 16.1–17.3.1 arm64e
  ( Alfie / roothide's build ) — у нас его ещё нет, переносим.
- `physrw_pte` — уже есть, выверен.
- Таблица `DPSupportedRanges` — как источник правды для выбора эксплойта
  по iOS-версии.

### Требует адаптации
- `DOExploitManager` — вместо XPC-бандлов берём плоские .dylib в IPA-бандле
  и dlopen напрямую; таблица Range/Priority из Info.plist → наша JSON.
- `kcall_Fugu14` / `kcall_arm64` — нужен только если делаем kcall (мы не
  делаем — только krw).
- `jbinfo_initialize_hardcoded_offsets` — jitbox-подстройки для task-оффсетов
  (важно для proc_find/task_for_pid на A15+).

### Не переносим
- jbserver, launchdhook, systemhook, bootstrap, forkfix, ElleKit —
  это весь jailbreak-слой, у нас его нет и не нужен.
- blacklist — у нас нет «скрытия», процесс один и работает в фоне.
- pid-reclaim-защита — у нас другой подход к task-портам (не через
  jbserver checkin, а напрямую через extmod-counter обнуление).

---

## 12. Источники
- Код: https://github.com/roothide/Dopamine-roothide/tree/9617d75f476423fdfd33477299c8a1349eb6f375
- Issues: #163, #164, #166, #169, #170, #152, #137, #146 — GitHub
- Контекст журнала: opa334/Dopamine 2.x (база) + felix-pb/kfd
- Разборы: theapplewiki (Dopamine), siguza blog (PAC/physrw), projectzero
  (CoreTrust/PPL), newosxbook (XNU internals)
