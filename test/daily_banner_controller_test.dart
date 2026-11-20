import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:prime_fact/daily/daily_banner_controller.dart';
import 'package:prime_fact/daily/daily_progress.dart';
import 'package:prime_fact/daily/daily_repository.dart';
import 'package:prime_fact/shared/date_key.dart';

class _Repo extends DailyRepository {
  bool failLoad = false;
  bool failLoadAll = false;
  final stored = <int, DailyProgress>{};

  /// 設定すると、その日の [load] はこれを待つ。
  final gates = <int, Completer<void>>{};
  int loads = 0;

  @override
  Future<DailyProgress?> load(int dateKey) async {
    loads++;
    await gates[dateKey]?.future;
    if (failLoad) throw Exception('load');
    return stored[dateKey];
  }

  @override
  Future<Map<int, DailyProgress>> loadAll() async {
    if (failLoadAll) throw Exception('loadAll');
    return Map.of(stored);
  }

  @override
  Future<void> save(int dateKey, DailyProgress progress) async =>
      stored[dateKey] = progress;
}

void main() {
  final t0 = DateTime.utc(2026, 11, 1, 3); // JST 2026-11-01 12:00
  final today = jstDateKey(t0);
  final yesterday = dateKeyOfDayIndex(dayIndexOf(today) - 1);
  final tomorrowUtc = t0.add(const Duration(days: 1));
  final tomorrow = jstDateKey(tomorrowUtc);
  late _Repo repo;
  late DateTime clock;

  DailyBannerController make() {
    final c = DailyBannerController(repository: repo, now: () => clock);
    addTearDown(c.dispose);
    return c;
  }

  DailyProgress cleared(DateTime start) => DailyProgress(
    startedAt: start,
    clearedAt: start.add(const Duration(minutes: 1)),
  );

  setUp(() {
    repo = _Repo();
    clock = t0;
  });

  test('snapshot is null until the first load finishes', () async {
    final c = make();
    expect(c.snapshot, isNull);
    expect(c.streakToShow, isNull);
    await c.reload();
    expect(c.snapshot?.key, today);
    expect(c.snapshot?.progress, isNull);
  });

  test('a failed load is shown as not started', () async {
    repo
      ..stored[today] = DailyProgress(startedAt: t0)
      ..failLoad = true;
    final c = make();
    await c.reload();
    expect(c.snapshot?.key, today);
    expect(c.snapshot?.progress, isNull);
  });

  test('stats that cannot be read are left out', () async {
    repo
      ..stored[today] = cleared(t0)
      ..failLoadAll = true;
    final c = make();
    await c.reload();
    expect(c.snapshot?.progress?.isCleared, isTrue);
    expect(c.snapshot?.stats, isNull);
    expect(c.streakToShow, isNull);
  });

  group('streakToShow', () {
    test('a one-day streak cleared today is not shown', () async {
      repo.stored[today] = cleared(t0);
      final c = make();
      await c.reload();
      expect(c.snapshot?.stats?.currentStreak, 1);
      expect(c.streakToShow, isNull);
    });

    test('a two-day streak cleared today is shown', () async {
      repo
        ..stored[yesterday] = cleared(t0.subtract(const Duration(days: 1)))
        ..stored[today] = cleared(t0);
      final c = make();
      await c.reload();
      expect(c.streakToShow, 2);
    });

    test('a streak alive through yesterday is shown before clearing', () async {
      repo.stored[yesterday] = cleared(t0.subtract(const Duration(days: 1)));
      final c = make();
      await c.reload();
      expect(c.streakToShow, 1);
    });
  });

  test('checkDate reloads only after the date changes', () async {
    final c = make();
    await c.reload();
    final before = repo.loads;

    c.checkDate();
    await pumpEventQueue();
    expect(repo.loads, before);

    clock = tomorrowUtc;
    c.checkDate();
    await pumpEventQueue();
    expect(repo.loads, before + 1);
    expect(c.snapshot?.key, tomorrow);
  });

  test('checkDate waits for a load of the same day in progress', () async {
    final c = make();
    await c.reload();
    clock = tomorrowUtc;
    repo.gates[tomorrow] = Completer<void>();
    c.checkDate();
    await pumpEventQueue();
    final loads = repo.loads;

    // 読み込みが遅くても、確認のたびに読み直して延期し続けない
    c
      ..checkDate()
      ..checkDate();
    await pumpEventQueue();
    expect(repo.loads, loads);

    repo.gates[tomorrow]!.complete();
    await pumpEventQueue();
    expect(c.snapshot?.key, tomorrow);
  });

  test('a slow older load does not overwrite a newer one', () async {
    repo.gates[today] = Completer<void>();
    final c = make();
    final older = c.reload();
    clock = tomorrowUtc;
    await c.reload();
    expect(c.snapshot?.key, tomorrow);

    repo.gates[today]!.complete();
    await older;
    expect(c.snapshot?.key, tomorrow);
  });

  group('puzzleToOpen', () {
    test('is null before loading', () async {
      expect(await make().puzzleToOpen(), isNull);
    });

    test('opens the puzzle of the shown day', () async {
      final c = make();
      await c.reload();
      final puzzle = await c.puzzleToOpen();
      expect(puzzle?.dateKey, today);
    });

    test('refreshes instead of opening once the date has changed', () async {
      final c = make();
      await c.reload();
      clock = tomorrowUtc;
      expect(await c.puzzleToOpen(), isNull);
      expect(c.snapshot?.key, tomorrow);
    });
  });

  test('stays silent after dispose', () async {
    repo.gates[today] = Completer<void>();
    final c = DailyBannerController(repository: repo, now: () => clock);
    var notified = 0;
    c.addListener(() => notified++);
    final pending = c.reload();
    c.dispose();
    repo.gates[today]!.complete();
    await pending;
    expect(notified, 0);
    expect(c.snapshot, isNull);
  });
}
