import 'package:flutter_test/flutter_test.dart';
import 'package:prime_fact/calculator/factorization.dart';

import 'helpers/factorization.dart';

void main() {
  group('isPrime / isComposite', () {
    test('a prime has a single factor to the first power', () {
      final f = fact('7');
      expect(f.isPrime, isTrue);
      expect(f.isComposite, isFalse);
    });

    test('a prime power is composite, not prime', () {
      final f = fact('4', '2^2');
      expect(f.isPrime, isFalse);
      expect(f.isComposite, isTrue);
    });

    test('a product of distinct primes is composite', () {
      final f = fact('6', '2x3');
      expect(f.isPrime, isFalse);
      expect(f.isComposite, isTrue);
    });

    test('0 and 1 are neither prime nor composite', () {
      for (final n in ['0', '1']) {
        final f = fact(n);
        expect(f.factors, isEmpty, reason: n);
        expect(f.isPrime, isFalse, reason: n);
        expect(f.isComposite, isFalse, reason: n);
      }
    });
  });

  group('notation', () {
    test('writes exponents only when above 1, joined by x', () {
      expect(fact('360', '2^3x3^2x5').notation, '2^3x3^2x5');
      expect(
        Factorization(BigInt.from(12), [
          (prime: BigInt.two, exponent: 2),
          (prime: BigInt.from(3), exponent: 1),
        ]).notation,
        '2^2x3',
      );
      expect(fact('7').notation, '7');
      expect(fact('1').notation, '');
    });
  });

  group('fromNotation', () {
    test('parses bases and exponents', () {
      final f = fact('1000', '2^3x5^3');
      expect(f.n, BigInt.from(1000));
      expect(f.factors, [
        (prime: BigInt.two, exponent: 3),
        (prime: BigInt.from(5), exponent: 3),
      ]);
    });

    test('parses a 30-digit factor and a multi-digit exponent', () {
      final p = '9' * 30;
      expect(fact(p, '${p}x2^10').factors, [
        (prime: BigInt.parse(p), exponent: 1),
        (prime: BigInt.two, exponent: 10),
      ]);
    });

    test('without notation, 2 and above is a prime and below 2 is empty', () {
      expect(fact('2').factors, [(prime: BigInt.two, exponent: 1)]);
      expect(fact('1').factors, isEmpty);
      expect(fact('-7').factors, isEmpty);
    });

    test('round trips through notation', () {
      for (final s in ['2^2x3', '2x3x5x7x11', '1000000007^2']) {
        expect(fact('0', s).notation, s);
      }
    });

    test('rejects a malformed notation', () {
      for (final s in ['', '2x', 'x3', '2^', '2^2^3', '2*3', 'a', ' 2']) {
        expect(() => fact('6', s), throwsFormatException, reason: '"$s"');
      }
    });

    test('the error points at the token that could not be read', () {
      expect(
        () => fact('6', '2x?'),
        throwsA(
          isA<FormatException>()
              .having((e) => e.source, 'source', '?')
              .having((e) => e.message, 'message', 'not a prime power'),
        ),
      );
    });
  });
}
