# Event Album

> This project was generated with the help of OpenAI Codex.

Event Album is a Flutter application for capturing, organising, and analysing archery practice sessions on iOS and Android devices. The app leans on Material 3 design, smooth transitions, and an intuitive bottom navigation layout to keep memories easy to create and revisit.

## Features

- **Bottom Navigation** with Home, Activities, and Settings tabs powered by Material 3 `NavigationBar`.
- **Home** highlights the most recent activities, quick capture shortcuts, and polished hero animations to detail pages.
- **Activities** shows every album in a responsive grid, supporting rename, delete, and photo capture directly within each entry.
- **Activity Detail** renders an interactive archery target with tap-to-score arrows, per-round totals, optional photos, and long-press removal.
- **Settings** exposes theme selection (light/dark/system), default naming templates, configurable storage path, and an About section.

## Architecture

- **State Management:** `flutter_bloc` with dedicated blocs/cubits per feature.
- **Data Layer:** Repositories backed by local storage (`path_provider`) plus camera/gallery input via `image_picker`.
- **Settings Persistence:** `shared_preferences` retains user preferences across launches.
- **Folder Structure:**
  ```
  lib/
    blocs/              # Activity, activity detail, settings, navigation
    data/
      models/           # Core entities (Activity, ArcheryRound, ArrowHit, AppSettings)
      repositories/     # Activity & settings repositories
      services/         # Storage helpers
    theme/              # Light & dark Material 3 themes
    ui/
      activities/
      common/
      home/
      root/
      settings/
    main.dart
  ```

## Getting Started

1. Install dependencies:
   ```bash
   flutter pub get
   ```
2. Run on a connected device or emulator:
   ```bash
   flutter run
   ```
3. Execute static analysis and tests:
   ```bash
   flutter analyze
   flutter test
   ```

Make sure camera and photo library permissions are declared in `AndroidManifest.xml` and `Info.plist` before distributing the app.
