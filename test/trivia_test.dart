import 'package:flutter_test/flutter_test.dart';
import 'package:prime_fact/trivia.dart';

Trivia? t(String n) => triviaFor(BigInt.parse(n));

void main() {
  test('perfect numbers', () {
    for (final n in ['6', '28', '496', '8128', '33550336', '8589869056']) {
      expect(t(n), Trivia.perfect, reason: n);
    }
    // 2^(k-1) * (2^k - 1) の形でも 2^k - 1 が合成数なら完全数ではない
    expect(t('120'), isNull); // 2^3 * 15
    expect(t('12'), isNull);
  });

  test('Mersenne primes', () {
    for (final n in ['3', '7', '31', '127', '8191', '2147483647']) {
      expect(t(n), Trivia.mersenne, reason: n);
    }
    expect(t('15'), isNull); // 2^4 - 1 は合成数
    expect(t('63'), isNull);
  });

  test('Fermat primes', () {
    for (final n in ['5', '17', '257', '65537']) {
      expect(t(n), Trivia.fermat, reason: n);
    }
  });

  test('palindromic primes', () {
    for (final n in ['11', '101', '131', '10301']) {
      expect(t(n), Trivia.palindromicPrime, reason: n);
    }
    expect(t('121'), isNull); // 回文だが 11^2
  });

  test('twin primes', () {
    for (final n in ['13', '19', '29', '43']) {
      expect(t(n), Trivia.twinPrime, reason: n);
    }
    expect(t('23'), isNull); // 21 も 25 も素数ではない
  });

  test('Ramanujan number', () {
    expect(t('1729'), Trivia.ramanujan);
  });

  test('Grothendieck prime (57) is composite but has its own trivia', () {
    expect(t('57'), Trivia.grothendieck);
    expect(t('56'), isNull);
    expect(t('58'), isNull);
  });

  test('numbers without trivia', () {
    for (final n in ['0', '1', '2', '4', '9', '100', '23']) {
      expect(t(n), isNull, reason: n);
    }
  });
}
