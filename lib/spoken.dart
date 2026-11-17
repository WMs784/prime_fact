import 'package:prime_fact/l10n/app_localizations.dart';
import 'package:prime_fact/number_style.dart';

final _factorToken = RegExp(r'^(\d+)(?:\^(\d+))?$');

/// 結果の文字列（`"60 NP\n60=2^2x3x5"`）を、スクリーンリーダー向けの文にする。
///
/// 画面に出す形式（`^` や `x`、折り返し用の不可視文字）は読み上げに向かないので、
/// 因数分解の行だけ「60は2の2乗かける3かける5」のように言葉にする。
/// [result] は整形前の文字列を渡す（区切り文字のない数字のまま読ませるため）。
/// 因数分解の行がない・形式が想定と違うときは、数の整形以外は [result] のまま返す。
///
/// 数の整形は、日本語の単位つき（`1万2345`）のときだけ読み上げにも反映する。
/// カンマやアポストロフィの区切りは読み上げでは邪魔なので、素の数字のまま読ませる。
/// 指数は整形しない（「2の10乗」のまま読ませる）。
String spokenResult(
  AppLocalizations loc,
  String result, {
  NumberStyle numberStyle = NumberStyle.plain,
}) {
  final units =
      effectiveStyle(numberStyle, ja: isJapanese(loc)) == NumberStyle.units;
  String digits(String s) =>
      units ? formatDigits(s, NumberStyle.units, ja: true) : s;
  String text(String s) =>
      units ? formatNumbers(s, NumberStyle.units, ja: true) : s;

  final lines = result.split('\n');
  if (lines.length != 2) return text(result);
  final eq = lines[1].indexOf('=');
  if (eq < 0) return text(result);

  final parts = <String>[];
  for (final token in lines[1].substring(eq + 1).split('x')) {
    final m = _factorToken.firstMatch(token);
    if (m == null) return text(result);
    final exponent = m[2];
    parts.add(
      exponent == null
          ? digits(token)
          : loc.spokenPower(digits(m[1]!), exponent),
    );
  }
  final factorization = loc.spokenFactorization(
    digits(lines[1].substring(0, eq)),
    parts.reduce(loc.spokenTimes),
  );
  return '${text(lines[0])}${loc.spokenLineSeparator}$factorization';
}
