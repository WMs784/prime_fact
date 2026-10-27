# 素因数分解計算機 / Prime Factorization Calculator

正の整数を入力すると素因数分解の結果を表示する Flutter アプリです。日本語・英語に対応しています。

A Flutter app that factorizes a positive integer into primes. Supports Japanese and English.

---

# ユーザー向け / For Users

## 機能 / Features

- 30 桁以下の正の整数を素因数分解
- 入力が素数の場合はその旨を表示
- 計算履歴の保存・表示
- 日本語 / 英語 (端末の言語設定に従う)

## インストール / Install

- Android: [Google Play](https://play.google.com/store/apps/details?id=project.My_prime_nember)
- 動作環境: Android 5.0 (API 21) 以上

## 使い方 / Usage

1. 入力欄に 30 桁以下の正の整数を入力する
2. 「calculate」ボタンを押す
3. 素因数分解の結果 (素数の場合はその旨) が表示される
4. 過去の計算はドロワーの「履歴」から確認できる

## サポート / Support

- [アプリ紹介・プライバシーポリシー](https://wms784.github.io/prime_fact/)
- 不具合報告・問い合わせ: アプリのドロワー内「お問い合わせ」、または GitHub Issues

## ライセンス / License

[MIT License](LICENSE) の下で公開しています。

This project is licensed under the [MIT License](LICENSE).

---

# コミッター向け / For Contributors

## 必要環境

- Flutter 3.47 以上 (Dart 3.13 以上)
- Android: AGP 9.1 / Gradle 9.3 (ラッパーに同梱)。古い Flutter ではビルドできません

## セットアップ

```bash
git clone https://github.com/WMs784/prime_fact.git
cd prime_fact
flutter pub get
git config core.hooksPath .githooks   # pre-commit フックを有効化 (初回のみ)
```

pre-commit フックはコミット前に `flutter analyze` と `flutter test` を実行します。

## 開発コマンド

```bash
flutter run            # 実機・エミュレータで起動
flutter analyze        # 静的解析
flutter test           # テスト
flutter gen-l10n       # ARB 変更後にローカライズを再生成
```

## ビルド

```bash
flutter build apk          # Android APK
flutter build appbundle    # Android App Bundle (Play Store 向け)
flutter build ios
```

Release ビルドの署名には `android/key.properties` が必要です (リポジトリには含まれません)。

## ディレクトリ構成

| パス | 内容 |
| --- | --- |
| `lib/main.dart` | アプリのエントリポイントと計算画面 |
| `lib/judge.dart` | 素数判定 (Miller-Rabin) と素因数分解 (Pollard-Brent) |
| `lib/history_*.dart` | 計算履歴 (`shared_preferences` で永続化) |
| `lib/l10n/` | 日英のローカライズ (ARB) |
| `test/` | テスト |

## ブランチ運用と CI

- `master` から feature ブランチを切り、`master` 向けに PR を作成します
- GitHub Actions (`.github/workflows/ci.yml`) が `master` 向け PR と `master` への push で、`flutter analyze`、`flutter test`、debug APK のビルドを実行します
- 自動生成される各プラットフォームのプラグイン登録ファイル (`generated_plugin_registrant.*` など) は Git 管理対象外です
