import 'dart:async';

BigInt _gcd(BigInt a, BigInt b) {
  while (b != BigInt.zero) {
    final t = b;
    b = a % b;
    a = t;
  }
  return a;
}

// Deterministic for n < 3.3×10^24; effectively deterministic (error < 4^-20) for 30-digit n
const _witnesses = [
  2,
  3,
  5,
  7,
  11,
  13,
  17,
  19,
  23,
  29,
  31,
  37,
  41,
  43,
  47,
  53,
  59,
  61,
  67,
  71,
];

bool _isPrime(BigInt n) {
  if (n < BigInt.two) return false;
  if (n == BigInt.two) return true;
  if (n.isEven) return false;
  if (n < BigInt.from(9)) return true;

  BigInt d = n - BigInt.one;
  int r = 0;
  while (d.isEven) {
    d >>= 1;
    r++;
  }

  outer:
  for (final a in _witnesses) {
    final aBig = BigInt.from(a);
    if (aBig >= n) continue;

    BigInt x = aBig.modPow(d, n);
    if (x == BigInt.one || x == n - BigInt.one) continue;

    for (int i = 0; i < r - 1; i++) {
      x = x.modPow(BigInt.two, n);
      if (x == n - BigInt.one) continue outer;
    }
    return false;
  }
  return true;
}

/// 素数判定（`_isPrime` の公開版）。
bool isProbablePrime(BigInt n) => _isPrime(n);

/// `sync*` の途中経過から値を受け取るための入れ物。
class _Box<T> {
  T value;
  _Box(this.value);
}

// 以下の因数分解は、一定の計算ごとに `yield` して呼び出し側へ制御を返せる形（Iterable）で書く。
// 同期で最後まで回せば `pri_fact_isolate`、時間で区切って UI に制御を返しながら回せば
// `factorizeAsync`（Web には Isolate がないので、重い計算で画面が固まらないようにするため）。

// Brent's improvement of Pollard's rho with batch GCD (m=128)
Iterable<void> _pollardBrent(BigInt n, BigInt c, _Box<BigInt> out) sync* {
  BigInt y = BigInt.from(2);
  BigInt x = BigInt.zero;
  BigInt ys = BigInt.zero;
  BigInt d = BigInt.one;
  BigInt q = BigInt.one;
  int r = 1;
  const m = 128;

  while (d == BigInt.one) {
    x = y;
    for (int i = 0; i < r; i++) {
      y = (y * y + c) % n;
      if (i & 1023 == 1023) yield null;
    }
    int k = 0;
    while (k < r && d == BigInt.one) {
      ys = y;
      final steps = (r - k) < m ? (r - k) : m;
      for (int i = 0; i < steps; i++) {
        y = (y * y + c) % n;
        q = q * (x - y).abs() % n;
      }
      d = _gcd(q, n);
      k += m;
      yield null;
    }
    r *= 2;
  }

  if (d == n) {
    // バッチ内で複数の因数が同時に見つかった場合、1ステップずつ巻き戻して絞り込む
    do {
      ys = (ys * ys + c) % n;
      d = _gcd((x - ys).abs(), n);
    } while (d == BigInt.one);
  }

  out.value = d;
}

Iterable<void> _findFactor(BigInt n, _Box<BigInt> out) sync* {
  if (n.isEven) {
    out.value = BigInt.two;
    return;
  }
  for (int c = 1; ; c++) {
    final d = _Box(n);
    yield* _pollardBrent(n, BigInt.from(c), d);
    if (d.value != n) {
      out.value = d.value;
      return;
    }
  }
}

Iterable<void> _factorHelper(BigInt n, Map<BigInt, int> factors) sync* {
  if (n == BigInt.one) return;

  // Trial division up to 1000 for small prime factors
  for (int p = 2; p <= 1000; p += p == 2 ? 1 : 2) {
    final pBig = BigInt.from(p);
    while (n % pBig == BigInt.zero) {
      factors.update(pBig, (v) => v + 1, ifAbsent: () => 1);
      n ~/= pBig;
    }
    if (n == BigInt.one) return;
  }

  if (_isPrime(n)) {
    factors.update(n, (v) => v + 1, ifAbsent: () => 1);
    return;
  }

  final f = _Box(n);
  yield* _findFactor(n, f);
  yield* _factorHelper(f.value, factors);
  yield* _factorHelper(n ~/ f.value, factors);
}

/// `pri_fact_isolate` への入力（isolate に渡せるよう record にしている）。
///
/// [special] は、素数/合成数の見出しを差し替える（完全数や 57 など）。因数分解の結果はそのまま出す。
typedef FactorRequest = ({
  BigInt n,
  String isNotPrime,
  String isPrime,
  String? special,
});

Iterable<void> _factorize(FactorRequest request, _Box<String> out) sync* {
  final n = request.n;
  final isNotPrime = request.isNotPrime;
  final isPrime = request.isPrime;
  final special = request.special;

  final nStr = n.toString();
  if (n <= BigInt.one) {
    out.value = nStr + isNotPrime;
    return;
  }
  if (_isPrime(n)) {
    out.value = nStr + (special ?? isPrime);
    return;
  }

  final factors = <BigInt, int>{};
  yield* _factorHelper(n, factors);

  final sortedEntries = factors.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));

  final factStr = sortedEntries
      .map((e) {
        return e.value == 1 ? e.key.toString() : '${e.key}^${e.value}';
      })
      .join('x');

  out.value = '$nStr${special ?? isNotPrime}\n$nStr=$factStr';
}

/// 最後まで同期で計算する。isolate（`compute`）に渡せるトップレベル関数。
// ignore: non_constant_identifier_names
String pri_fact_isolate(FactorRequest request) {
  final out = _Box('');
  for (final _ in _factorize(request, out)) {}
  return out.value;
}

/// 計算の中止の合図。[cancel] を呼ぶと、実行中の [factorizeAsync] が次の区切りで止まる。
class CancelToken {
  final _completer = Completer<void>();
  bool get isCancelled => _completer.isCompleted;

  /// 中止されたときに完了する。別 Isolate で動く計算を止めるのに使う。
  Future<void> get whenCancelled => _completer.future;

  void cancel() {
    if (!_completer.isCompleted) _completer.complete();
  }
}

/// [CancelToken] で中止されたときに [factorizeAsync] が投げる。
class CancelledException implements Exception {
  const CancelledException();
  @override
  String toString() => 'CancelledException';
}

/// `pri_fact_isolate` と同じ結果を、[slice] ごとに UI へ制御を返しながら計算する。
///
/// Web には Isolate がなく `compute` がメインスレッドで動くので、重い数で画面が固まる。
/// こちらは区切りのたびにイベントループへ戻るので、描画も入力も止まらず、
/// [token] による中止もできる（中止されると [CancelledException]）。
/// Web 以外では別 Isolate で動く `factorizeInIsolate` を使う（区切りで描画が落ちないため）。
Future<String> factorizeAsync(
  FactorRequest request,
  CancelToken token, {
  Duration slice = const Duration(milliseconds: 20),
}) async {
  final out = _Box('');
  final watch = Stopwatch()..start();
  for (final _ in _factorize(request, out)) {
    if (token.isCancelled) throw const CancelledException();
    if (watch.elapsed >= slice) {
      await Future<void>.delayed(Duration.zero);
      watch.reset();
    }
  }
  if (token.isCancelled) throw const CancelledException();
  return out.value;
}
