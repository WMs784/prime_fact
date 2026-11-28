# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Flutter application that calculates prime factorization of numbers. The app supports bilingual functionality (Japanese/English) and is designed as a simple, focused calculator tool.

**Key Details:**
- App Name: Prime Factorization Calculator (素因数分解計算機)
- Version: 4.5.0+22
- Flutter SDK: 3.50.0 (stable, Dart 3.14) 以上。AGP 9 / Gradle 9 を使うため、古い Flutter ではビルドできない
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

## Code Quality Services

- **Lint**: `very_good_analysis`（`analysis_options.yaml`）。`flutter analyze` が CI とプリコミットで警告ゼロを要求する
- **Codecov**: CI の `flutter test --coverage` の結果を `codecov/codecov-action` で送る。リポジトリの Secrets に `CODECOV_TOKEN` が必要。設定は `codecov.yml`
- **Complexity**: CI の `lizard` が `lib/` の関数ごとの循環的複雑度（CCN）を測り、15 を超えると落とす。手元では `pip install lizard` のあと `lizard lib -l dart -x "lib/l10n/app_localizations*" -C 15 -w`。現状の最大は 14（`triviaFor`）。IBM などが推奨する 10 は目標で、10 超の関数が 5 つある

- **依存図**: master への push のたびに `.github/workflows/pages.yml` が `tool/deps/build.py`（`lakos` + graphviz）を回し、`lib/` のファイル間の import 依存を `/<repo>/deps/` に公開する（層ごとの図、`lib` のみの図、指標の比較）。層の割り当ては `tool/deps/build.py` の `LAYERS` / `SHARED`。`lib/` にファイルを足したらここに書き足す（Pages の生成では、未割り当てと層の違反は警告に出すだけでデプロイは止めない。PR の検査は下の通り落とす）。手元では `dart pub global activate lakos` と graphviz を入れて `python3 tool/deps/build.py . /tmp/deps`
- **依存の向きの検査**: PR ごとに CI の `check-dependencies` が `python3 tool/deps/build.py --check .` を回し、層の違反（下の層から上の層、共通部品から他のファイル）と循環依存があれば落とす（graphviz は不要）。層に未割り当てのファイルがあっても落とす（そのファイルが絡む違反を見逃すため。`lib/` にファイルを足す PR で `LAYERS` / `SHARED` に書き足す）。検査ロジックのテストは `tool/deps/test_build.py`（`python3 -m unittest discover -s tool/deps`。同じジョブで回る。Dart の mutation test の対象外）

## Mutation Testing

行カバレッジでは見えない「テストが挙動の変化を検出できるか」を `mutation_test`（dev 依存）で測る。ソースを 1 箇所ずつ書き換え（`==`→`!=`、`+`→`-` など）、対応するテストが落ちれば検出とみなす。

```bash
mutation_test/run.sh              # judge / trivia / number_style / daily_puzzle / date_key / daily_stats / spoken / factorization / result_text を順に実行
mutation_test/run.sh trivia       # 1 ファイルだけ
```

- 対象は UI に依存しない純粋ロジックの 9 ファイルだけ（`mutation_test/<name>.xml`。変異ごとに `flutter test test/<name>_test.dart` を走らせる）。UI を含めると 1 変異ごとの時間が桁違いに増える
- 全体で約 20 分（`judge.dart` が大半）。PR ごとには回さず、`.github/workflows/mutation.yml`（master への push（`lib/` `test/` `mutation_test/` `pubspec.*` の変更時だけ）、手動）で実行する。マージのゲートではなく、マージ後の事後検知。レポートは `mutation-test-report/`（HTML）と CI のアーティファクト
- ルールは組み込みから「数の負数化」を除いた `mutation_test/rules.xml`（Dart の `%` は常に非負なので素数リスト等で等価変異になるため）
- 無限ループになる変異は 30 秒でタイムアウトする（テストが止めたので検出済み）。ループ条件は変異対象から外している
- **合否は検出率ではなく「生き残り数」で決める**（`run.sh` の `max_survivors`）。ツールはタイムアウトも未検出に数えるので検出率では判定できない。生き残り = 未検出 - タイムアウト。基準値は `judge` が 1、他は 0（どれも結果が変わらない等価変異）。基準値を上げるときは、増えた変異が等価変異である理由を PR に書く
- 検出できない等価変異（性能だけの分岐、実時間の境界など）は、各 XML の `<exclude>` に**コードの正規表現**で理由付きで除外している（行番号ではない）。組み込みの `if` ルールは前の空白から `{` までを 1 つの変異にするので、正規表現も `\s` で始めて `{` まで含める。行がずれても追従するが、コードを書き換えて正規表現が合わなくなると等価変異が生き残り、基準値を超えて失敗する
- 数を確認するだけなら `dart run mutation_test -d --rules mutation_test/rules.xml mutation_test/<name>.xml`（dry run。テストは走らない）
- `judge.dart` / `factorization.dart` / `trivia.dart` / `number_style.dart` / `result_text.dart` / `spoken.dart` / `daily_*.dart` を変更したら、該当ファイルで `mutation_test/run.sh <name>` を回して生き残りを確認する

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
- **フォルダ構成**: `lib/` は機能ごとに分ける。`app/`（ホーム・ドロワー・設定・`AppDependencies`）、`calculator/`（計算機・`judge`・`trivia`）、`daily/`（今日の素因数分解）、`history/`（履歴）、`format/`（数の表示形式・読み上げ）、`shared/`（どこからでも使う小さな部品）。入口の `main.dart` だけが直下。層の割り当て（`tool/deps/build.py` の `LAYERS` / `SHARED`）はファイル名で書くので、フォルダに関係なく同じ。新しいファイルは機能の近くに置き、`LAYERS` / `SHARED` にも書き足す
- **`lib/main.dart`**: Main app entry point with MaterialApp setup, theme configuration, and localization delegates (`PrimeFactApp`)
- **`lib/app/app_dependencies.dart`**: 時計・保存先（Repository）・計算・共有・URL の差し替え口を `AppDependencies` にまとめる（Widget に依存しない純粋な Dart）。`PrimeFactApp(dependencies: ...)` が組み立てて（省くと本番の実装。本番の実装を選ぶのはここだけ）`HomePage(dependencies:)` に渡し、`HomePage` が必要なものを子の Widget に引数で渡す（`AppDrawer(openUrl)`、`DailyBanner(repository, now, share)` → `DailyPage(onShare)`、`CalculatorForm(calculator, share, now)`）。依存を読んでよいのは入口の層（`main` と `HomePage`）だけで、画面や部品は `AppScope` のようなものから自分で取らず、引数で受け取る。テストで差し替える入口はここだけ（`DailyPage` を含め、`shareText` などの本番の実装に直結する既定値は持たない）
- **`lib/calculator/calculator.dart`**: `Calculator` 型（`BigInt` → `Factorization`）と `defaultCalculator`（Web は `factorizeAsync`、それ以外は別 Isolate の `factorizeInIsolate`）
- **`lib/calculator/calculator_controller.dart`**: 計算機の状態（`CalculatorController`、`ChangeNotifier`）。計算中か・結果欄の内容（`CalculatedOutput`（`Factorization` と `Trivia`）/ `FailedOutput`。文言は持たず、表示するときの言語で組み立てる）を持ち、計算の実行・中止・結果欄の消去をする。`calculate` は成功したときだけ履歴用の `HistoryEntry`（時刻は渡された `now` から取る）を返す（失敗・中止・破棄後は null、中止では直前の結果を残す）。Widget に依存しない
- **`lib/app/home_page.dart`**: ホーム画面（`HomePage`）。`AppDependencies` から依存を読み、ドロワー・バナー・計算機を並べる
- **`lib/app/home_controller.dart`**: ホーム画面の状態（`HomeController`、`ChangeNotifier`）。履歴と表示設定の読み込み・追加・保存を持ち、Widget に依存しない。読み込み前に追加した履歴は読み込んだ履歴の後ろに続け、読み込み前に変えた設定はその操作を優先する。履歴を読めなかったら保存しない（保存済みの履歴を空で上書きしないため）。保存の失敗は `bestEffort` で握りつぶす
- **`lib/app/app_drawer.dart`**: ドロワー（`AppDrawer`、状態を持たない）。履歴・バナーの表示切替・数の表示形式・アプリ情報のリンク
- **`lib/calculator/calculator_form.dart`**: 計算機の入力・結果表示（`CalculatorForm`）
- **`lib/calculator/judge.dart`**: Core business logic (Miller-Rabin primality test, Pollard-Brent factorization on `BigInt`; アルゴリズム本体は `yield` で区切れる `sync*`。`factorizeSync(BigInt)` は最後まで同期で回す版（テスト・isolate 用）、`factorizeAsync(n, CancelToken)` は約 50ms ごとにイベントループへ制御を返す版で、Web ではこれをメインスレッドで使う（Web には Isolate がなく `compute` だと画面が固まるため。速度は同期版と同程度）。Web 以外は `lib/calculator/judge_isolate.dart` の `factorizeInIsolate` で別 Isolate に出す（メインスレッドで区切ると 1 フレーム 16.7ms を超えて描画が落ちるため）。どちらも `CancelToken.cancel()` で `CancelledException` を投げて止まる。結果は `Factorization`（文言を含まない）)
- **`lib/calculator/factorization.dart`**: 因数分解の結果のデータ（`Factorization`: `n` と素因数の昇順の `PrimePower` のリスト、`isPrime` / `isComposite`）。表示の文言・形式は持たない。`notation`（`2^2x3`）は履歴の保存形式で、`fromNotation` で戻す（素数・1 以下は保存しないので、null で 2 以上なら素数とみなす）
- **`lib/calculator/trivia.dart`**: Replaces the primality header for special numbers (perfect / Mersenne / Fermat / palindromic / Sophie Germain / twin primes, 1729, 57 Grothendieck), e.g. "6は素数、ではなく完全数です！". `CalculatorController` が計算後に `triviaFor` で求めて `CalculatedOutput.trivia` に持ち、`HistoryPage` は行ごとに求めて覚える。見出しの文言は `result_text.dart` の `resultHeader` が組み立てる. To extend: add a `Trivia` value, its `isXxx` ARB strings (suffix after the number), a `triviaHeader` case and a test
- **`lib/history/history_*.dart`**: Calculation history (`HistoryEntry`, `HistoryRepository` persisting via `shared_preferences`, `HistoryPage`)
- **`lib/daily/daily_*.dart`**: 「今日の素因数分解」。`DailyPuzzle` が JST の日付だけから決定的に `n = p×q`（`p` は 7〜53 の最小の素因数、`q` は `p`〜293）を生成する（`p` の範囲は易/中/難 = 50/35/15% の 3 段階。難度は画面にもシェア文にも出さない）。`DailyProgress`/`DailyRepository` が開始時刻・ミス回数・クリア時刻を `shared_preferences` に保存し（離脱中も時間は進む）、`DailyBanner`（ホーム）→`DailyPage`（出題・結果・シェア）と遷移する。生成手順を変えると同じ日の問題が変わるので、変更時は日付で分岐し `test/daily_puzzle_test.dart` の固定値も更新する
- **`lib/daily/daily_controller.dart`**: 挑戦画面（`DailyPage`）の状態（`DailyController`、`ChangeNotifier`）。読み込み・回答の採点と保存・保存中の二重送信防止・クリア後の連続日数を持ち、Widget に依存しない。画面は `ListenableBuilder` で購読し、入力欄とエラー文だけを持つ。回答は保存に成功してから状態に反映する
- **`lib/daily/daily_banner_controller.dart`**: ホームのバナー（`DailyBanner`）の状態（`DailyBannerController`、`ChangeNotifier`）。表示する日の記録と累計の読み込み（世代で古い読み込みの結果を捨てる）、日付が変わったかの確認（`checkDate`。同じ日の読み込み中は待つ）、タップで開く問題（`puzzleToOpen`。日付が変わっていたら開かずに読み直す）、連続日数を出すかを持ち、Widget に依存しない。いつ読み直すか（30 秒ごとの確認・前面に戻ったとき・挑戦画面から戻ったとき）は画面が決める
- **`lib/shared/date_key.dart`**: 出題日 `yyyyMMdd`（int）の変換（`jstDateKey` / `formatDateKey` / 連続判定用の通し日数 `dayIndexOf`・`dateKeyOfDayIndex`）。出題・保存・累計が共有する
- **`lib/daily/daily_stats.dart` / `lib/daily/daily_records_page.dart`**: 「今日の素因数分解」の累計成績と記録画面。`DailyRepository.loadAll()` が `daily_<yyyyMMdd>` を全部読み（破損した日は除く）、`DailyStats.compute` が連続日数（今日が未クリアなら昨日までの連続を続行中として数える）・最長連続・クリア日数・ノーミス数・ベストタイム（時計変更で 0 になった記録は除く）を求める。バナー（記録ボタンと連続日数）、挑戦画面（AppBar の記録ボタン、クリア後の連続日数）から使う
- **`lib/app/settings_repository.dart`**: 表示設定（ドロワーのスイッチで「今日の素因数分解」バナーの表示/非表示を切り替え、`shared_preferences` に保存。既定は表示）
- **`lib/format/number_style.dart`**: 数の表示形式（そのまま/カンマ区切り/アポストロフィ区切り/単位つき）。結果・履歴・コピー・共有の表示時に整形する（保存値は素の数字）。単位つき（万・億…）は日本語のみで、英語では選択肢を出さず `effectiveStyle` で plain 扱いにする。数字だけの文字列を整形する（`formatDigits`）。どの数を整形するかは `result_text.dart` が決める。設定は `SettingsRepository` に保存。コピー・共有は画面に出ている形式のまま出す（入力欄は `digitsOnly` なのでカンマ付きは貼っても数字に戻るが、単位つきの「万」「億」は消えて別の数になる）。「今日の素因数分解」の画面・シェア文は対象外（n が小さく効果が薄いため）
- **`lib/format/result_text.dart`**: `Factorization` から結果欄・コピー・共有・履歴の行を組み立てる（`resultLines`。1 行目は数＋見出し（`resultHeader`）、合成数なら 2 行目に `n=2^2x3`）。数（n と素因数）は表示形式で整形し、指数は整形しない。`breakable` で「=」の直後と「x」の直前にだけ折り返し用の幅のない空白を入れる（画面のみ。コピー・共有には入れない）。表示中の結果も履歴も、表示するときの言語で出る
- **`lib/format/spoken.dart`**: スクリーンリーダー向けの読み上げ文。`Factorization` を「60は2の2乗かける3かける5」のように言葉にする（ARB の `spoken*`）。結果の `Text.semanticsLabel`（`liveRegion` で計算完了も読み上げる）、計算中のインジケーター、履歴の各行に使う。数の整形は、日本語の単位つき（「1万2345」）のときだけ読み上げにも反映し、カンマ・アポストロフィ区切りは素の数字のまま読ませる（指数は整形しない）。表示用の文字列（折り返し用の不可視文字を含む）は変えない。`semanticsLabel` を付けた `Text` は `Semantics` で包まれるので、テストで段落を取るときは `find.descendant(of: ..., matching: find.byType(RichText))` を使う
- **`lib/shared/share.dart`**: 共有（`shareText`: 共有シート、なければクリップボードにコピーして `ShareOutcome.copied`。`originOf`: iPad のポップオーバーの基準位置）。結果の共有と「今日の素因数分解」のシェアが共有する
- **`lib/shared/language.dart`**: `isJapanese(loc)`。言語による分岐（単位つきの可否、読み上げなど）はこれで判定する
- **`lib/shared/best_effort.dart`**: 保存の失敗方針（保存に失敗しても、この起動中の画面の状態は保つ）の `bestEffort` と、Repository ごとの読み込み失敗の扱いの一覧
- **`lib/shared/links.dart`**: 外部リンク（プライバシーポリシー、Play ストア、Web アプリなど）の定数と、URL を開く `UrlOpener` / `defaultUrlOpener`。ドロワーとシェア文で共有する
- **`lib/l10n/`**: Internationalization files for Japanese and English support

### Key Components
1. **PrimeFactApp**: Root widget with theme and localization configuration（`AppDependencies` を組み立てる）
2. **HomePage** / `HomeController`: Main layout with drawer navigation、履歴と表示設定
3. **CalculatorForm** / `CalculatorController`: Primary calculator interface with input field and result display
4. **DailyBanner** / `DailyBannerController` → **DailyPage** / `DailyController`: 「今日の素因数分解」

### Algorithm Implementation
- Primality: Miller-Rabin with fixed witnesses (deterministic below 3.3×10^24, error < 4^-20 for 30 digits)
- Factorization: Pollard-Brent rho on `BigInt`, recursing on found factors
- Supports integers up to 30 digits
- Returns formatted results with Japanese/English localization

### State Management
- 画面ごとの状態は Flutter 標準の `ChangeNotifier` のコントローラーに置く（`HomeController` / `CalculatorController` / `DailyBannerController` / `DailyController`）。コントローラーは Widget・`BuildContext` に依存せず、依存（Repository・時計・計算）は引数で受け取るので、Widget なしで単体テストできる
- Widget は自分の `State` でコントローラーを作って `dispose` し、`ListenableBuilder` で購読する。`State` に残すのは入力欄（`TextEditingController`）・エラー文・`SnackBar` など表示と Flutter 固有のもの（タイマー、アプリの前面復帰の購読、画面遷移）だけ
- コントローラーは破棄後に通知しない（`_disposed` を見る）。非同期の結果は「保存に成功してから状態に反映する」「古い読み込みの結果は捨てる」など、それぞれのクラスのコメントに方針を書く
- 状態管理ライブラリ（Provider, Riverpod, Bloc など）は使わない。コントローラーは画面の中で作るので、共有のための仕組みが要らない。依存は `AppDependencies` から引数で渡す

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
- **Build tools**: AGP 9.1.1 / Gradle 9.3.1 (`android.newDsl=false` で opt-out)
- **Build file**: `android/app/build.gradle`
- **Release signing**: Configured with keystore properties

### iOS
- **Platform**: iOS 13.0+ (share_plus の要件)
- **Configuration**: `ios/Runner/Info.plist`
- **Display name**: Supports Japanese characters

## Dependencies

### Core Dependencies
- `material_ui` / `cupertino_ui` - Material/Cupertino（`flutter/material.dart` は 3.47 で非推奨）
- `styled_text: ^10.0.0` - Rich text formatting for results
- `flutter_localizations` (SDK) - Internationalization support
- `intl: ^0.20.2` - Date/number formatting
- `shared_preferences: ^2.3.0` - Persisting calculation history
- `url_launcher: ^6.3.0` - External links in drawer
- `share_plus: ^13.3.1` - Sharing the daily challenge result

### Dev Dependencies
- `flutter_launcher_icons: ^0.14.4` - Custom app icon generation
- `very_good_analysis: ^11.0.0` - Lint rules (`analysis_options.yaml`)。アプリの設計上合わない一部のルールは理由付きで無効化している

## Development Notes

### Code Style
- Mixed Japanese/English comments in codebase
- Material Design pattern throughout
- Teal color scheme for consistent branding

### Testing
- `test/judge_test.dart`: primality (Carmichael numbers, strong pseudoprimes), factorization (prime powers, trial-division boundary, ~30-digit semiprime), trivial inputs, `Factorization` round trip through the real `compute` isolate, `factorizeAsync` / `factorizeInIsolate`（同期版と同じ結果・制御を返すこと・中止）
- `test/trivia_test.dart`: each special-number category and near-miss numbers (e.g. 121, 120, 15)
- `test/factorization_test.dart`: `isPrime` / `isComposite`、`notation`、`fromNotation`（素数・1 以下、30 桁、往復、壊れた記法は `FormatException`）
- `test/result_text_test.dart`: 見出し（豆知識が優先）、結果の行（合成数・素数・1 以下）、表示時の言語に従うこと、数の整形と指数の除外、負の数、折り返し位置
- `test/history_test.dart`: `HistoryEntry` JSON round trip and legacy-format migration, `fromFactorization`, 保存データからの `factorization`, `HistoryRepository` load/save/corrupted data（読めない `factors` を含む）
- `test/date_key_test.dart`: JST の日付切り替え、タイムゾーン非依存、通し日数（月/年/うるう日またぎ）
- `test/daily_puzzle_test.dart`: determinism, JST date rollover, p/q ranges, tier ratios, fixed-date regression values
- `test/calculator_controller_test.dart`: `CalculatorController` の成功・失敗・中止（直前の結果を残す）、特別な数の豆知識、素数の履歴、結果欄の消去、破棄後に通知しないこと
- `test/daily_controller_test.dart`: `DailyController` の読み込み（開始時刻の保持・失敗と再試行）、採点と保存、保存失敗で状態が変わらないこと、二重送信の無視、連続日数、破棄後に通知しないこと
- `test/daily_banner_controller_test.dart`: `DailyBannerController` の読み込み（失敗は未開始扱い・累計が読めなければ省く）、連続日数を出す条件、日付の変化での読み直し（同じ日の読み込み中は待つ）、古い読み込みの破棄、開く問題（日付が変わったら開かない）、破棄後に通知しないこと
- `test/daily_progress_test.dart`, `test/daily_challenge_test.dart`: progress/repository, banner → challenge → result flow, share text
- `test/daily_stats_test.dart`: 連続日数（途切れ・月/年/うるう年またぎ・未クリア日）、ノーミス数、ベストタイム、`loadAll`、バナーの連続表示と記録画面
- `test/daily_robustness_test.dart`: load/save failures, share fallback rules, stale reloads, double submit, Enter key, share errors, banner at JST midnight, short screen with keyboard
- `test/number_style_test.dart`: 各形式の整形、英語での単位つき無効化、設定の保存
- `test/number_format_ui_test.dart`: ドロワーからの形式選択（カンマ・アポストロフィ・単位つき）、結果・共有・履歴への反映、英語で単位つきが出ないこと、クリアボタン（有効条件: 入力/結果/エラーのいずれか、入力と結果の消去、日本語ラベル）
- `test/spoken_test.dart`: 読み上げ文（ja/en、べき乗、30 桁、素数・1 以下、豆知識）、結果の読み上げラベルと liveRegion、整形形式に依存しないこと、計算中ラベル、履歴の行
- `test/home_controller_test.dart`: `HomeController` の履歴（読み込み前の追加の連結、読み込み失敗で保存しない、保存失敗でも残す、外から変えられない）、設定（読み込み中の値、読み込み前の操作の優先、保存失敗でも残す）、破棄後に通知しないこと
- `test/best_effort_test.dart`: 保存の失敗を握りつぶして続けること
- `test/settings_test.dart`: daily banner toggle in the drawer and its persistence
- `test/widget_test.dart`: calculator UI, input validation errors, localized results, history save races (injected `HistoryRepository`), failed and cancelled calculation (injected `Calculator`), drawer links (injected `UrlOpener`), wrapped result (line breaks only after `=` and before `x`), 表示中の結果が言語の切り替えに従うこと, copy/share buttons, fixed input position
- `test/helpers/localized_app.dart`: 画面単体のテスト用の `localizedApp(home, {locale})`（ローカライズ付きの `MaterialApp`）
- Add tests alongside any change to `judge.dart` or the history format

### Known Limitations
- Factoring a ~30-digit number whose prime factors are both ~15 digits can take a long time (14 桁×14 桁で JIT 約 7 秒)。計算中は「中止」ボタンで止められるが、速くするには別のアルゴリズム（ECM / SIQS）が必要
- Web は dart2js の BigInt が VM よりずっと遅く（24 桁で約 10 倍）、さらにタブが裏に回るとタイマーが間引かれて区切りのたびに待たされ、計算が大きく遅くなる。根本対応は Web Worker 化
- History grows without a size limit
- Daily challenge results (`daily_<yyyyMMdd>` in `shared_preferences`) are never deleted: one small key per day played
- Daily challenge times use the device wall clock (no server): changing the clock can distort or zero the recorded time, and a negative elapsed time is shown as 0:00.0
- Daily records dated after today (left by moving the device clock forward) are ignored by the stats and the records page until that date actually arrives
- A corrupted daily record is treated as "not started" and overwritten, so the cleared state is lost (it cannot be recovered anyway)
