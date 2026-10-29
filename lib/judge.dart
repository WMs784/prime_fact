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

// Brent's improvement of Pollard's rho with batch GCD (m=128)
BigInt _pollardBrent(BigInt n, BigInt c) {
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

  return d;
}

BigInt _findFactor(BigInt n) {
  if (n.isEven) return BigInt.two;
  for (int c = 1; ; c++) {
    final d = _pollardBrent(n, BigInt.from(c));
    if (d != n) return d;
  }
}

void _factorHelper(BigInt n, Map<BigInt, int> factors) {
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

  final f = _findFactor(n);
  _factorHelper(f, factors);
  _factorHelper(n ~/ f, factors);
}

// args = [n (BigInt), isNotPrimeStr, isPrimeStr]
// ignore: non_constant_identifier_names
String pri_fact_isolate(List<dynamic> args) {
  final BigInt n = args[0] as BigInt;
  final String isNotPrime = args[1] as String;
  final String isPrime = args[2] as String;

  final nStr = n.toString();
  if (n <= BigInt.one) return nStr + isNotPrime;
  if (_isPrime(n)) return nStr + isPrime;

  final factors = <BigInt, int>{};
  _factorHelper(n, factors);

  final sortedEntries = factors.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));

  final factStr = sortedEntries
      .map((e) {
        return e.value == 1 ? e.key.toString() : '${e.key}^${e.value}';
      })
      .join('x');

  return '$nStr$isNotPrime\n$nStr=$factStr';
}
