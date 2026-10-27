# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Flutter application that calculates prime factorization of numbers. The app supports bilingual functionality (Japanese/English) and is designed as a simple, focused calculator tool.

**Key Details:**
- App Name: Prime Factorization Calculator (素因数分解計算機)
- Version: 4.0.0+17
- Flutter SDK: 3.47.8 (stable, Dart 3.13) 以上。AGP 9 / Gradle 9 を使うため、古い Flutter ではビルドできない
- Package ID: `project.My_prime_nember` (Android)

## Common Commands

### Development
```bash
# Run the app in development mode
flutter run

# Run on specific platform
flutter run -d android
flutter run -d ios

# Hot reload (press 'r' in terminal during flutter run)
# Hot restart (press 'R' in terminal during flutter run)
```

### Building
```bash
# Build APK for Android
flutter build apk

# Build App Bundle for Android (preferred for Play Store)
flutter build appbundle

# Build for iOS
flutter build ios

# Build for web
flutter build web
```

### Testing
```bash
# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage
```

### Maintenance
```bash
# Check for dependency updates
flutter pub outdated

# Update dependencies
flutter pub upgrade

# Clean build artifacts
flutter clean

# Get dependencies
flutter pub get

# Generate localization files
flutter gen-l10n

# Enable pre-commit hooks (run once after cloning)
git config core.hooksPath .githooks
```

## Git Hooks

Pre-commit hooks are stored in `.githooks/` and run `dart format` (check only), `flutter analyze` and `flutter test` before each commit. If the format check fails, run `dart format .`. Enable them once per clone:

```bash
git config core.hooksPath .githooks
```

To skip in an emergency: `git commit --no-verify`

To hide the bulk formatting commit from `git blame` locally (GitHub already honors `.git-blame-ignore-revs`):

```bash
git config blame.ignoreRevsFile .git-blame-ignore-revs
```

## Architecture

### Core Structure
- **`lib/main.dart`**: Main app entry point with MaterialApp setup, theme configuration, and localization delegates
- **`lib/judge.dart`**: Core business logic (Miller-Rabin primality test, Pollard-Brent factorization on `BigInt`; entry point `pri_fact_isolate()` runs in an isolate)
- **`lib/history_*.dart`**: Calculation history (`HistoryEntry`, `HistoryRepository` persisting via `shared_preferences`, `HistoryPage`)
- **`lib/l10n/`**: Internationalization files for Japanese and English support

### Key Components
1. **MyApp**: Root widget with theme and localization configuration
2. **MyLayout**: Main layout with drawer navigation
3. **MyWidget**: Primary calculator interface with input field and result display

### Algorithm Implementation
- Primality: Miller-Rabin with fixed witnesses (deterministic below 3.3×10^24, error < 4^-20 for 30 digits)
- Factorization: Pollard-Brent rho on `BigInt`, recursing on found factors
- Supports integers up to 30 digits
- Returns formatted results with Japanese/English localization

### State Management
- Uses simple StatefulWidget approach with `setState()`
- No complex state management library (Provider, Bloc, etc.)
- Local state management for calculator operations

## Internationalization

The app supports Japanese and English:
- **Configuration**: `l10n.yaml` with generated classes
- **Files**: `app_ja.arb` (Japanese), `app_en.arb` (English)
- **Usage**: `AppLocalizations.of(context)!.localizedString`
- **Regeneration**: Run `flutter gen-l10n` after updating ARB files

## Platform Configuration

### Android
- **Min SDK**: `flutter.minSdkVersion` (Flutter の既定値に従う)
- **Target SDK**: 36 (Android 16)
- **Build tools**: AGP 9.1.0 / Gradle 9.3.1 (`android.newDsl=false` で opt-out)
- **Build file**: `android/app/build.gradle`
- **Release signing**: Configured with keystore properties

### iOS
- **Platform**: iOS 9.0+
- **Configuration**: `ios/Runner/Info.plist`
- **Display name**: Supports Japanese characters

## Dependencies

### Core Dependencies
- `styled_text: ^8.1.0` - Rich text formatting for results
- `flutter_localizations` (SDK) - Internationalization support
- `intl: ^0.20.2` - Date/number formatting
- `shared_preferences: ^2.3.0` - Persisting calculation history
- `url_launcher: ^6.0.18` - External links in drawer

### Dev Dependencies
- `flutter_launcher_icons: any` - Custom app icon generation

## Development Notes

### Code Style
- Mixed Japanese/English comments in codebase
- Material Design pattern throughout
- Teal color scheme for consistent branding

### Testing
- Basic widget tests exist in `test/widget_test.dart`
- Test coverage is minimal and should be expanded
- Focus testing on prime factorization logic in `judge.dart`

### Common Issues
- Some hardcoded strings remain (not fully internationalized)
- Input validation could be more robust

### Git Workflow
- **Main branch**: `master`
- Feature branch workflow in use; PRs target `master`
- CI (`.github/workflows/ci.yml`) runs `dart format` (check only), `flutter analyze`, `flutter test` and a debug APK build on PRs and pushes to `master`