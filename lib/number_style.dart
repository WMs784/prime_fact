import 'package:prime_fact/l10n/app_localizations.dart';

/// 結果に出てくる数の表示形式。
enum NumberStyle {
  /// そのまま（既定）
  plain,

  /// 3 桁区切りのカンマ（1,234,567）
  comma,

  /// 単位つき（日本語のみ: 1億2345万。英語では一般的でないため使わない）
  units;

  static NumberStyle fromName(String? name) => NumberStyle.values.firstWhere(
    (s) => s.name == name,
    orElse: () => NumberStyle.plain,
  );
}

const _jaUnits = ['', '万', '億', '兆', '京', '垓', '秭', '穰'];
// 指数（`^` に続く数字の並び）は整形しない。
// 直前が `^` か数字の位置からは始めないので、`^1234` の途中（`234`）も拾わない。
final _numberPattern = RegExp(r'(?<![\^\d])\d+');

/// 言語 [ja] で実際に使う形式。英語では単位つきを使わず、そのまま表示する。
NumberStyle effectiveStyle(NumberStyle style, {required bool ja}) =>
    (style == NumberStyle.units && !ja) ? NumberStyle.plain : style;

/// [text] に含まれる数（指数を除く）を [style] に従って整形する。
String formatNumbers(String text, NumberStyle style, {required bool ja}) {
  style = effectiveStyle(style, ja: ja);
  if (style == NumberStyle.plain) return text;
  return text.replaceAllMapped(
    _numberPattern,
    (m) => formatDigits(m[0]!, style, ja: ja),
  );
}

/// 数字だけの文字列 [digits] を整形する。
String formatDigits(String digits, NumberStyle style, {required bool ja}) {
  switch (style) {
    case NumberStyle.plain:
      return digits;
    case NumberStyle.comma:
      return _group(digits, 3).join(',');
    case NumberStyle.units:
      if (!ja) return digits;
      final groups = _group(digits, 4);
      if (groups.length == 1 || groups.length > _jaUnits.length) return digits;
      final parts = <String>[];
      for (var i = 0; i < groups.length; i++) {
        final value = int.parse(groups[i]);
        if (value == 0) continue;
        final unit = _jaUnits[groups.length - 1 - i];
        parts.add('$value$unit');
      }
      return parts.isEmpty ? '0' : parts.join();
  }
}

/// 末尾から [size] 桁ずつに分ける。
List<String> _group(String digits, int size) {
  final groups = <String>[];
  for (var end = digits.length; end > 0; end -= size) {
    final start = end - size < 0 ? 0 : end - size;
    groups.insert(0, digits.substring(start, end));
  }
  return groups;
}

/// 現在の言語が日本語か。単位つき表示の可否など、言語による分岐はこれで判定する。
bool isJapanese(AppLocalizations loc) => loc.localeName.startsWith('ja');

/// 現在の言語に合わせて [text] の数を [style] で整形する。
String formatForLocale(AppLocalizations loc, String text, NumberStyle style) =>
    formatNumbers(text, style, ja: isJapanese(loc));
