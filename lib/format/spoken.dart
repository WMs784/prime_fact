import 'package:prime_fact/calculator/factorization.dart';
import 'package:prime_fact/calculator/trivia.dart';
import 'package:prime_fact/format/number_style.dart';
import 'package:prime_fact/format/result_text.dart';
import 'package:prime_fact/l10n/app_localizations.dart';
import 'package:prime_fact/shared/language.dart';

/// 結果をスクリーンリーダー向けの文にする（例: 「60は素数ではありません。60は2の2乗かける3かける5」）。
///
/// 画面に出す形式（`^` や `x`、折り返し用の不可視文字）は読み上げに向かないので、
/// 因数分解を言葉にする。見出しは画面と同じ（[resultHeader]）。
///
/// 数の整形は、日本語の単位つき（`1万2345`）のときだけ読み上げにも反映する。
/// カンマやアポストロフィの区切りは読み上げでは邪魔なので、素の数字のまま読ませる。
/// 指数は整形しない（「2の10乗」のまま読ませる）。
String spokenResult(
  AppLocalizations loc,
  Factorization f,
  Trivia? trivia, {
  NumberStyle numberStyle = NumberStyle.plain,
}) {
  final units =
      effectiveStyle(numberStyle, ja: isJapanese(loc)) == NumberStyle.units;
  String number(BigInt v) =>
      units ? formatDigits('$v', NumberStyle.units, ja: true) : '$v';

  final n = number(f.n);
  final header = '$n${resultHeader(loc, f, trivia)}';
  if (!f.isComposite) return header;
  final factors = f.factors
      .map(
        (p) => p.exponent == 1
            ? number(p.prime)
            : loc.spokenPower(number(p.prime), '${p.exponent}'),
      )
      .reduce(loc.spokenTimes);
  return '$header${loc.spokenLineSeparator}'
      '${loc.spokenFactorization(n, factors)}';
}
