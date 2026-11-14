# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Flutter application that calculates prime factorization of numbers. The app supports bilingual functionality (Japanese/English) and is designed as a simple, focused calculator tool.

**Key Details:**
- App Name: Prime Factorization Calculator (素因数分解計算機)
- Version: 4.4.0+21
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
- **`lib/judge.dart`**: Core business logic (Miller-Rabin primality test, Pollard-Brent factorization on `BigInt`; アルゴリズム本体は `yield` で区切れる `sync*`。`pri_fact_isolate(FactorRequest)` は最後まで同期で回す版（テスト・isolate 用）、`factorizeAsync(request, CancelToken)` は約 50ms ごとにイベントループへ制御を返す版で、Web ではこれをメインスレッドで使う（Web には Isolate がなく `compute` だと画面が固まるため。速度は同期版と同程度）。Web 以外は `lib/judge_isolate.dart` の `factorizeInIsolate` で別 Isolate に出す（メインスレッドで区切ると 1 フレーム 16.7ms を超えて描画が落ちるため）。どちらも `CancelToken.cancel()` で `CancelledException` を投げて止まる。the request is a record `(n, isNotPrime, isPrime, special)`)
- **`lib/trivia.dart`**: Replaces the primality header for special numbers (perfect / Mersenne / Fermat / palindromic / Sophie Germain / twin primes, 1729, 57 Grothendieck), e.g. "6は素数、ではなく完全数です！". The result is passed to the calculator (`factorizeAsync` / `factorizeInIsolate`) as `FactorRequest.special`; `HistoryPage` re-derives it via `headerFor`. To extend: add a `Trivia` value, its `isXxx` ARB strings (suffix after the number), a `triviaHeader` case and a test
- **`lib/history_*.dart`**: Calculation history (`HistoryEntry`, `HistoryRepository` persisting via `shared_preferences`, `HistoryPage`)
- **`lib/daily_*.dart`**: 「今日の素因数分解」。`DailyPuzzle` が JST の日付だけから決定的に `n = p×q`（`p` は 7〜53 の最小の素因数、`q` は `p`〜293）を生成する（`p` の範囲は易/中/難 = 50/35/15% の 3 段階。難度は画面にもシェア文にも出さない）。`DailyProgress`/`DailyRepository` が開始時刻・ミス回数・クリア時刻を `shared_preferences` に保存し（離脱中も時間は進む）、`DailyBanner`（ホーム）→`DailyPage`（出題・結果・シェア）と遷移する。生成手順を変えると同じ日の問題が変わるので、変更時は日付で分岐し `test/daily_puzzle_test.dart` の固定値も更新する
- **`lib/daily_stats.dart` / `lib/daily_records_page.dart`**: 「今日の素因数分解」の累計成績と記録画面。`DailyRepository.loadAll()` が `daily_<yyyyMMdd>` を全部読み（破損した日は除く）、`DailyStats.compute` が連続日数（今日が未クリアなら昨日までの連続を続行中として数える）・最長連続・クリア日数・ノーミス数・ベストタイム（時計変更で 0 になった記録は除く）を求める。バナー（記録ボタンと連続日数）、挑戦画面（AppBar の記録ボタン、クリア後の連続日数）から使う
- **`lib/settings_repository.dart`**: 表示設定（ドロワーのスイッチで「今日の素因数分解」バナーの表示/非表示を切り替え、`shared_preferences` に保存。既定は表示）
- **`lib/number_style.dart`**: 数の表示形式（そのまま/カンマ区切り/単位つき）。結果・履歴・コピー・共有の表示時に整形する（保存値は素の数字）。単位つき（万・億…）は日本語のみで、英語では選択肢を出さず `effectiveStyle` で plain 扱いにする。指数（`^` の直後）は整形しない。設定は `SettingsRepository` に保存。コピー・共有は画面に出ている形式のまま出す（入力欄は `digitsOnly` なのでカンマ付きは貼っても数字に戻るが、単位つきの「万」「億」は消えて別の数になる）。「今日の素因数分解」の画面・シェア文は対象外（n が小さく効果が薄いため）
- **`lib/links.dart`**: 外部リンク（プライバシーポリシー、Play ストア、Web アプリなど）の定数。ドロワーとシェア文で共有する
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
- **Platform**: iOS 13.0+ (share_plus の要件)
- **Configuration**: `ios/Runner/Info.plist`
- **Display name**: Supports Japanese characters

## Dependencies

### Core Dependencies
- `styled_text: ^10.0.0` - Rich text formatting for results
- `flutter_localizations` (SDK) - Internationalization support
- `intl: ^0.20.2` - Date/number formatting
- `shared_preferences: ^2.3.0` - Persisting calculation history
- `url_launcher: ^6.3.0` - External links in drawer
- `share_plus: ^13.3.1` - Sharing the daily challenge result

### Dev Dependencies
- `flutter_launcher_icons: ^0.14.4` - Custom app icon generation

## Development Notes

### Code Style
- Mixed Japanese/English comments in codebase
- Material Design pattern throughout
- Teal color scheme for consistent branding

### Testing
- `test/judge_test.dart`: primality (Carmichael numbers, strong pseudoprimes), factorization (prime powers, trial-division boundary, ~30-digit semiprime), trivial inputs, `FactorRequest` round trip through the real `compute` isolate, `factorizeAsync` / `factorizeInIsolate`（同期版と同じ結果・制御を返すこと・中止）
- `test/trivia_test.dart`: each special-number category and near-miss numbers (e.g. 121, 120, 15)
- `test/history_test.dart`: `HistoryEntry` JSON round trip and legacy-format migration, `HistoryRepository` load/save/corrupted data
- `test/daily_puzzle_test.dart`: determinism, JST date rollover, p/q ranges, tier ratios, fixed-date regression values
- `test/daily_progress_test.dart`, `test/daily_challenge_test.dart`: progress/repository, banner → challenge → result flow, share text
- `test/daily_stats_test.dart`: 連続日数（途切れ・月/年/うるう年またぎ・未クリア日）、ノーミス数、ベストタイム、`loadAll`、バナーの連続表示と記録画面
- `test/daily_robustness_test.dart`: load/save failures, share fallback rules, stale reloads, double submit, Enter key, share errors, banner at JST midnight, short screen with keyboard
- `test/number_style_test.dart`: 各形式の整形、指数の除外、英語での単位つき無効化、設定の保存
- `test/number_format_ui_test.dart`: ドロワーからの形式選択、結果・共有・履歴への反映、英語で単位つきが出ないこと
- `test/settings_test.dart`: daily banner toggle in the drawer and its persistence
- `test/widget_test.dart`: calculator UI, input validation errors, localized results, history save races (injected `HistoryRepository`), failed and cancelled calculation (injected `Calculator`), drawer links (injected `UrlOpener`), wrapped result (line breaks only before `x`), copy/share buttons, fixed input position
- Add tests alongside any change to `judge.dart` or the history format

### Known Limitations
- Factoring a ~30-digit number whose prime factors are both ~15 digits can take a long time (14 桁×14 桁で JIT 約 7 秒)。計算中は「中止」ボタンで止められるが、速くするには別のアルゴリズム（ECM / SIQS）が必要
- Web は dart2js の BigInt が VM よりずっと遅く（24 桁で約 10 倍）、さらにタブが裏に回るとタイマーが間引かれて区切りのたびに待たされ、計算が大きく遅くなる。根本対応は Web Worker 化
- History grows without a size limit
- Daily challenge results (`daily_<yyyyMMdd>` in `shared_preferences`) are never deleted: one small key per day played
- Daily challenge times use the device wall clock (no server): changing the clock can distort or zero the recorded time, and a negative elapsed time is shown as 0:00.0
- Daily records dated after today (left by moving the device clock forward) are ignored by the stats and the records page until that date actually arrives
- A corrupted daily record is treated as "not started" and overwritten, so the cleared state is lost (it cannot be recovered anyway)
