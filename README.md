# 素因数分解計算機 / Prime Factorization Calculator

正の整数を入力すると素因数分解の結果を表示する Flutter アプリです。日本語・英語に対応しています。

A Flutter app that factorizes a positive integer into primes. Supports Japanese and English.

## 機能 / Features

- 30 桁以下の正の整数を素因数分解 (Miller-Rabin 法による素数判定 + Pollard-Brent 法)
- 入力が素数の場合はその旨を表示
- 計算履歴の保存・表示
- 日本語 / 英語 (端末の言語設定に従う)

## 必要環境 / Requirements

- Flutter 3.47 以上 (Dart 3.13 以上)
- Android: AGP 9.1 / Gradle 9.3 (ラッパーに同梱)

## 開発 / Development

```bash
flutter pub get
flutter run            # 実機・エミュレータで起動
flutter analyze        # 静的解析
flutter test           # テスト
flutter gen-l10n       # ARB 変更後にローカライズを再生成
```

コミット前に `analyze` と `test` を実行する pre-commit フックを用意しています。クローン後に一度だけ有効化してください。

```bash
git config core.hooksPath .githooks
```

## ビルド / Build

```bash
flutter build apk          # Android APK
flutter build appbundle    # Android App Bundle (Play Store 向け)
flutter build ios
```

Release ビルドの署名には `android/key.properties` が必要です (リポジトリには含まれません)。

## CI

GitHub Actions (`.github/workflows/ci.yml`) が `master` 向け PR と `master` への push で、`flutter analyze`、`flutter test`、debug APK のビルドを実行します。

## ディレクトリ構成 / Structure

| パス | 内容 |
| --- | --- |
| `lib/main.dart` | アプリのエントリポイントと計算画面 |
| `lib/judge.dart` | 素数判定・素因数分解のロジック |
| `lib/history_*.dart` | 計算履歴 |
| `lib/l10n/` | 日英のローカライズ (ARB) |
| `test/` | テスト |
