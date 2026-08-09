# Repository Guidelines

## Project Structure & Module Organization

This is a Flutter app for archery session albums and score tracking. Main Dart code lives in `lib/`, organized by responsibility:

- `lib/main.dart` starts the app.
- `lib/ui/` contains screens and reusable widgets, including `home/`, `activities/`, `settings/`, `root/`, and `common/`.
- `lib/blocs/` holds feature state management for activities, activity detail, settings, and navigation.
- `lib/data/` contains models, repositories, and storage services.
- `lib/theme/` defines Material 3 app themes.
- `test/` contains Flutter widget tests.
- `assets/icon/` contains launcher and app icon source images.

Platform projects are in `android/`, `ios/`, `web/`, `macos/`, `linux/`, and `windows/`. Keep generated build output in `build/` out of commits.

## Build, Test, and Development Commands

- `flutter pub get` installs dependencies from `pubspec.yaml`.
- `flutter run` launches the app on the selected device or emulator.
- `flutter analyze` runs static analysis using `analysis_options.yaml`.
- `flutter test` runs all tests under `test/`.
- `flutter build appbundle --release` builds the Android release bundle.

For launcher icon changes, update `assets/icon/app_icon.png` and run the configured Flutter launcher icon tooling before committing generated platform icons.

## Coding Style & Naming Conventions

Follow `package:flutter_lints/flutter.yaml` through `analysis_options.yaml`. Use Dart defaults: two-space indentation, `lowerCamelCase` for variables and methods, `UpperCamelCase` for classes/enums, and `snake_case.dart` for file names. Keep widgets small and colocate feature-specific UI under the relevant `lib/ui/<feature>/` folder. Prefer repository and service APIs for persistence instead of accessing platform storage directly from UI code.

## Testing Guidelines

Use `flutter_test` for widget and unit coverage. Name test files with the `_test.dart` suffix and place them under `test/`. When testing UI that depends on blocs or repositories, provide focused fakes or seeded blocs as in `test/widget_test.dart`. Run `flutter test` and `flutter analyze` before opening a pull request.

## Commit & Pull Request Guidelines

Recent history uses short conventional-style subjects such as `feat: add x ring`, `fix: show summary when open activity`, and release commits like `release v1.0.2`. Keep commits imperative and scoped to one change.

Pull requests should include a concise description, test results, linked issues when applicable, and screenshots or screen recordings for visible UI changes. Call out platform-specific changes, permissions, release signing updates, or storage/data migration risks.

## Security & Configuration Tips

Do not commit signing secrets. Use `android/key.properties.example` as the template, keep real `android/key.properties` local, and confirm camera/photo permissions in Android and iOS manifests before release builds.
