import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prime_fact/daily_page.dart';
import 'package:prime_fact/daily_progress.dart';
import 'package:prime_fact/daily_puzzle.dart';
import 'package:prime_fact/daily_repository.dart';
import 'package:prime_fact/l10n/app_localizations.dart';
import 'package:prime_fact/main.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _day = DateTime.utc(2026, 10, 31, 3); // 12:00 JST
final _puzzle = DailyPuzzle.forDate(_day);

class _FakeRepo extends DailyRepository {
  bool failLoad = false;
  bool failSave = false;
  Completer<void>? saveGate;
  int saves = 0;
  DailyProgress? stored;

  @override
  Future<DailyProgress?> load(int dateKey) async {
    if (failLoad) throw Exception('load');
    return stored;
  }

  @override
  Future<void> save(int dateKey, DailyProgress progress) async {
    saves++;
    await saveGate?.future;
    if (failSave) throw Exception('save');
    stored = progress;
  }
}

class _NeverLoadRepo extends DailyRepository {
  int loads = 0;

  @override
  Future<DailyProgress?> load(int dateKey) {
    loads++;
    return Completer<DailyProgress?>().future;
  }
}

/// 1 回目の load だけ完了を保留し、2 回目以降はクリア済みを返す。
class _SlowFirstLoadRepo extends DailyRepository {
  final firstLoad = Completer<DailyProgress?>();
  int _calls = 0;

  @override
  Future<DailyProgress?> load(int dateKey) {
    if (_calls++ == 0) return firstLoad.future;
    return Future.value(
      DailyProgress(
        startedAt: _day,
        clearedAt: _day.add(const Duration(seconds: 5)),
      ),
    );
  }
}

/// [result] を返す share。null のときは未実装として [UnimplementedError] を投げる。
Future<ShareResult> Function(ShareParams) _fakeShare(
  ShareResult? result, {
  Object? error,
}) => (_) async {
  if (error != null) throw error;
  return result ?? (throw UnimplementedError());
};

Widget _app(Widget home) => MaterialApp(
  locale: const Locale('ja'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

DailyPage _page(
  _FakeRepo repo, {
  Future<ShareOutcome> Function(String, Rect?)? onShare,
}) => DailyPage(
  puzzle: _puzzle,
  repository: repo,
  now: () => _day,
  onShare: onShare ?? (_, _) async => ShareOutcome.sheet,
);

Future<void> _pumpPage(WidgetTester tester, Widget page) async {
  await tester.pumpWidget(_app(page));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('load failure shows an error with retry instead of a spinner', (
    tester,
  ) async {
    final repo = _FakeRepo()..failLoad = true;
    await _pumpPage(tester, _page(repo));
    expect(find.text('今日の挑戦を読み込めませんでした'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('ホームに戻る'), findsOneWidget);

    repo.failLoad = false;
    await tester.tap(find.text('再試行'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('${_puzzle.n}'), findsOneWidget);
  });

  testWidgets('a failed save is not reflected in the UI', (tester) async {
    final repo = _FakeRepo();
    await _pumpPage(tester, _page(repo));

    repo.failSave = true;
    await tester.enterText(find.byType(TextField), '${_puzzle.p}');
    await tester.tap(find.text('回答する'));
    await tester.pump();
    await tester.pump();

    expect(find.text('保存できませんでした。もう一度お試しください'), findsOneWidget);
    expect(find.text('ミス: 0回'), findsOneWidget);
    expect(find.text('回答する'), findsOneWidget); // クリア扱いにならない
    expect(repo.stored?.isCleared, isFalse);
  });

  testWidgets('answers are ignored while saving (no overlapping saves)', (
    tester,
  ) async {
    final repo = _FakeRepo();
    await _pumpPage(tester, _page(repo));
    final initialSaves = repo.saves;

    final gate = repo.saveGate = Completer<void>();
    await tester.enterText(find.byType(TextField), '1');
    await tester.tap(find.text('回答する'));
    await tester.pump();
    // 保存中はボタンが無効で、Enter でも送信されない
    await tester.tap(find.text('回答する'), warnIfMissed: false);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(repo.saves, initialSaves + 1);

    gate.complete();
    await tester.pump();
    await tester.pump();
    expect(find.text('ミス: 1回'), findsOneWidget);
    expect(repo.stored?.wrong, 1);
  });

  testWidgets('Enter on the keyboard submits the answer', (tester) async {
    final repo = _FakeRepo();
    await _pumpPage(tester, _page(repo));

    await tester.enterText(find.byType(TextField), '1');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump();
    expect(find.text('ミス: 1回'), findsOneWidget);
  });

  testWidgets('the answer field has no character counter', (tester) async {
    await _pumpPage(tester, _page(_FakeRepo()));
    expect(find.text('0/6'), findsNothing);
  });

  group('share', () {
    Future<_FakeRepo> cleared(
      WidgetTester tester,
      Future<ShareOutcome> Function(String, Rect?) onShare,
    ) async {
      final repo = _FakeRepo()
        ..stored = DailyProgress(
          startedAt: _day,
          clearedAt: _day.add(const Duration(seconds: 5)),
        );
      await _pumpPage(tester, _page(repo, onShare: onShare));
      return repo;
    }

    testWidgets('passes the button rect as the share origin', (tester) async {
      Rect? origin;
      await cleared(tester, (_, o) async {
        origin = o;
        return ShareOutcome.sheet;
      });
      await tester.tap(find.text('結果をシェア'));
      await tester.pump();
      expect(origin, isNotNull);
      expect(origin!.isEmpty, isFalse);
    });

    testWidgets('tells the user when the text was copied instead', (
      tester,
    ) async {
      await cleared(tester, (_, _) async => ShareOutcome.copied);
      await tester.tap(find.text('結果をシェア'));
      await tester.pump();
      expect(find.text('クリップボードにコピーしました'), findsOneWidget);
    });

    testWidgets('a real share error is reported, not shown as copied', (
      tester,
    ) async {
      await cleared(tester, (_, _) async => throw PlatformException(code: 'x'));
      await tester.tap(find.text('結果をシェア'));
      await tester.pump();
      expect(find.text('共有できませんでした'), findsOneWidget);
      expect(find.text('クリップボードにコピーしました'), findsNothing);
    });
  });

  group('shareText', () {
    String? copied;

    setUp(() {
      copied = null;
      TestWidgetsFlutterBinding.ensureInitialized();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              copied = (call.arguments as Map)['text'] as String;
            }
            return null;
          });
    });
    tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    test(
      'does not touch the clipboard when the result is unavailable',
      () async {
        final shared = await shareText(
          'hello',
          null,
          share: _fakeShare(ShareResult.unavailable),
        );
        expect(shared, ShareOutcome.sheet);
        expect(copied, isNull);
      },
    );

    test('copies only when there is no share implementation', () async {
      final shared = await shareText('hello', null, share: _fakeShare(null));
      expect(shared, ShareOutcome.copied);
      expect(copied, 'hello');
    });

    test('other errors propagate without copying', () async {
      await expectLater(
        shareText(
          'hello',
          null,
          share: _fakeShare(null, error: PlatformException(code: 'x')),
        ),
        throwsA(isA<PlatformException>()),
      );
      expect(copied, isNull);
    });
  });

  group('banner', () {
    testWidgets('does not flash the start label while loading', (tester) async {
      await tester.pumpWidget(_app(const Scaffold(body: MyLayout())));
      // 読み込み完了前
      expect(find.text('今日の素因数分解に挑戦する'), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('今日の素因数分解に挑戦する'), findsOneWidget);
    });

    testWidgets('refreshes after crossing JST midnight', (tester) async {
      tester.platformDispatcher.localesTestValue = [const Locale('ja')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await DailyRepository().save(
        20261031,
        DailyProgress(
          startedAt: _day,
          clearedAt: _day.add(const Duration(seconds: 5)),
        ),
      );
      var now = _day;
      await tester.pumpWidget(MyApp(now: () => now));
      await tester.pumpAndSettle();
      expect(find.text('今日の挑戦はクリア済み'), findsOneWidget);

      // 日付が変わった状態でアプリに戻ると、前日のクリア表示は消える
      now = DateTime.utc(2026, 10, 31, 15, 0, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('今日の挑戦はクリア済み'), findsNothing);
      expect(find.text('今日の素因数分解に挑戦する'), findsOneWidget);
    });
  });

  testWidgets('the banner notices a date change on its own', (tester) async {
    tester.platformDispatcher.localesTestValue = [const Locale('ja')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await DailyRepository().save(
      20261031,
      DailyProgress(
        startedAt: _day,
        clearedAt: _day.add(const Duration(seconds: 5)),
      ),
    );
    var now = _day;
    await tester.pumpWidget(MyApp(now: () => now));
    await tester.pumpAndSettle();
    expect(find.text('今日の挑戦はクリア済み'), findsOneWidget);

    // 復帰イベントもタイマーの再設定もなく、時計だけが進んだ場合
    now = DateTime.utc(2026, 10, 31, 15, 0, 1);
    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();
    expect(find.text('今日の素因数分解に挑戦する'), findsOneWidget);
  });

  testWidgets('tapping a stale banner refreshes it instead of opening', (
    tester,
  ) async {
    tester.platformDispatcher.localesTestValue = [const Locale('ja')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await DailyRepository().save(
      20261031,
      DailyProgress(
        startedAt: _day,
        clearedAt: _day.add(const Duration(seconds: 5)),
      ),
    );
    var now = _day;
    await tester.pumpWidget(MyApp(now: () => now));
    await tester.pumpAndSettle();

    now = DateTime.utc(2026, 10, 31, 15, 0, 1);
    await tester.tap(find.text('今日の挑戦はクリア済み'));
    await tester.pumpAndSettle();
    expect(find.text('今日の素因数分解に挑戦する'), findsOneWidget);
    expect(find.text('回答する'), findsNothing); // 新しい日の計時は始まっていない
    expect(await DailyRepository().load(20261101), isNull);
  });

  testWidgets('a long-running load is not restarted by the periodic check', (
    tester,
  ) async {
    final repo = _NeverLoadRepo();
    await tester.pumpWidget(MyApp(now: () => _day, dailyRepository: repo));
    await tester.pump(const Duration(seconds: 95));
    expect(repo.loads, 1);
  });

  testWidgets('a slow stale load does not overwrite a newer one', (
    tester,
  ) async {
    tester.platformDispatcher.localesTestValue = [const Locale('ja')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    final repo = _SlowFirstLoadRepo();
    await tester.pumpWidget(MyApp(now: () => _day, dailyRepository: repo));
    await tester.pump();
    // 1 回目の読み込み（未開始）が止まっている間に、2 回目（クリア済み）を始める
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('今日の挑戦はクリア済み'), findsOneWidget);

    repo.firstLoad.complete(null); // 古い結果が遅れて届く
    await tester.pumpAndSettle();
    expect(find.text('今日の挑戦はクリア済み'), findsOneWidget);
  });

  testWidgets('answering after midnight keeps the record on the puzzle day', (
    tester,
  ) async {
    final repo = _FakeRepo();
    var now = _day;
    await _pumpPage(
      tester,
      DailyPage(
        puzzle: _puzzle,
        repository: repo,
        now: () => now,
        onShare: (_, _) async => ShareOutcome.sheet,
      ),
    );
    now = DateTime.utc(2026, 10, 31, 16); // 翌日 01:00 JST
    await tester.enterText(find.byType(TextField), '${_puzzle.p}');
    await tester.tap(find.text('回答する'));
    await tester.pump();
    await tester.pump();
    expect(find.text('2026-10-31'), findsOneWidget);
    expect(repo.stored?.isCleared, isTrue);
  });

  testWidgets('calculator stays usable on a short screen with the keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 480);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    // レイアウトのオーバーフローは例外としてテストを失敗させる
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(TextField).first, '12');
    expect(find.byType(ElevatedButton), findsOneWidget);
  });
}
