# Contributing to FiT

Thanks for helping improve FiT! Bug reports, ideas and pull requests are all welcome.

## Getting started

```bash
git clone https://github.com/Shayan1810/FiT-App.git
cd FiT-App/fit
flutter pub get
flutter test
```

You need Flutter 3.47 or newer. Android builds need JDK 21; iOS builds need macOS with Xcode.

## Project layout

The app lives in `fit/` and follows Clean Architecture. Each feature in `lib/features/<name>/` has:

| Folder | Contains |
|---|---|
| `domain/` | Entities, repository interfaces and use cases. Pure Dart, no Flutter. |
| `data/` | Hive-backed repositories, API clients and mappers. |
| `presentation/` | BLoC / Cubit and widgets. |

Shared code (theme, 3D widget kit, storage, DI) is in `lib/core/`. All formulas live in `lib/features/insights/domain/calculators/` and every one cites its source in a doc comment.

## Guidelines

- **Keep it offline-first.** Nothing in the main flow may require a network connection.
- **Keep the UI thread free.** Heavy computation belongs in a use case that runs in `Isolate.run`.
- **Use the palette.** Use `AppColors` / `AppText` instead of hard-coded colours so light and dark mode both work.
- **Cite the science.** New coaching rules or formulas need a reference in the doc comment.
- **Test it.** Add or update tests in `fit/test/`. Calculators need unit tests; new screens should be covered by `test/ui/app_smoke_test.dart`.

Before opening a pull request:

```bash
cd fit
dart format -l 110 lib test tool
flutter analyze        # must report no issues
flutter test           # must pass
```

## Regenerating screenshots

```bash
cd fit
flutter test tool/generate_screenshots_test.dart   # writes docs/screenshots (light + dark)
```

## Commit messages

Use the imperative mood ("Add sleep regularity chart", not "Added …") and keep the first line under 72 characters.
