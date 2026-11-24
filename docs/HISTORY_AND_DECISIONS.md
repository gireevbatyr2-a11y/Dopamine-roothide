# История состояния реконструкции

Факты ниже взяты из сообщений коммитов и метаданных GitHub; объяснения авторов сверх этих сообщений не предполагаются.

| Commit | Сообщение | Подтверждённый смысл |
|---|---|---|
| `5b8ce9a` | Reconstruct roothide/Dopamine-roothide @ 9617d75…: full tree + pinned submodules | Создано основное дерево реконструкции и добавлены ссылки на зависимости. |
| `7a81b64` | Convert dependency paths to submodule gitlinks at upstream-recorded SHAs | Часть внешних путей оформлена как gitlink-ссылки на зависимости. |
| `8058335` | CI: checkout own repository (reconstruction verification) | Workflow переключён на checkout репозитория реконструкции. |
| `a69310a` | pin build environment to upstream-resolved state (zstd 49bf1d1, credits builder, commit hash, artifact version) | Добавлены параметры окружения для именования и конфигурации сборки. |

Полные SHA и временные метки доступны в истории ветки `main`. В этой таблице намеренно не делаются выводы о мотивах авторов или о деталях exploit-реализации.
