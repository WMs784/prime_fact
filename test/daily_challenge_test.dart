import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prime_fact/daily_page.dart';
import 'package:prime_fact/daily_progress.dart';
import 'package:prime_fact/l10n/app_localizations_en.dart';
import 'package:prime_fact/l10n/app_localizations_ja.dart';
import 'package:prime_fact/daily_puzzle.dart';
import 'package:prime_fact/daily_repository.dart';
import 'package:prime_fact/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _day = DateTime.utc(2026, 10, 31, 3); // 12:00 JST
final _puzzle = DailyPuzzle.forDate(_day);

void _setLocale(WidgetTester tester, Locale locale) {
  tester.platformDispatcher.localesTestValue = [locale];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
}

Future<void> _openChallenge(
  WidgetTester tester,
  DateTime Function() now,
) async {
  await tester.pumpWidget(MyApp(now: now));
  await tester.pumpAndSettle();
  await tester.tap(find.text('今日の素因数分解に挑戦する'));
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('banner opens the puzzle and a correct answer shows the result', (
    tester,
  ) async {
    _setLocale(tester, const Locale('ja'));
    var now = _day;
    await tester.pumpWidget(MyApp(now: () => now));
    await tester.pumpAndSettle();
    expect(find.text('今日の素因数分解に挑戦する'), findsOneWidget);

    await tester.tap(find.text('今日の素因数分解に挑戦する'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('${_puzzle.n}'), findsOneWidget);

    now = _day.add(const Duration(seconds: 12, milliseconds: 300));
    await tester.enterText(find.byType(TextField), '${_puzzle.p}');
    // 入力だけでは判定されない
    await tester.pump();
    expect(find.text('回答する'), findsOneWidget);
    await tester.tap(find.text('回答する'));
    await tester.pump();
    await tester.pump();

    expect(find.text('正解！最小の素因数は${_puzzle.p}です'), findsOneWidget);
    expect(find.text('タイム 0:12.3 / ミス 0回'), findsOneWidget);

    // 結果画面からホームに戻れる。バナーはクリア済み表示になる
    await tester.tap(find.text('ホームに戻る'));
    await tester.pumpAndSettle();
    expect(find.text('今日の挑戦はクリア済み'), findsOneWidget);
    expect(find.text('タイム 0:12.3 / ミス 0回'), findsOneWidget);
  });

  testWidgets('every wrong answer counts as a miss, including 1 and 3', (
    tester,
  ) async {
    _setLocale(tester, const Locale('ja'));
    await _openChallenge(tester, () => _day);

    for (final wrong in ['1', '3', '${_puzzle.n}']) {
      await tester.enterText(find.byType(TextField), wrong);
      await tester.tap(find.text('回答する'));
      await tester.pump();
      await tester.pump();
    }
    expect(find.text('ミス: 3回'), findsOneWidget);
    expect(find.text('ちがいます。もう一度！'), findsOneWidget);

    final saved = await DailyRepository().load(20261031);
    expect(saved?.wrong, 3);
  });

  testWidgets('empty answer is not a miss', (tester) async {
    _setLocale(tester, const Locale('ja'));
    await _openChallenge(tester, () => _day);

    await tester.tap(find.text('回答する'));
    await tester.pump();
    expect(find.text('ミス: 0回'), findsOneWidget);
    expect(find.text('数値を入力してください'), findsOneWidget);
  });

  testWidgets('leaving and returning keeps the clock running', (tester) async {
    _setLocale(tester, const Locale('ja'));
    var now = _day;
    await _openChallenge(tester, () => now);
    await tester.enterText(find.byType(TextField), '1');
    await tester.tap(find.text('回答する'));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('ホームに戻る'));
    await tester.pumpAndSettle();
    expect(find.text('続きから挑戦する'), findsOneWidget);

    now = _day.add(const Duration(minutes: 5));
    await tester.tap(find.text('続きから挑戦する'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('経過時間: 5:00.0'), findsOneWidget);
    expect(find.text('ミス: 1回'), findsOneWidget);
  });

  testWidgets('a cleared challenge opens the result without the input', (
    tester,
  ) async {
    _setLocale(tester, const Locale('ja'));
    await DailyRepository().save(
      20261031,
      DailyProgress(
        startedAt: _day,
        wrong: 2,
        clearedAt: _day.add(const Duration(seconds: 12, milliseconds: 300)),
      ),
    );
    await tester.pumpWidget(
      MyApp(now: () => _day.add(const Duration(hours: 1))),
    );
    await tester.pumpAndSettle();
    expect(find.text('今日の挑戦はクリア済み'), findsOneWidget);

    await tester.tap(find.text('今日の挑戦はクリア済み'));
    await tester.pumpAndSettle();
    expect(find.text('タイム 0:12.3 / ミス 2回'), findsOneWidget);
    expect(find.text('結果をシェア'), findsOneWidget);
    expect(find.text('回答する'), findsNothing);
  });

  test(
    'share text contains time and misses but not the number or the answer',
    () {
      final progress = DailyProgress(
        startedAt: _day,
        wrong: 2,
        clearedAt: _day.add(const Duration(seconds: 12, milliseconds: 300)),
      );
      final ja = dailyShareText(AppLocalizationsJa(), 20261031, progress, _day);
      expect(ja, '素因数分解チャレンジ 2026-10-31\n✅ 0:12.3 / ミス2回');
      final en = dailyShareText(AppLocalizationsEn(), 20261031, progress, _day);
      expect(
        en,
        'Prime Factorization Challenge 2026-10-31\n✅ 0:12.3 / Misses 2',
      );
      for (final text in [ja, en]) {
        expect(text, isNot(contains('${_puzzle.n}')));
      }
    },
  );
}
