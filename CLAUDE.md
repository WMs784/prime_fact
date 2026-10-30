# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Flutter application that calculates prime factorization of numbers. The app supports bilingual functionality (Japanese/English) and is designed as a simple, focused calculator tool.

**Key Details:**
- App Name: Prime Factorization Calculator (素因数分解計算機)
- Version: 4.1.0+18
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
- **`lib/trivia.dart`**: Replaces the primality header for special numbers (perfect / Mersenne / Fermat / palindromic / Sophie Germain / twin primes, 1729, 57 Grothendieck), e.g. "6は素数、ではなく完全数です！". The result is passed to `pri_fact_isolate` as an optional 4th arg; `HistoryPage` re-derives it via `headerFor`. To extend: add a `Trivia` value, its `isXxx` ARB strings (suffix after the number), a `triviaHeader` case and a test
- **`lib/history_*.dart`**: Calculation history (`HistoryEntry`, `HistoryRepository` persisting via `shared_preferences`, `HistoryPage`)
- **`lib/daily_*.dart`**: 「今日の素因数分解」。`DailyPuzzle` が JST の日付だけから決定的に `n = p×q`（`p` は 7〜97 の最小の素因数、`q` は `p`〜997）を生成する（難度ティアは易/中/難 = 40/40/20%）。`DailyProgress`/`DailyRepository` が開始時刻・ミス回数・クリア時刻を `shared_preferences` に保存し（離脱中も時間は進む）、`DailyBanner`（ホーム）→`DailyPage`（出題・結果・シェア）と遷移する。生成手順を変えると同じ日の問題が変わるので、変更時は日付で分岐し `test/daily_puzzle_test.dart` の固定値も更新する
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
- **Platform**: iOS 11.0+
- **Configuration**: `ios/Runner/Info.plist`
- **Display name**: Supports Japanese characters

## Dependencies

### Core Dependencies
- `styled_text: ^10.0.0` - Rich text formatting for results
- `flutter_localizations` (SDK) - Internationalization support
- `intl: ^0.20.2` - Date/number formatting
- `shared_preferences: ^2.3.0` - Persisting calculation history
- `url_launcher: ^6.0.18` - External links in drawer
- `share_plus: ^13.3.1` - Sharing the daily challenge result

### Dev Dependencies
- `flutter_launcher_icons: any` - Custom app icon generation

## Development Notes

### Code Style
- Mixed Japanese/English comments in codebase
- Material Design pattern throughout
- Teal color scheme for consistent branding

### Testing
- `test/judge_test.dart`: primality (Carmichael numbers, strong pseudoprimes), factorization (prime powers, trial-division boundary, ~30-digit semiprime), trivial inputs
- `test/trivia_test.dart`: each special-number category and near-miss numbers (e.g. 121, 120, 15)
- `test/history_test.dart`: `HistoryEntry` JSON round trip and legacy-format migration, `HistoryRepository` load/save/corrupted data
- `test/daily_puzzle_test.dart`: determinism, JST date rollover, p/q ranges, tier ratios, fixed-date regression values
- `test/daily_progress_test.dart`, `test/daily_challenge_test.dart`: progress/repository, banner → challenge → result flow, share text
- `test/widget_test.dart`: calculator UI, input validation errors, localized results
- Add tests alongside any change to `judge.dart` or the history format

### Known Limitations
- Factoring a ~30-digit number whose prime factors are both ~15 digits can take a long time; `compute` cannot be cancelled, so the button stays disabled until it finishes (no practical fix without a different algorithm)
- Until `HistoryRepository.load()` finishes at startup, saving a new entry would overwrite the stored history (only a window of a few milliseconds after launch)
- History grows without a size limit
