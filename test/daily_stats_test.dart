import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prime_fact/daily_progress.dart';
import 'package:prime_fact/daily_puzzle.dart';
import 'package:prime_fact/daily_records_page.dart';
import 'package:prime_fact/daily_repository.dart';
import 'package:prime_fact/daily_stats.dart';
import 'package:prime_fact/l10n/app_localizations.dart';
import 'package:prime_fact/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _t0 = DateTime.utc(2026, 1, 1);

DailyProgress _cleared({int wrong = 0, int millis = 5000}) => DailyProgress(
  startedAt: _t0,
  wrong: wrong,
  clearedAt: _t0.add(Duration(milliseconds: millis)),
);

DailyProgress _open() => DailyProgress(startedAt: _t0);

void main() {
  group('DailyStats.compute', () {
    test('empty', () {
      final s = DailyStats.compute({}, 20261031);
      expect(s.cleared, 0);
      expect(s.noMiss, 0);
      expect(s.currentStreak, 0);
      expect(s.bestStreak, 0);
      expect(s.bestTime, isNull);
    });

    test('streak through today when today is cleared', () {
      final s = DailyStats.compute({
        20261029: _cleared(),
        20261030: _cleared(),
        20261031: _cleared(),
      }, 20261031);
      expect(s.currentStreak, 3);
      expect(s.bestStreak, 3);
    });

    test('streak stays alive through yesterday when today is not cleared', () {
      final records = {20261029: _cleared(), 20261030: _cleared()};
      expect(DailyStats.compute(records, 20261031).currentStreak, 2);
      records[20261031] = _open();
      expect(DailyStats.compute(records, 20261031).currentStreak, 2);
    });

    test('streak is broken by a missed day', () {
      final s = DailyStats.compute({
        20261028: _cleared(),
        20261029: _cleared(),
        // 30 日は未プレイ
        20261031: _cleared(),
      }, 20261031);
      expect(s.currentStreak, 1);
      expect(s.bestStreak, 2);
    });

    test('streak is 0 when neither today nor yesterday is cleared', () {
      final s = DailyStats.compute({
        20261028: _cleared(),
        20261029: _cleared(),
      }, 20261031);
      expect(s.currentStreak, 0);
      expect(s.bestStreak, 2);
    });

    test('an unfinished day breaks the streak', () {
      final s = DailyStats.compute({
        20261029: _cleared(),
        20261030: _open(),
        20261031: _cleared(),
      }, 20261031);
      expect(s.currentStreak, 1);
      expect(s.bestStreak, 1);
      expect(s.cleared, 2);
    });

    test('streak crosses month and year boundaries', () {
      final s = DailyStats.compute({
        20251230: _cleared(),
        20251231: _cleared(),
        20260101: _cleared(),
        20260228: _cleared(),
        20260301: _cleared(),
      }, 20260301);
      expect(s.bestStreak, 3);
      expect(s.currentStreak, 2);
      // うるう年
      final leap = DailyStats.compute({
        20280228: _cleared(),
        20280229: _cleared(),
        20280301: _cleared(),
      }, 20280301);
      expect(leap.currentStreak, 3);
    });

    test('no-miss count and best time ignore uncleared and zero times', () {
      final s = DailyStats.compute({
        20261029: _cleared(wrong: 1, millis: 3000),
        20261030: _cleared(millis: 7000),
        20261031: _cleared(millis: 0), // 時計の変更で 0 になった記録
        20261101: _open(),
      }, 20261101);
      expect(s.cleared, 3);
      expect(s.noMiss, 2);
      expect(s.bestTime, const Duration(seconds: 3));
    });
  });

  group('DailyRepository.loadAll', () {
    test('returns every day, skipping corrupted and unrelated keys', () async {
      SharedPreferences.setMockInitialValues({
        'daily_20261030':
            '{"startedAt":${_t0.millisecondsSinceEpoch},"wrong":1,"clearedAt":null}',
        'daily_20261031': 'not json',
        'daily_20261101': 12345,
        'daily_x': '{}',
        'history': '[]',
      });
      final repo = DailyRepository();
      await repo.save(20261102, _cleared());
      final all = await repo.loadAll();
      expect(all.keys.toSet(), {20261030, 20261102});
      expect(all[20261030]!.wrong, 1);
      expect(all[20261102]!.isCleared, isTrue);
    });
  });

  group('UI', () {
    final now = DateTime.utc(2026, 10, 31, 3); // 12:00 JST, 20261031

    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<void> seed(Map<int, DailyProgress> records) async {
      final repo = DailyRepository();
      for (final e in records.entries) {
        await repo.save(e.key, e.value);
      }
    }

    void setLocale(WidgetTester tester, Locale locale) {
      tester.platformDispatcher.localesTestValue = [locale];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    }

    testWidgets('banner shows the streak and opens the records page', (
      tester,
    ) async {
      setLocale(tester, const Locale('ja'));
      await seed({
        20261029: _cleared(),
        20261030: _cleared(wrong: 2, millis: 65300),
        20261031: _cleared(),
      });
      await tester.pumpWidget(MyApp(now: () => now));
      await tester.pumpAndSettle();
      expect(find.text('🔥 3日連続'), findsOneWidget);

      await tester.tap(find.byTooltip('記録'));
      await tester.pumpAndSettle();
      expect(find.text('現在の連続'), findsOneWidget);
      expect(find.text('最長の連続'), findsOneWidget);
      expect(find.text('3日'), findsNWidgets(3)); // 現在・最長・クリア日数
      expect(find.text('2026-10-30'), findsOneWidget);
      expect(find.text('タイム 1:05.3 / ミス 2回'), findsOneWidget);
    });

    testWidgets('banner shows the alive streak before today is cleared', (
      tester,
    ) async {
      setLocale(tester, const Locale('en'));
      await seed({20261030: _cleared()});
      await tester.pumpWidget(MyApp(now: () => now));
      await tester.pumpAndSettle();
      expect(find.text('🔥 1-day streak'), findsOneWidget);
    });

    testWidgets('the result screen shows the streak after a correct answer', (
      tester,
    ) async {
      setLocale(tester, const Locale('ja'));
      await seed({20261029: _cleared(), 20261030: _cleared()});
      await tester.pumpWidget(MyApp(now: () => now));
      await tester.pumpAndSettle();
      await tester.tap(find.text('今日の素因数分解に挑戦する'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      await tester.enterText(
        find.byType(TextField),
        '${DailyPuzzle.forDate(now).p}',
      );
      await tester.tap(find.text('回答する'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text('🔥 3日連続'), findsOneWidget);
    });

    testWidgets('banner hides a one-day streak that is already cleared today', (
      tester,
    ) async {
      setLocale(tester, const Locale('ja'));
      await seed({20261031: _cleared()});
      await tester.pumpWidget(MyApp(now: () => now));
      await tester.pumpAndSettle();
      expect(find.textContaining('日連続'), findsNothing);
    });

    testWidgets('records page: empty, unfinished and in-progress days', (
      tester,
    ) async {
      setLocale(tester, const Locale('ja'));
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DailyRecordsPage(repository: DailyRepository(), now: () => now),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('まだ記録がありません'), findsOneWidget);

      await seed({20261030: _open(), 20261031: _open()});
      await tester.pumpWidget(
        MaterialApp(
          key: UniqueKey(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DailyRecordsPage(repository: DailyRepository(), now: () => now),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('未クリア'), findsOneWidget);
      expect(find.text('挑戦中'), findsOneWidget);
    });

    testWidgets('records page offers a retry when loading fails', (
      tester,
    ) async {
      setLocale(tester, const Locale('ja'));
      final repo = _FailOnceRepo();
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DailyRecordsPage(repository: repo, now: () => now),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('記録を読み込めませんでした'), findsOneWidget);
      await tester.tap(find.text('再試行'));
      await tester.pumpAndSettle();
      expect(find.text('まだ記録がありません'), findsOneWidget);
    });
  });
}

class _FailOnceRepo extends DailyRepository {
  bool _failed = false;

  @override
  Future<Map<int, DailyProgress>> loadAll() async {
    if (!_failed) {
      _failed = true;
      throw Exception('load');
    }
    return {};
  }
}
