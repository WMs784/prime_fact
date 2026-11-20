import 'package:material_ui/material_ui.dart';
import 'package:prime_fact/l10n/app_localizations.dart';
import 'package:prime_fact/main.dart' show appLocalizationsDelegates;

/// ローカライズ付きの [MaterialApp] に [home] を載せる。画面単体のテスト用。
///
/// [locale] を省くと、テスト環境のロケール（`setLocale` や `localesTestValue`）に従う。
Widget localizedApp(Widget home, {Key? key, Locale? locale}) => MaterialApp(
  key: key,
  locale: locale,
  localizationsDelegates: appLocalizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);
