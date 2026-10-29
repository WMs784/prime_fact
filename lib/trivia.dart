import 'package:prime_fact/l10n/app_localizations.dart';

import 'judge.dart';

/// 素数判定の見出しを差し替える、数の種類。優先度の高い順に並べている。
enum Trivia {
  ramanujan,
  grothendieck,
  perfect,
  mersenne,
  fermat,
  palindromicPrime,
  sophieGermainPrime,
  twinPrime,
}

final _two = BigInt.two;
final _fermatPrimes = {3, 5, 17, 257, 65537}.map(BigInt.from).toSet();

/// [n] に当てはまる豆知識を返す。なければ null。
Trivia? triviaFor(BigInt n) {
  if (n == BigInt.from(1729)) return Trivia.ramanujan;
  if (n == BigInt.from(57)) return Trivia.grothendieck;
  if (_isPerfect(n)) return Trivia.perfect;
  if (n < _two || !isProbablePrime(n)) return null;

  // n + 1 が 2 のべき乗（n = 2^p - 1）。2^p - 1 が素数ならメルセンヌ素数
  if (n > _two && (n + BigInt.one) & n == BigInt.zero) return Trivia.mersenne;
  if (_fermatPrimes.contains(n)) return Trivia.fermat;
  if (_isPalindrome(n)) return Trivia.palindromicPrime;
  // 2n + 1 も素数
  if (isProbablePrime(n * _two + BigInt.one)) return Trivia.sophieGermainPrime;
  if (isProbablePrime(n + _two) || (n > _two && isProbablePrime(n - _two))) {
    return Trivia.twinPrime;
  }
  return null;
}

/// 偶数の完全数は 2^(k-1) * (2^k - 1)（2^k - 1 はメルセンヌ素数）に限られる。
bool _isPerfect(BigInt n) {
  if (n.isOdd || n < BigInt.from(6)) return false;
  for (var k = 2; ; k++) {
    final mersenne = (BigInt.one << k) - BigInt.one;
    final candidate = (BigInt.one << (k - 1)) * mersenne;
    if (candidate > n) return false;
    if (candidate == n) return isProbablePrime(mersenne);
  }
}

bool _isPalindrome(BigInt n) {
  final s = n.toString();
  return s.length >= 2 && s == s.split('').reversed.join();
}

/// [n] の素数判定の見出し（数の直後に続く文言）。
String headerFor(AppLocalizations loc, BigInt n) {
  final trivia = triviaFor(n);
  if (trivia != null) return triviaHeader(loc, trivia);
  return n >= _two && isProbablePrime(n) ? loc.isPrime : loc.isNotPrime;
}

String triviaHeader(AppLocalizations loc, Trivia trivia) => switch (trivia) {
  Trivia.ramanujan => loc.isRamanujanNumber,
  Trivia.grothendieck => loc.isGrothendieckPrime,
  Trivia.perfect => loc.isPerfectNumber,
  Trivia.mersenne => loc.isMersennePrime,
  Trivia.fermat => loc.isFermatPrime,
  Trivia.palindromicPrime => loc.isPalindromicPrime,
  Trivia.sophieGermainPrime => loc.isSophieGermainPrime,
  Trivia.twinPrime => loc.isTwinPrime,
};
