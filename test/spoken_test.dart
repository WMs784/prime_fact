import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:prime_fact/app/app_dependencies.dart';
import 'package:prime_fact/calculator/calculator_form.dart';
import 'package:prime_fact/calculator/factorization.dart';
import 'package:prime_fact/calculator/trivia.dart';
import 'package:prime_fact/format/number_style.dart';
import 'package:prime_fact/format/spoken.dart';
import 'package:prime_fact/history/history_entry.dart';
import 'package:prime_fact/history/history_page.dart';
import 'package:prime_fact/l10n/app_localizations_en.dart';
import 'package:prime_fact/l10n/app_localizations_ja.dart';
import 'package:prime_fact/main.dart';
import 'package:prime_fact/shared/share.dart';

import 'helpers/factorization.dart';
import 'helpers/localized_app.dart';

void main() {
  final ja = AppLocalizationsJa();
  final en = AppLocalizationsEn();

  group('spokenResult', () {
    test('reads the factorization in words (ja)', () {
      expect(
        spokenResult(ja, fact('60', '2^2x3x5'), null),
        '60は素数ではありません。60は2の2乗かける3かける5',
      );
    });

    test('reads the factorization in words (en)', () {
      expect(
        spokenResult(en, fact('60', '2^2x3x5'), null),
        '60 is not a prime number. 60 equals 2 to the power of 2 times 3 times 5',
      );
    });

    test('handles a single prime power and a two-prime product', () {
      expect(spokenResult(ja, fact('8', '2^3'), null), '8は素数ではありません。8は2の3乗');
      expect(
        spokenResult(ja, fact('10', '2x5'), null),
        '10は素数ではありません。10は2かける5',
      );
    });

    test('a prime and numbers below 2 are read as the header only', () {
      expect(spokenResult(ja, fact('7'), null), '7は素数です！');
      expect(spokenResult(ja, fact('1'), null), '1は素数ではありません');
    });

    test('uses the trivia header', () {
      expect(
        spokenResult(ja, fact('6', '2x3'), Trivia.perfect),
        '6${ja.isPerfectNumber}。6は2かける3',
      );
    });

    test(
      'keeps 30-digit numbers and multi-digit exponents as plain digits',
      () {
        const n = '123456789012345678901234567890';
        expect(
          spokenResult(en, fact(n, '2^10x3'), null),
          '$n is not a prime number. $n equals 2 to the power of 10 times 3',
        );
      },
    );

    test(
      'contains no symbols or zero-width spaces that a reader would trip on',
      () {
        final spoken = spokenResult(en, fact('60', '2^2x3x5'), null);
        expect(spoken, isNot(contains('^')));
        expect(spoken, isNot(contains('x')));
        expect(spoken, isNot(contains('=')));
        expect(spoken, isNot(contains('\u200B')));
      },
    );

    test('units style is read with units in Japanese only', () {
      const units = NumberStyle.units;
      expect(
        spokenResult(ja, fact('12345', '3x5x823'), null, numberStyle: units),
        '1万2345は素数ではありません。1万2345は3かける5かける823',
      );
      // 底も単位つきにし、指数は整形しない
      expect(
        spokenResult(
          ja,
          fact('100000000', '2^8x5^8'),
          null,
          numberStyle: units,
        ),
        '1億は素数ではありません。1億は2の8乗かける5の8乗',
      );
      expect(
        spokenResult(ja, fact('20000', '10000^2x2'), null, numberStyle: units),
        '2万は素数ではありません。2万は1万の2乗かける2',
      );
      // 素数など因数分解の行がないときも、数は単位つきで読む
      expect(
        spokenResult(ja, fact('10007'), null, numberStyle: units),
        '1万7は素数です！',
      );
      // 英語では単位つきは使わない
      expect(
        spokenResult(en, fact('12345', '3x5x823'), null, numberStyle: units),
        '12345 is not a prime number. 12345 equals 3 times 5 times 823',
      );
    });

    test('comma and apostrophe styles are not applied to the spoken text', () {
      for (final style in [NumberStyle.comma, NumberStyle.apostrophe]) {
        expect(
          spokenResult(ja, fact('12345', '3x5x823'), null, numberStyle: style),
          '12345は素数ではありません。12345は3かける5かける823',
        );
      }
    });
  });

  group('screen reader semantics', () {
    testWidgets('the result is a live region read in words (en)', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      tester.platformDispatcher.localesTestValue = [const Locale('en')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await tester.pumpWidget(
        PrimeFactApp(
          dependencies: AppDependencies(
            calculator: (_, _) async => fact('60', '2^2x3x5'),
          ),
        ),
      );
      await tester.pump();
      await tester.enterText(find.byType(TextField), '60');
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      await tester.pump();

      final node = tester.getSemantics(find.byKey(const ValueKey('result')));
      expect(
        node.label,
        '60 is not a prime number. 60 equals 2 to the power of 2 times 3 times 5',
      );
      expect(node.flagsCollection.isLiveRegion, isTrue);
      // 画面の表示（折り返し用の不可視文字を含む）は変わらない
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('result'))).data,
        '60 is not a prime number\n60=\u200B2^2\u200Bx3\u200Bx5',
      );
      handle.dispose();
    });

    testWidgets('the result ignores the number format (apostrophes)', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      tester.platformDispatcher.localesTestValue = [const Locale('ja')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await tester.pumpWidget(
        localizedApp(
          Scaffold(
            body: CalculatorForm(
              calculator: (_, _) async => fact('12345', '3x5x823'),
              share: (_, _) async => ShareOutcome.sheet,
              now: DateTime.now,
              numberStyle: NumberStyle.apostrophe,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.enterText(find.byType(TextField), '12345');
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      await tester.pump();

      expect(
        tester.widget<Text>(find.byKey(const ValueKey('result'))).data,
        contains("12'345"),
      );
      expect(
        tester.getSemantics(find.byKey(const ValueKey('result'))).label,
        '12345は素数ではありません。12345は3かける5かける823',
      );
      handle.dispose();
    });

    testWidgets('the result includes units in units style (ja)', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      tester.platformDispatcher.localesTestValue = [const Locale('ja')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await tester.pumpWidget(
        localizedApp(
          Scaffold(
            body: CalculatorForm(
              calculator: (_, _) async => fact('12345', '3x5x823'),
              share: (_, _) async => ShareOutcome.sheet,
              now: DateTime.now,
              numberStyle: NumberStyle.units,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.enterText(find.byType(TextField), '12345');
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      await tester.pump();

      expect(
        tester.getSemantics(find.byKey(const ValueKey('result'))).label,
        '1万2345は素数ではありません。1万2345は3かける5かける823',
      );
      handle.dispose();
    });

    testWidgets('the progress indicator says it is calculating (ja)', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      tester.platformDispatcher.localesTestValue = [const Locale('ja')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await tester.pumpWidget(
        PrimeFactApp(
          dependencies: AppDependencies(
            calculator: (_, _) => Completer<Factorization>().future,
          ),
        ),
      );
      await tester.pump();
      await tester.enterText(find.byType(TextField), '60');
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(
        tester.getSemantics(find.byType(CircularProgressIndicator)).label,
        '計算中',
      );
      // 後始末: 中止して未完了の Future を残さない
      await tester.tap(find.text('中止'));
      await tester.pump();
      handle.dispose();
    });

    testWidgets('a history row is read in words with its date (en)', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      tester.platformDispatcher.localesTestValue = [const Locale('en')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await tester.pumpWidget(
        localizedApp(
          HistoryPage(
            history: [
              HistoryEntry.parse(
                input: '60',
                factors: '2^2x3x5',
                timestamp: DateTime(2026, 11, 17, 9, 5),
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(
        find.bySemanticsLabel(
          RegExp(
            r'^60 is not a prime number\. 60 equals 2 to the power of 2 times 3 times 5\. ',
          ),
        ),
        findsOneWidget,
      );
      handle.dispose();
    });
  });
}
