import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prime_fact/history_entry.dart';
import 'package:prime_fact/history_repository.dart';
import 'package:prime_fact/daily_page.dart' show ShareOutcome;
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

  group('drawer links', () {
    Future<List<String>> tapPrivacy(
      WidgetTester tester,
      Future<bool> Function(String) open,
    ) async {
      final opened = <String>[];
      _setLocale(tester, const Locale('en'));
      await tester.pumpWidget(
        MyApp(
          openUrl: (url) {
            opened.add(url);
            return open(url);
          },
        ),
      );
      await tester.pumpAndSettle();
      tester
          .state<ScaffoldState>(
            find.descendant(
              of: find.byType(MyLayout),
              matching: find.byType(Scaffold),
            ),
          )
          .openDrawer();
      await tester.pumpAndSettle();
      await tester.tap(find.text('App Info'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Privacy Policy'));
      await tester.pumpAndSettle();
      return opened;
    }

    testWidgets('opens the link and closes the drawer', (tester) async {
      final opened = await tapPrivacy(tester, (_) async => true);
      expect(opened, hasLength(1));
      expect(find.byType(Drawer), findsNothing);
      expect(find.text('Could not open the link.'), findsNothing);
    });

    for (final failure in <String, Future<bool> Function(String)>{
      'returns false': (_) async => false,
      'throws': (_) => Future.error(StateError('no browser')),
    }.entries) {
      testWidgets('tells the user when opening ${failure.key}', (tester) async {
        await tapPrivacy(tester, failure.value);
        expect(find.byType(Drawer), findsNothing);
        expect(find.text('Could not open the link.'), findsOneWidget);
      });
    }
  });

  testWidgets('A long result wraps at full size', (tester) async {
    _setLocale(tester, const Locale('en'));
    await tester.pumpWidget(MyApp(calculator: (_) async => '${'2x' * 60}2'));
    await tester.pump();

    await tester.enterText(find.byType(TextField), '12');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('result')), findsOneWidget);
    expect(find.byType(FittedBox), findsNothing);
    final height = tester.getSize(find.byKey(const ValueKey('result'))).height;
    expect(height, greaterThan(40)); // 1 行(約 24)に収まらず折り返している
  });

  testWidgets('Copy/share buttons show for a result, and the input stays put', (
    tester,
  ) async {
    _setLocale(tester, const Locale('en'));
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      MyApp(calculator: (_) async => 'RESULT\n${'2x' * 60}2'),
    );
    await tester.pump();
    expect(find.byIcon(Icons.copy), findsNothing);

    final before = tester.getTopLeft(find.byType(TextField));
    await tester.enterText(find.byType(TextField), '12');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    expect(tester.getTopLeft(find.byType(TextField)), before); // 読み込み中
    await tester.pump();
    expect(tester.getTopLeft(find.byType(TextField)), before); // 結果表示後

    expect(find.byIcon(Icons.share), findsOneWidget);
    await tester.tap(find.byIcon(Icons.copy));
    await tester.pump();
    expect(copied, startsWith('RESULT\n'));
    expect(find.text('Copied'), findsOneWidget);
  });

  testWidgets('Line breaks are only allowed before x in the factorization', (
    tester,
  ) async {
    _setLocale(tester, const Locale('en'));
    await tester.pumpWidget(
      MyApp(calculator: (_) async => '60 NP\n60=2^2x3x5'),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), '60');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    await tester.pump();

    final text = tester.widget<Text>(find.byKey(const ValueKey('result')));
    expect(text.data, '60 NP\n60=2^2\u200Bx3\u200Bx5');
  });

  for (final c in [
    (ShareOutcome.copied, 'Copied'),
    (ShareOutcome.sheet, null),
  ]) {
    testWidgets('Share outcome ${c.$1} -> snackbar ${c.$2}', (tester) async {
      _setLocale(tester, const Locale('en'));
      await tester.pumpWidget(
        MyApp(calculator: (_) async => 'R', share: (_, _) async => c.$1),
      );
      await tester.pump();
      await tester.enterText(find.byType(TextField), '12');
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byIcon(Icons.share));
      await tester.pump();
      expect(find.text('Copied'), c.$2 == null ? findsNothing : findsOneWidget);
    });
  }

  testWidgets('A share error is reported (ja), tooltips are localized', (
    tester,
  ) async {
    _setLocale(tester, const Locale('ja'));
    await tester.pumpWidget(
      MyApp(calculator: (_) async => 'R', share: (_, _) async => throw 'x'),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), '12');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    await tester.pump();
    expect(find.byTooltip('コピー'), findsOneWidget);
    expect(find.byTooltip('共有'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.share));
    await tester.pump();
    expect(find.text('共有できませんでした'), findsOneWidget);
  });

  testWidgets('No copy/share buttons after a failed calculation', (
    tester,
  ) async {
    _setLocale(tester, const Locale('en'));
    await tester.pumpWidget(
      MyApp(calculator: (_) async => throw Exception('boom')),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), '12');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    await tester.pump();
    expect(find.text('Calculation failed. Please try again.'), findsOneWidget);
    expect(find.byIcon(Icons.copy), findsNothing);
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
    expect(find.textContaining('57=3\u200Bx19'), findsOneWidget);
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
    expect(find.textContaining('6=2\u200Bx3'), findsOneWidget);
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
