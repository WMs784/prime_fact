// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get title => '素因数分解計算機';

  @override
  String get info => 'アプリ情報';

  @override
  String get button => '素因数分解';

  @override
  String get description => '18桁以下の正整数を入力してください';

  @override
  String get isPrime => 'は素数です！';

  @override
  String get isNotPrime => 'は素数ではありません';

  @override
  String get privacyPolicy => 'プライバシーポリシー';

  @override
  String get review => '評価する';

  @override
  String get contact => 'お問い合わせ';

  @override
  String get aboutUs => '開発者情報';
}
