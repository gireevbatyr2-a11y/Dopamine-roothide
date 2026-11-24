# Зависимости и среда сборки

Ниже — только категории, подтверждённые текущим `.github/workflows/main.yml` и деревом репозитория; это не полный SBOM.

- Git submodules: workflow выполняет рекурсивный checkout; версии задаются gitlink SHA.
- Xcode и Apple SDK: workflow использует `macos-latest` и `latest-stable` Xcode.
- Сторонние средства сборки: workflow устанавливает инструменты из Procursus/Homebrew, Theos и вспомогательные пакеты.
- Swift Package Manager: workflow формирует `Package.resolved` для зависимости проекта.
- Сторонние GitHub Actions и установки из `main`/`latest` остаются плавающими ссылками; поэтому одинаковый commit не гарантирует идентичную среду повторного запуска.

Полные версии каждого инструмента, хеши всех зависимостей и SBOM здесь не подтверждены. Для точного аудита нужны полный workflow log и рекурсивное сравнение каждого gitlink с фактически использованным checkout.
