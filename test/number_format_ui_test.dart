import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:prime_fact/app_dependencies.dart';
import 'package:prime_fact/home_page.dart';
import 'package:prime_fact/judge.dart' show CancelToken, FactorRequest;
import 'package:prime_fact/main.dart';
import 'package:prime_fact/share.dart' show ShareOutcome;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  void setLocale(WidgetTester tester, String code) {
    tester.platformDispatcher.localesTestValue = [Locale(code)];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  }

  // 計算結果は固定（整形前の素の数字）。
  Future<String> fakeCalc(FactorRequest r, CancelToken _) async =>
      '${r.n}${r.isNotPrime}\n${r.n}=127x9721';

  Future<void> pump(WidgetTester tester, {List<String>? shared}) async {
    await tester.pumpWidget(
      PrimeFactApp(
        dependencies: AppDependencies(
          calculator: fakeCalc,
          share: (text, _) async {
            shared?.add(text);
            return ShareOutcome.sheet;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openDrawer(WidgetTester tester) async {
    tester
        .state<ScaffoldState>(
          find.descendant(
            of: find.byType(HomePage),
            matching: find.byType(Scaffold),
          ),
        )
        .openDrawer();
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String title, String option) async {
    await openDrawer(tester);
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
    await tester.tap(find.text(option));
    await tester.pumpAndSettle();
    // 選んだ後もドロワーは開いたまま。計算できるよう閉じる
    expect(find.byType(Drawer), findsOneWidget);
    tester
        .state<ScaffoldState>(
          find.descendant(
            of: find.byType(HomePage),
            matching: find.byType(Scaffold),
          ),
        )
        .closeDrawer();
    await tester.pumpAndSettle();
  }

  Future<void> calculate(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField), '1234567');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();
  }

  String resultText(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const ValueKey('result'))).data!;

  testWidgets('comma style changes the result and the share text (en)', (
    tester,
  ) async {
    setLocale(tester, 'en');
    final shared = <String>[];
    await pump(tester, shared: shared);
    await choose(tester, 'Number format', 'Commas (1,234,567)');

    await calculate(tester);
    expect(resultText(tester), contains('1,234,567 is not a prime number'));
    expect(resultText(tester), contains('1,234,567='));

    await tester.tap(find.byTooltip('Share'));
    await tester.pumpAndSettle();
    expect(shared.single, contains('1,234,567='));
  });

  testWidgets('apostrophe style changes the result (en)', (tester) async {
    setLocale(tester, 'en');
    await pump(tester);
    await choose(tester, 'Number format', "Apostrophes (1'234'567)");

    await calculate(tester);
    expect(resultText(tester), contains("1'234'567 is not a prime number"));
  });

  testWidgets(
    'the clear button is enabled only when there is something to clear '
    'and clears the input and the result',
    (tester) async {
      setLocale(tester, 'en');
      await pump(tester);
      Finder clear() => find.widgetWithText(OutlinedButton, 'Clear');
      bool enabled() =>
          tester.widget<OutlinedButton>(clear()).onPressed != null;

      expect(enabled(), isFalse);
      await tester.enterText(find.byType(TextField), '123');
      await tester.pump();
      expect(enabled(), isTrue);

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      expect(resultText(tester), isNotEmpty);

      await tester.tap(clear());
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(resultText(tester), isEmpty);
      expect(enabled(), isFalse);
    },
  );

  testWidgets('the clear button also clears an error shown with empty input', (
    tester,
  ) async {
    setLocale(tester, 'en');
    await pump(tester);
    Finder clear() => find.widgetWithText(OutlinedButton, 'Clear');

    // 空のまま判定するとエラーだけが残る（入力も結果も空）
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();
    expect(find.text('Please enter a number'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(clear()).onPressed, isNotNull);

    await tester.tap(clear());
    await tester.pump();
    expect(find.text('Please enter a number'), findsNothing);
    expect(tester.widget<OutlinedButton>(clear()).onPressed, isNull);
  });

  testWidgets('clear button label in Japanese', (tester) async {
    setLocale(tester, 'ja');
    await pump(tester);
    expect(find.widgetWithText(OutlinedButton, 'クリア'), findsOneWidget);
  });

  testWidgets('the apostrophe style is applied to history too (ja)', (
    tester,
  ) async {
    setLocale(tester, 'ja');
    await pump(tester);
    await choose(tester, '数の表示形式', "アポストロフィ区切り（1'234'567）");
    await calculate(tester);
    expect(resultText(tester), contains("1'234'567"));

    await openDrawer(tester);
    await tester.tap(find.text('履歴'));
    await tester.pumpAndSettle();
    expect(find.textContaining("1'234'567"), findsWidgets);
  });

  testWidgets('units style in Japanese changes the result and history', (
    tester,
  ) async {
    setLocale(tester, 'ja');
    await pump(tester);
    await choose(tester, '数の表示形式', '単位つき（123万4567）');

    await calculate(tester);
    expect(resultText(tester), contains('123万4567'));

    await openDrawer(tester);
    await tester.tap(find.text('履歴'));
    await tester.pumpAndSettle();
    expect(find.textContaining('123万4567'), findsWidgets);
  });

  testWidgets('the style is applied to history too (comma)', (tester) async {
    setLocale(tester, 'en');
    await pump(tester);
    await choose(tester, 'Number format', 'Commas (1,234,567)');
    await calculate(tester);

    await openDrawer(tester);
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1,234,567'), findsWidgets);
  });

  testWidgets('English offers no units option', (tester) async {
    setLocale(tester, 'en');
    await pump(tester);
    await openDrawer(tester);
    await tester.tap(find.text('Number format'));
    await tester.pumpAndSettle();
    final dialog = find.byType(SimpleDialog);
    expect(
      find.descendant(of: dialog, matching: find.text('Plain (1234567)')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('Commas (1,234,567)')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.textContaining('Units')),
      findsNothing,
    );
  });

  testWidgets('a saved units style is shown as plain in English', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'number_style': 'units'});
    setLocale(tester, 'en');
    await pump(tester);
    await calculate(tester);
    expect(resultText(tester), contains('1234567 is not a prime number'));
  });
}
