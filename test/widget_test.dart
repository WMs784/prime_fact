import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:prime_fact/app/app_dependencies.dart';
import 'package:prime_fact/app/home_page.dart';
import 'package:prime_fact/calculator/factorization.dart';
import 'package:prime_fact/calculator/judge.dart'
    show CancelToken, CancelledException;
import 'package:prime_fact/history/history_entry.dart';
import 'package:prime_fact/history/history_repository.dart';
import 'package:prime_fact/main.dart';
import 'package:prime_fact/shared/share.dart' show ShareOutcome;

import 'helpers/factorization.dart';

/// 1 行に収まらない、長い因数分解（2 を 61 個）。
final String _manyTwos = List.filled(61, '2').join('x');

void main() {
  testWidgets('App renders calculator UI', (tester) async {
    await tester.pumpWidget(PrimeFactApp());
    await tester.pump();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);
  });

  testWidgets('Input field rejects non-numeric input', (tester) async {
    await tester.pumpWidget(PrimeFactApp());
    await tester.pump();

    final field = find.byType(TextField);
    await tester.enterText(field, 'abc');
    await tester.pump();

    final tf = tester.widget<TextField>(field);
    expect(tf.controller?.text ?? '', isEmpty);
  });

  testWidgets('Empty input shows a localized error (ja)', (tester) async {
    _setLocale(tester, const Locale('ja'));
    await tester.pumpWidget(PrimeFactApp());
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
    await tester.pumpWidget(PrimeFactApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '0');
    await tester.tap(find.byType(ElevatedButton));
    // compute() は実 isolate で動くため、実時間で完了を待つ
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();
    expect(find.text('0 is not a prime number'), findsOneWidget);
  });

  testWidgets('Enter key on the keyboard starts the calculation', (
    tester,
  ) async {
    _setLocale(tester, const Locale('en'));
    await tester.pumpWidget(PrimeFactApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '0');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
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
    await tester.pumpWidget(
      PrimeFactApp(dependencies: AppDependencies(historyRepository: repo)),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), '0');
    await tester.tap(find.byType(ElevatedButton));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();
    // 読み込みが終わるまでは保存しない
    expect(repo.saved, isEmpty);

    loading.complete([
      HistoryEntry.parse(input: '7', timestamp: DateTime.utc(2026)),
    ]);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();

    expect(repo.saved.last.map((e) => e.input), ['7', '0']);
  });

  testWidgets('History records the time from the injected clock', (
    tester,
  ) async {
    final repo = _FakeHistoryRepository(() async => []);
    final t0 = DateTime(2026, 11, 21, 9, 30);
    _setLocale(tester, const Locale('en'));
    await tester.pumpWidget(
      PrimeFactApp(
        dependencies: AppDependencies(
          historyRepository: repo,
          now: () => t0,
          calculator: (_, _) async => fact('7'),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), '7');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    await tester.pump();

    expect(repo.saved.last.single.timestamp, t0);
  });

  testWidgets('History is not saved when loading it failed', (tester) async {
    final repo = _FakeHistoryRepository(
      () => Future.error(StateError('storage unavailable')),
    );
    _setLocale(tester, const Locale('en'));
    await tester.pumpWidget(
      PrimeFactApp(dependencies: AppDependencies(historyRepository: repo)),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), '0');
    await tester.tap(find.byType(ElevatedButton));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();

    expect(find.text('0 is not a prime number'), findsOneWidget);
    expect(repo.saved, isEmpty);
  });

  for (final ignoresCancel in [false, true]) {
    testWidgets(
      'Cancelling a calculation keeps the previous result and saves no history'
      '${ignoresCancel ? ' (even if the calculator still returns a result)' : ''}',
      (tester) async {
        final repo = _FakeHistoryRepository(() async => []);
        _setLocale(tester, const Locale('en'));
        final done = Completer<Factorization>();
        CancelToken? token;
        var calls = 0;
        await tester.pumpWidget(
          PrimeFactApp(
            dependencies: AppDependencies(
              historyRepository: repo,
              calculator: (_, cancel) {
                // 1 回目はすぐ結果を返し、2 回目は止めて待つ
                if (++calls == 1) return Future.value(fact('10', '2x5'));
                token = cancel;
                return done.future;
              },
            ),
          ),
        );
        await tester.pump();

        await tester.enterText(find.byType(TextField), '10');
        await tester.tap(find.byType(ElevatedButton));
        await tester.pump();
        await tester.pump();
        expect(find.textContaining('10=\u200B2'), findsOneWidget);
        expect(repo.saved, hasLength(1));

        await tester.enterText(find.byType(TextField), '12');
        await tester.tap(find.byType(ElevatedButton));
        await tester.pump();

        // 計算中は中止ボタンが出て、計算ボタンは押せない
        expect(find.text('Cancel'), findsOneWidget);
        expect(
          tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
          isNull,
        );

        await tester.tap(find.text('Cancel'));
        expect(token!.isCancelled, isTrue);
        if (ignoresCancel) {
          done.complete(fact('12', '2^2x3'));
        } else {
          done.completeError(const CancelledException());
        }
        await tester.pump();
        await tester.pump();

        expect(find.text('Cancel'), findsNothing);
        expect(find.textContaining('12='), findsNothing);
        // 中止しても、直前の結果は残る
        expect(find.textContaining('10=\u200B2'), findsOneWidget);
        expect(
          find.text('Calculation failed. Please try again.'),
          findsNothing,
        );
        expect(
          tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
          isNotNull,
        );
        expect(repo.saved, hasLength(1));
      },
    );
  }

  testWidgets('A failed calculation shows an error and re-enables the button', (
    tester,
  ) async {
    final repo = _FakeHistoryRepository(() async => []);
    _setLocale(tester, const Locale('en'));
    await tester.pumpWidget(
      PrimeFactApp(
        dependencies: AppDependencies(
          historyRepository: repo,
          calculator: (_, _) => Future.error(StateError('boom')),
        ),
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
        PrimeFactApp(
          dependencies: AppDependencies(
            openUrl: (url) {
              opened.add(url);
              return open(url);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      tester
          .state<ScaffoldState>(
            find.descendant(
              of: find.byType(HomePage),
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
    await tester.pumpWidget(
      PrimeFactApp(
        dependencies: AppDependencies(
          calculator: (_, _) async => fact('12', _manyTwos),
        ),
      ),
    );
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
      PrimeFactApp(
        dependencies: AppDependencies(
          calculator: (_, _) async => fact('12', _manyTwos),
        ),
      ),
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
    expect(copied, startsWith('12 is not a prime number\n12=2x2x'));
    // 折り返し用の不可視文字はコピーに混ぜない
    expect(copied, isNot(contains('\u200B')));
    expect(find.text('Copied'), findsOneWidget);
  });

  testWidgets('A shown result follows a language change', (tester) async {
    _setLocale(tester, const Locale('en'));
    await tester.pumpWidget(
      PrimeFactApp(
        dependencies: AppDependencies(
          calculator: (_, _) async => fact('12', '2^2x3'),
        ),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), '12');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('12 is not a prime number'), findsOneWidget);

    // 計算し直さなくても、表示中の結果が新しい言語で出る
    tester.platformDispatcher.localesTestValue = [const Locale('ja')];
    await tester.pumpAndSettle();
    expect(find.textContaining('12は素数ではありません'), findsOneWidget);
    expect(find.textContaining('12 is not a prime number'), findsNothing);
  });

  testWidgets(
    'Line breaks are only allowed after = and before x in the factorization',
    (tester) async {
      _setLocale(tester, const Locale('en'));
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

      final text = tester.widget<Text>(find.byKey(const ValueKey('result')));
      expect(
        text.data,
        '60 is not a prime number\n60=\u200B2^2\u200Bx3\u200Bx5',
      );
    },
  );

  // flutter test のフォント(Ahem)は全角 20dp 幅。実機の 360dp(20sp の数字で約 29 文字)に
  // 近い状況は、32 文字(30 桁の n と「=」に少し余裕を足した幅)にすると再現できる。
  for (final n in ['9999999999994400000000000783', '9' * 30]) {
    testWidgets(
      'A ${n.length}-digit n is never split mid-number on a narrow screen',
      (tester) async {
        _setLocale(tester, const Locale('en'));
        const charWidth = 20.0;
        // 結果欄の左右の余白(CalculatorForm の horizontal: 12 × 2)。余白を変えたらここも直す
        const sidePadding = 24.0;
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(
          32 * charWidth + sidePadding,
          2400,
        );
        addTearDown(tester.view.reset);

        final result = fact(n, '99999999999971x99999999999973');
        await tester.pumpWidget(
          PrimeFactApp(
            dependencies: AppDependencies(calculator: (_, _) async => result),
          ),
        );
        await tester.pump();
        await tester.enterText(find.byType(TextField), '12');
        await tester.tap(find.byType(ElevatedButton));
        await tester.pump();
        await tester.pump();

        // semanticsLabel を付けた Text は Semantics で包まれるので、中の段落を探す
        final p = tester.renderObject<RenderParagraph>(
          find.descendant(
            of: find.byKey(const ValueKey('result')),
            matching: find.byType(RichText),
          ),
        );
        final text = p.text.toPlainText();
        final factorLine = text.indexOf('\n') + 1;
        var lastTop = -1.0;
        var lines = 0;
        for (var i = factorLine; i < text.length; i++) {
          final boxes = p.getBoxesForSelection(
            TextSelection(baseOffset: i, extentOffset: i + 1),
          );
          if (boxes.isEmpty || text[i] == '\u200B') continue;
          if (boxes.first.top == lastTop) continue;
          lastTop = boxes.first.top;
          lines++;
          if (lines == 1) continue;
          // 行頭は「x」か、「=」の直後でなければならない（数字の途中ではない）
          final prev = text.substring(0, i).replaceAll('\u200B', '');
          expect(
            text[i] == 'x' || prev.endsWith('='),
            isTrue,
            reason: 'line $lines starts mid-number at ${text.substring(i)}',
          );
        }
        expect(lines, greaterThan(1));
      },
    );
  }

  for (final c in [
    (ShareOutcome.copied, 'Copied'),
    (ShareOutcome.sheet, null),
  ]) {
    testWidgets('Share outcome ${c.$1} -> snackbar ${c.$2}', (tester) async {
      _setLocale(tester, const Locale('en'));
      await tester.pumpWidget(
        PrimeFactApp(
          dependencies: AppDependencies(
            calculator: (_, _) async => fact('12', '2^2x3'),
            share: (_, _) async => c.$1,
          ),
        ),
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
      PrimeFactApp(
        dependencies: AppDependencies(
          calculator: (_, _) async => fact('12', '2^2x3'),
          share: (_, _) async => throw 'x',
        ),
      ),
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
      PrimeFactApp(
        dependencies: AppDependencies(
          calculator: (_, _) async => throw Exception('boom'),
        ),
      ),
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
    await tester.pumpWidget(PrimeFactApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '57');
    await tester.tap(find.byType(ElevatedButton));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();
    expect(find.textContaining('57は素数です！ by グロタンディーク'), findsOneWidget);
    expect(find.textContaining('57=\u200B3\u200Bx19'), findsOneWidget);
  });

  testWidgets('Special numbers get their own header (en)', (tester) async {
    Future<void> calc(String n) async {
      await tester.enterText(find.byType(TextField), n);
      await tester.tap(find.byType(ElevatedButton));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
      await tester.pump();
    }

    _setLocale(tester, const Locale('en'));
    await tester.pumpWidget(PrimeFactApp());
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
    await tester.pumpWidget(PrimeFactApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '6');
    await tester.tap(find.byType(ElevatedButton));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();
    expect(find.textContaining('6は素数、ではなく完全数です！'), findsOneWidget);
    expect(find.textContaining('6=\u200B2\u200Bx3'), findsOneWidget);
  });
}

void _setLocale(WidgetTester tester, Locale locale) {
  tester.platformDispatcher.localesTestValue = [locale];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
}

class _FakeHistoryRepository extends HistoryRepository {
  new(this._load);
  final Future<List<HistoryEntry>> Function() _load;
  final saved = <List<HistoryEntry>>[];

  @override
  Future<List<HistoryEntry>> load() => _load();

  @override
  Future<void> save(List<HistoryEntry> history) async {
    saved.add(List.of(history));
  }
}
