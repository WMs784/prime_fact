import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prime_fact/main.dart';

void main() {
  testWidgets('App renders calculator UI', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);
  });

  testWidgets('Input field rejects non-numeric input', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    final field = find.byType(TextField);
    await tester.enterText(field, 'abc');
    await tester.pump();

    final tf = tester.widget<TextField>(field);
    expect(tf.controller?.text ?? '', isEmpty);
  });

  testWidgets('Empty input shows a localized error (ja)', (tester) async {
    _setLocale(tester, const Locale('ja'));
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    expect(find.text('数値を入力してください'), findsOneWidget);

    // 入力を始めるとエラーは消える
    await tester.enterText(find.byType(TextField), '1');
    await tester.pump();
    expect(find.text('数値を入力してください'), findsNothing);
  });

  testWidgets('Zero is judged as not prime (en)', (tester) async {
    _setLocale(tester, const Locale('en'));
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '0');
    await tester.tap(find.byType(ElevatedButton));
    // compute() は実 isolate で動くため、実時間で完了を待つ
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();
    expect(find.text('0 is not a prime number'), findsOneWidget);
  });
}

void _setLocale(WidgetTester tester, Locale locale) {
  tester.platformDispatcher.localesTestValue = [locale];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
}
