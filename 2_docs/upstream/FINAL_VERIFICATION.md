# FINAL VERIFICATION — независимая реконструкция roothide/Dopamine-roothide@9617d75

## Вердикт: PARTIAL — BUILD SUCCESS, IDENTITY NOT (FULLY) VERIFIED

- Репозиторий реконструкции: `gireevbatyr2-a11y/Dopamine-roothide` (переименован из
  `Dopamine-roothide-reconstruction` для паритета checkout-пути
  `/Users/runner/work/Dopamine-roothide/Dopamine-roothide/`).
- Run 1: 45343537230 (commit 8058335) — SUCCESS с первой попытки.
- Run 2: 45345681667 (commit a69310a, env-пины) — SUCCESS.
- Артефакт run 2: `roothide-Dopamine-(3.0.13-30-9617d75)-2026.11.06-UTC-02.17.10.tipa`
  (имя совпадает с эталоном).

## Паритет исходного дерева
771/771 файлов вверх по дереву совпадают с upstream по git-blob SHA (проверено API).
Все файлы `Dopamine.xcodeproj` — побайтово идентичны upstream. Submodule-пины (4) идентичны.

## Применённые env-пины (run 2, только workflow — tree-файлы не тронуты)
1. zstd: SPM Package.resolved pinned к `49bf1d14c8ffc6a25c32667ce878c4148f43ac4f`
   (dev HEAD, разрешённый CI upstream 2026-11-06, найдено в оригинальном логе).
2. Credits.plist BUILDER: name=roothider, link=roothide/Dopamine-roothide (вместо github.actor/repository).
3. COMMIT_HASH: `9617d75f476423fdfd33477299c8a1349eb6f375` передан в gmake.
4. VERSION артефакта: hardcoded `9617d75-2026.11.06-UTC-02.17.10`.

## Результат сравнения run 2 vs эталон (SHA-256 каждого файла бандла)
Побайтово идентичны (выборка критичных): `libjailbreak.dylib` (все 3 копии),
`libchoma.dylib`, `libxpf.dylib`, `libroothider.dylib`, `Dopamine.roothide`,
`Credits.plist`, все 24 Localizable.strings, все LICENSE_*, все bootstrap_*.tar.zst,
`jailbreakd`, `idownloadd`, все `dyldhook_merge.*.dylib`, `systemhook`, `forkfix`,
`opainject`, `boomerang`, `jbctl`, `hookd`, `bootstrapper`, все resource-`.deb`
(sileo/zebra/libroot? нет — см. ниже), `launchctl_*.deb`, `libkrw-dopamine.deb`? нет.

### Остаточные различия (все — класс "недетерминированные идентификаторы", кода нет)
| Файл | Байт различий | Причина (проверено) |
|---|---|---|
| Dopamine (бинарник) | 64 | LC_UUID + CDHash-каскад |
| 10 фреймворков (kfd, Titan, DarkSword, ClearSword, weightBufs, multicast_bytecopy, badRecovery, dmaFail, momentarius, palera1n) | 48–80 | LC_UUID + CDHash |
| roothidehooks/rootlesshooks.dylib | 96 | LC_UUID + CDHash |
| MachOMerger | 837 | + Swift WMO module hash 16 байт (недетерминизм swiftc между окружениями) |
| basebin.tc | 496 | случайный UUID при генерации trustcache (невоспроизводимо даже у upstream) |
| Info.plist приложения и всех фреймворков | — | `BuildMachineOSBuild` 25G83 → 25G332: образ runner macos-latest «поплыл» между 06.11 и 24.11; публично запиннить образ нельзя |
| _CodeSignature/CodeResources (прил.+фреймворки) | — | каскад UUID/BuildMachineOSBuild |
| basebin.tar, basebin-link.deb, libkrw-dopamine.deb, libroot.deb | — | mtimes members = настенные часы сборки (tar/ar не нормализованы, SOURCE_DATE_EPOCH у upstream не задан) — у самого upstream пересборка в другой день даёт другие байты |

`exploit_server`/`palera1n` бинарь: 48–80 байт (UUID+CDHash) — контент идентичен.

## Почему FULLY VERIFIED недостижим
1. Runner-образ GitHub (BuildMachineOSBuild) не пиннится.
2. ld64 UUID и codesign CDHash не воспроизводятся через настройки сборки.
3. tar/ar mtimes без SOURCE_DATE_EPOCH у upstream — не нормализованы.
4. trustcache UUID — случайный.
Каждый из этих факторов делает НЕВОЗМОЖНОЙ побайтовую воспроизводимость даже для
самих авторов upstream при повторной сборке в другой день.

## Доказательства
- Run 2: https://github.com/gireevbatyr2-a11y/Dopamine-roothide/actions/runs/45345681667 (SUCCESS)
- Артефакт скачан, распакован, полная SHA-256 таблица бандла сравнена
  с `evidence/original-artifacts/raw/roothide-Dopamine-(3.0.13-30-9617d75)-2026.11.06-UTC-02.17.10.tipa`
- Инструменты: gh api, diff/sha256sum, lief (секции/UUID Mach-O), strings, ar tv.
