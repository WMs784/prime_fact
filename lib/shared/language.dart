import 'package:prime_fact/l10n/app_localizations.dart';

/// 現在の言語が日本語か。単位つき表示の可否や読み上げなど、言語による分岐はこれで判定する。
bool isJapanese(AppLocalizations loc) => loc.localeName.startsWith('ja');
