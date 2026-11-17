import 'package:prime_fact/l10n/app_localizations.dart';

final _factorToken = RegExp(r'^(\d+)(?:\^(\d+))?$');

/// 結果の文字列（`"60 NP\n60=2^2x3x5"`）を、スクリーンリーダー向けの文にする。
///
/// 画面に出す形式（`^` や `x`、折り返し用の不可視文字）は読み上げに向かないので、
/// 因数分解の行だけ「60は2の2乗かける3かける5」のように言葉にする。
/// [result] は整形前の文字列を渡す（区切り文字のない数字のまま読ませるため）。
/// 因数分解の行がない・形式が想定と違うときは、[result] をそのまま返す。
String spokenResult(AppLocalizations loc, String result) {
  final lines = result.split('\n');
  if (lines.length != 2) return result;
  final eq = lines[1].indexOf('=');
  if (eq < 0) return result;

  final parts = <String>[];
  for (final token in lines[1].substring(eq + 1).split('x')) {
    final m = _factorToken.firstMatch(token);
    if (m == null) return result;
    final exponent = m[2];
    parts.add(exponent == null ? token : loc.spokenPower(m[1]!, exponent));
  }
  final factorization = loc.spokenFactorization(
    lines[1].substring(0, eq),
    parts.join(loc.spokenTimes),
  );
  return '${lines[0]}${loc.spokenLineSeparator}$factorization';
}
