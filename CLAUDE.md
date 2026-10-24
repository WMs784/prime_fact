# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Flutter application that calculates prime factorization of numbers. The app supports bilingual functionality (Japanese/English) and is designed as a simple, focused calculator tool.

**Key Details:**
- App Name: Prime Factorization Calculator (素因数分解計算機)
- Version: 2.0.1+3
- Flutter SDK: ">=2.12.0 <3.0.0"
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
```

## Architecture

### Core Structure
- **`lib/main.dart`**: Main app entry point with MaterialApp setup, theme configuration, and localization delegates
- **`lib/judge.dart`**: Core business logic containing prime factorization algorithms (`prime()` and `pri_fact()` functions)
- **`lib/l10n/`**: Internationalization files for Japanese and English support

### Key Components
1. **MyApp**: Root widget with theme and localization configuration
2. **MyLayout**: Main layout with drawer navigation
3. **MyWidget**: Primary calculator interface with input field and result display

### Algorithm Implementation
- Prime detection uses trial division up to √n
- Factorization algorithm iteratively divides by smallest prime factors
- Supports integers up to 18 digits
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
- **Min SDK**: 21 (Android 5.0)
- **Target SDK**: 34 (Android 14)
- **Build file**: `android/app/build.gradle`
- **Release signing**: Configured with keystore properties

### iOS
- **Platform**: iOS 9.0+
- **Configuration**: `ios/Runner/Info.plist`
- **Display name**: Supports Japanese characters

## Dependencies

### Core Dependencies
- `styled_text: ^8.1.0` - Rich text formatting for results
- `flutter_localization: ^0.2.0` - Internationalization support
- `intl: ^0.18.0` - Date/number formatting
- `url_launcher: ^6.0.18` - External links in drawer

### Dev Dependencies
- `flutter_launcher_icons: any` - Custom app icon generation

## Development Notes

### Code Style
- Mixed Japanese/English comments in codebase
- Material Design pattern throughout
- Teal color scheme for consistent branding

### Testing
- Basic widget test setup exists but needs updating
- Test coverage is minimal and should be expanded
- Focus testing on prime factorization logic in `judge.dart`

### Common Issues
- Flutter SDK version is outdated - consider upgrading
- Some hardcoded strings remain (not fully internationalized)
- Input validation could be more robust

### Git Workflow
- **Current branch**: `feature/fix_drawer`
- **Main branch**: `master`
- Feature branch workflow in use
- Recent work includes drawer fixes and multi-language improvements