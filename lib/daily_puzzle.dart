/// 「今日の素因数分解」の出題。日付だけから決定的に作るので、全ユーザーで同じ問題になる。
///
/// 公開後にこのファイルの生成手順を変えると、同じ日でも問題が変わってしまう。
/// 変えるときは日付で分岐し、`test/daily_puzzle_test.dart` の固定値も更新すること。
library;

/// 最小の素因数 [p] の範囲と、出題の割合（合計 100）。
const _tiers = <({int minP, int maxP, int weight})>[
  (minP: 7, maxP: 13, weight: 50), // 易
  (minP: 17, maxP: 31, weight: 35), // 中
  (minP: 37, maxP: 53, weight: 15), // 難
];

/// もう一方の素因数 [q] の上限。n が高々 5 桁（約 1.6 万）に収まる。
const _maxQ = 293;

final List<int> _primes = _sieve(_maxQ);

List<int> _sieve(int limit) {
  final composite = List<bool>.filled(limit + 1, false);
  final primes = <int>[];
  for (var i = 2; i <= limit; i++) {
    if (composite[i]) continue;
    primes.add(i);
    for (var j = i * i; j <= limit; j += i) {
      composite[j] = true;
    }
  }
  return primes;
}

/// 32bit 同士の積の下位 32bit。Web（double）でも 2^53 を超えないよう 16bit に分けて掛ける。
int _mul32(int a, int b) {
  final low = a * (b & 0xFFFF);
  final high = (a * (b >> 16)) & 0xFFFF;
  return (low + (high << 16)) & 0xFFFFFFFF;
}

int _mix32(int x) {
  x &= 0xFFFFFFFF;
  x ^= x >> 16;
  x = _mul32(x, 0x45d9f3b);
  x ^= x >> 16;
  x = _mul32(x, 0x45d9f3b);
  x ^= x >> 16;
  return x;
}

/// [seed] から i 番目の擬似乱数（32bit）を取り出す。
int _rand(int seed, int i) => _mix32(_mix32(seed) + i * 0x9E3779B9);

/// 出題日（JST）を `yyyyMMdd` の整数にする。端末のタイムゾーンに依存しない。
int jstDateKey(DateTime now) {
  final jst = now.toUtc().add(const Duration(hours: 9));
  return jst.year * 10000 + jst.month * 100 + jst.day;
}

/// `20261031` を `2026-10-31` にする。
String formatDateKey(int dateKey) {
  final y = dateKey ~/ 10000;
  final m = dateKey ~/ 100 % 100;
  final d = dateKey % 100;
  return '$y-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
}

class DailyPuzzle {
  final int dateKey;

  /// 最小の素因数（正解）。
  final int p;
  final int q;

  const DailyPuzzle._(this.dateKey, this.p, this.q);

  int get n => p * q;

  factory DailyPuzzle.forDateKey(int dateKey) {
    final roll = _rand(dateKey, 0) % 100;
    var acc = 0;
    var tier = _tiers.last;
    for (final t in _tiers) {
      acc += t.weight;
      if (roll < acc) {
        tier = t;
        break;
      }
    }
    final ps = _primes.where((x) => x >= tier.minP && x <= tier.maxP).toList();
    final p = ps[_rand(dateKey, 1) % ps.length];
    final qs = _primes.where((x) => x >= p).toList();
    final q = qs[_rand(dateKey, 2) % qs.length];
    return DailyPuzzle._(dateKey, p, q);
  }

  factory DailyPuzzle.forDate(DateTime now) =>
      DailyPuzzle.forDateKey(jstDateKey(now));

  bool isCorrect(int answer) => answer == p;
}
