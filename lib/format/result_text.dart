import 'package:prime_fact/calculator/factorization.dart';
import 'package:prime_fact/calculator/trivia.dart';
import 'package:prime_fact/format/number_style.dart';
import 'package:prime_fact/l10n/app_localizations.dart';
import 'package:prime_fact/shared/language.dart';

/// 折り返してよい位置に入れる、幅のない空白。
const _breakable = '​';

/// 数の直後に続く見出し（「は素数です！」など）。[trivia] があればそちらを出す。
String resultHeader(AppLocalizations loc, Factorization f, Trivia? trivia) {
  if (trivia != null) return triviaHeader(loc, trivia);
  return f.isPrime ? loc.isPrime : loc.isNotPrime;
}

/// 結果欄・コピー・共有・履歴に出す行。1 行目は見出し、合成数なら 2 行目に因数分解
/// （例: `60は素数ではありません` / `60=2^2x3x5`）。
///
/// 数（n と素因数）は [style] で整形し、指数は整形しない。[breakable] なら、因数分解の行の
/// 「=」の直後と「x」の直前だけで折り返せるよう幅のない空白を入れる（数字や「^」の途中では
/// 折り返さない）。コピー・共有の文には入れない。
///
/// 「=」でも折り返すのは、`n=` と最初の因数が続けて 1 行に収まらないため。これで `n=`
/// （30 桁なら 31 文字）が 1 行に入る幅（20sp で約 350dp）なら、数字の途中で折り返さない。
List<String> resultLines(
  AppLocalizations loc,
  Factorization f,
  Trivia? trivia,
  NumberStyle style, {
  bool breakable = false,
}) {
  final ja = isJapanese(loc);
  String number(BigInt v) => v.isNegative
      ? '-${formatDigits('${-v}', style, ja: ja)}'
      : formatDigits('$v', style, ja: ja);

  final n = number(f.n);
  final header = '$n${resultHeader(loc, f, trivia)}';
  if (!f.isComposite) return [header];
  final b = breakable ? _breakable : '';
  final factors = f.factors
      .map(
        (p) => p.exponent == 1
            ? number(p.prime)
            : '${number(p.prime)}^${p.exponent}',
      )
      .join('${b}x');
  return [header, '$n=$b$factors'];
}
