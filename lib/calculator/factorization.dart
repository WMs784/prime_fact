/// 因数分解の結果を表すデータ。
///
/// 表示の文言（「は素数です！」など）や数の表示形式は持たない。画面・コピー・履歴・読み上げは、
/// 表示するときの言語と形式で、それぞれここから組み立てる（`lib/format/result_text.dart`、
/// `lib/format/spoken.dart`）。
library;

/// 素因数 [prime] の [exponent] 乗。
typedef PrimePower = ({BigInt prime, int exponent});

final _powerPattern = RegExp(r'^(\d+)(?:\^(\d+))?$');

/// `2^2` や `3` を [PrimePower] にする。読めなければ [FormatException]。
PrimePower _parsePower(String token) {
  final m = _powerPattern.firstMatch(token);
  if (m == null) throw FormatException('not a prime power', token);
  final exponent = m[2];
  return (
    prime: BigInt.parse(m[1]!),
    exponent: exponent == null ? 1 : int.parse(exponent),
  );
}

class Factorization {
  /// [factors] は素因数の昇順。[n] が 1 以下なら空、素数なら `[(prime: n, exponent: 1)]`。
  const new(this.n, this.factors);

  /// 履歴に保存した [notation] から戻す。合成数でないとき（素数・1 以下）は [notation] が null。
  ///
  /// 素数かどうかは保存していないので、[notation] が null で 2 以上なら素数とみなす
  /// （計算し直さない）。記法が読めなければ [FormatException]。
  factory fromNotation(BigInt n, String? notation) {
    if (notation == null) {
      return Factorization(
        n,
        n < BigInt.two ? const [] : [(prime: n, exponent: 1)],
      );
    }
    return Factorization(n, notation.split('x').map(_parsePower).toList());
  }

  final BigInt n;
  final List<PrimePower> factors;

  /// 素数か（素因数が 1 つで、その 1 乗）。
  bool get isPrime => factors.length == 1 && factors.first.exponent == 1;

  /// 合成数か（素因数の積として書ける。1 以下と素数は含まない）。
  bool get isComposite => factors.isNotEmpty && !isPrime;

  /// `2^2x3` の形（整形前の素の数字）。
  ///
  /// 履歴の保存形式でもある。変えるときは [fromNotation] で旧形式も読めるようにすること。
  String get notation => factors
      .map((f) => f.exponent == 1 ? '${f.prime}' : '${f.prime}^${f.exponent}')
      .join('x');
}
