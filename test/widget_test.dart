import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prime_fact/history_entry.dart';
import 'package:prime_fact/history_repository.dart';
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

  testWidgets('Enter key on the keyboard starts the calculation', (
    tester,
  ) async {
    _setLocale(tester, const Locale('en'));
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '0');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();
    expect(find.text('0 is not a prime number'), findsOneWidget);
  });

  testWidgets('A calculation made before history loads keeps stored history', (
    tester,
  ) async {
    final loading = Completer<List<HistoryEntry>>();
    final repo = _FakeHistoryRepository(() => loading.future);
    _setLocale(tester, const Locale('en'));
    await tester.pumpWidget(MyApp(historyRepository: repo));
    await tester.pump();

    await tester.enterText(find.byType(TextField), '0');
    await tester.tap(find.byType(ElevatedButton));
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();
    // 読み込みが終わるまでは保存しない
    expect(repo.saved, isEmpty);

    loading.complete([
      HistoryEntry(input: '7', timestamp: DateTime.utc(2026, 1, 1)),
    ]);
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();

    expect(repo.saved.last.map((e) => e.input), ['7', '0']);
  });

  testWidgets('History is not saved when loading it failed', (tester) async {
    final repo = _FakeHistoryRepository(
      () => Future.error(StateError('storage unavailable')),
    );
    _setLocale(tester, const Locale('en'));
    await tester.pumpWidget(MyApp(historyRepository: repo));
    await tester.pump();

    await tester.enterText(find.byType(TextField), '0');
    await tester.tap(find.byType(ElevatedButton));
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();

    expect(find.text('0 is not a prime number'), findsOneWidget);
    expect(repo.saved, isEmpty);
  });

  testWidgets('A failed calculation shows an error and re-enables the button', (
    tester,
  ) async {
    final repo = _FakeHistoryRepository(() async => []);
    _setLocale(tester, const Locale('en'));
    await tester.pumpWidget(
      MyApp(
        historyRepository: repo,
        calculator: (_) => Future.error(StateError('boom')),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), '12');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    await tester.pump();

    expect(find.text('Calculation failed. Please try again.'), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNotNull,
    );
    expect(repo.saved, isEmpty);
  });

  testWidgets('57 is shown as the Grothendieck prime (ja)', (tester) async {
    _setLocale(tester, const Locale('ja'));
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '57');
    await tester.tap(find.byType(ElevatedButton));
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();
    expect(find.textContaining('57は素数です！ by グロタンディーク'), findsOneWidget);
    expect(find.textContaining('57=3x19'), findsOneWidget);
  });

  testWidgets('Special numbers get their own header (en)', (tester) async {
    Future<void> calc(String n) async {
      await tester.enterText(find.byType(TextField), n);
      await tester.tap(find.byType(ElevatedButton));
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 500)),
      );
      await tester.pump();
    }

    _setLocale(tester, const Locale('en'));
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await calc('28');
    expect(
      find.textContaining('28 is not a prime, but a perfect number!'),
      findsOneWidget,
    );
    await calc('7');
    expect(find.text('7 is a Mersenne prime!'), findsOneWidget);
    // 通常の数に戻ると見出しも通常に戻る
    await calc('4');
    expect(find.textContaining('4 is not a prime number'), findsOneWidget);
  });

  testWidgets('Special header in Japanese', (tester) async {
    _setLocale(tester, const Locale('ja'));
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '6');
    await tester.tap(find.byType(ElevatedButton));
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();
    expect(find.textContaining('6は素数、ではなく完全数です！'), findsOneWidget);
    expect(find.textContaining('6=2x3'), findsOneWidget);
  });
}

void _setLocale(WidgetTester tester, Locale locale) {
  tester.platformDispatcher.localesTestValue = [locale];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
}

class _FakeHistoryRepository extends HistoryRepository {
  final Future<List<HistoryEntry>> Function() _load;
  final saved = <List<HistoryEntry>>[];

  _FakeHistoryRepository(this._load);

  @override
  Future<List<HistoryEntry>> load() => _load();

  @override
  Future<void> save(List<HistoryEntry> history) async {
    saved.add(List.of(history));
  }
}
