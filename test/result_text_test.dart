import 'package:flutter_test/flutter_test.dart';
import 'package:prime_fact/calculator/trivia.dart';
import 'package:prime_fact/format/number_style.dart';
import 'package:prime_fact/format/result_text.dart';
import 'package:prime_fact/l10n/app_localizations_en.dart';
import 'package:prime_fact/l10n/app_localizations_ja.dart';

import 'helpers/factorization.dart';

void main() {
  final ja = AppLocalizationsJa();
  final en = AppLocalizationsEn();
  const plain = NumberStyle.plain;

  group('resultHeader', () {
    test('falls back to the plain primality header', () {
      expect(resultHeader(ja, fact('79'), null), ja.isPrime);
      expect(resultHeader(ja, fact('15', '3x5'), null), ja.isNotPrime);
      expect(resultHeader(ja, fact('4', '2^2'), null), ja.isNotPrime);
      expect(resultHeader(ja, fact('1'), null), ja.isNotPrime);
      expect(resultHeader(ja, fact('0'), null), ja.isNotPrime);
    });

    test('trivia replaces the header of a prime and of a composite', () {
      expect(resultHeader(ja, fact('31'), Trivia.mersenne), ja.isMersennePrime);
      expect(
        resultHeader(ja, fact('6', '2x3'), Trivia.perfect),
        ja.isPerfectNumber,
      );
    });
  });

  group('resultLines', () {
    test('a composite has a header and a factorization line', () {
      expect(resultLines(ja, fact('60', '2^2x3x5'), null, plain), [
        '60は素数ではありません',
        '60=2^2x3x5',
      ]);
      expect(resultLines(en, fact('60', '2^2x3x5'), null, plain), [
        '60 is not a prime number',
        '60=2^2x3x5',
      ]);
    });

    test('a prime and numbers below 2 have only the header', () {
      expect(resultLines(en, fact('7'), null, plain), ['7 is a prime number!']);
      expect(resultLines(en, fact('0'), null, plain), [
        '0 is not a prime number',
      ]);
      expect(resultLines(en, fact('-7'), null, plain), [
        '-7 is not a prime number',
      ]);
    });

    test('trivia keeps the factorization of a composite', () {
      expect(resultLines(ja, fact('57', '3x19'), Trivia.grothendieck, plain), [
        '57${ja.isGrothendieckPrime}',
        '57=3x19',
      ]);
    });

    test('the language follows loc, not the time of calculation', () {
      final f = fact('12', '2^2x3');
      expect(resultLines(ja, f, null, plain).first, '12は素数ではありません');
      expect(resultLines(en, f, null, plain).first, '12 is not a prime number');
    });

    test('numbers are styled but exponents are not', () {
      final f = fact('1234567', '1000x2^1234');
      expect(resultLines(en, f, null, NumberStyle.comma), [
        '1,234,567 is not a prime number',
        '1,234,567=1,000x2^1234',
      ]);
      expect(
        resultLines(en, f, null, NumberStyle.apostrophe).last,
        "1'234'567=1'000x2^1234",
      );
      expect(
        resultLines(
          ja,
          fact('20000', '10000^2x2'),
          null,
          NumberStyle.units,
        ).last,
        '2万=1万^2x2',
      );
    });

    test('units are not used in English', () {
      expect(
        resultLines(en, fact('12345', '3x5x823'), null, NumberStyle.units).last,
        '12345=3x5x823',
      );
    });

    test('a negative number keeps its sign in front of the grouping', () {
      expect(resultLines(en, fact('-123456'), null, NumberStyle.comma), [
        '-123,456 is not a prime number',
      ]);
    });

    test('breakable adds break points after = and before x only', () {
      expect(
        resultLines(en, fact('60', '2^2x3x5'), null, plain, breakable: true),
        ['60 is not a prime number', '60=​2^2​x3​x5'],
      );
      // 見出しの行と、因数分解のない結果には入れない
      expect(resultLines(en, fact('7'), null, plain, breakable: true), [
        '7 is a prime number!',
      ]);
    });
  });
}
