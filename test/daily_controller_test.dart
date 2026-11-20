import 'package:flutter_test/flutter_test.dart';
import 'package:prime_fact/daily_controller.dart';
import 'package:prime_fact/daily_progress.dart';
import 'package:prime_fact/daily_puzzle.dart';
import 'package:prime_fact/daily_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Repo extends DailyRepository {
  bool failLoad = false;
  bool failSave = false;
  int saves = 0;
  final stored = <int, DailyProgress>{};

  @override
  Future<DailyProgress?> load(int dateKey) async {
    if (failLoad) throw Exception('load');
    return stored[dateKey];
  }

  @override
  Future<Map<int, DailyProgress>> loadAll() async => Map.of(stored);

  @override
  Future<void> save(int dateKey, DailyProgress progress) async {
    if (failSave) throw Exception('save');
    saves++;
    stored[dateKey] = progress;
  }
}

void main() {
  final t0 = DateTime.utc(2026, 11, 1, 3); // JST 12:00
  final puzzle = DailyPuzzle.forDate(t0);
  late _Repo repo;
  late DateTime clock;

  DailyController make() =>
      DailyController(puzzle: puzzle, repository: repo, now: () => clock);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repo = _Repo();
    clock = t0;
  });

  test('load starts the clock once and keeps the saved start', () async {
    final c = make();
    addTearDown(c.dispose);
    await c.load();
    expect(c.progress?.startedAt, t0);
    expect(repo.saves, 1);

    clock = t0.add(const Duration(minutes: 5));
    final again = make();
    addTearDown(again.dispose);
    await again.load();
    expect(again.progress?.startedAt, t0);
    expect(repo.saves, 1);
  });

  test('load failure sets loadFailed and a retry recovers', () async {
    repo.failLoad = true;
    final c = make();
    addTearDown(c.dispose);
    await c.load();
    expect(c.loadFailed, isTrue);
    expect(c.progress, isNull);

    repo.failLoad = false;
    await c.load();
    expect(c.loadFailed, isFalse);
    expect(c.progress, isNotNull);
  });

  test('a wrong answer counts a miss, a correct one clears', () async {
    final c = make();
    addTearDown(c.dispose);
    await c.load();

    expect(await c.submit(puzzle.p + 1000), DailySubmitOutcome.wrong);
    expect(c.progress?.wrong, 1);
    expect(c.progress?.isCleared, isFalse);

    clock = t0.add(const Duration(seconds: 30));
    expect(await c.submit(puzzle.p), DailySubmitOutcome.correct);
    expect(c.progress?.isCleared, isTrue);
    expect(c.progress?.clearedAt, clock);
    expect(repo.stored[puzzle.dateKey]?.isCleared, isTrue);
  });

  test('a save failure leaves the state unchanged and unlocks', () async {
    final c = make();
    addTearDown(c.dispose);
    await c.load();
    final before = c.progress;

    repo.failSave = true;
    expect(await c.submit(puzzle.p), DailySubmitOutcome.saveFailed);
    expect(c.progress, same(before));
    expect(c.busy, isFalse);
    expect(c.canSubmit, isTrue);
  });

  test('submit is ignored before load, after clear and while busy', () async {
    final c = make();
    addTearDown(c.dispose);
    expect(await c.submit(1), DailySubmitOutcome.ignored);

    await c.load();
    final first = c.submit(puzzle.p + 1000);
    expect(c.busy, isTrue);
    expect(await c.submit(puzzle.p), DailySubmitOutcome.ignored);
    await first;

    await c.submit(puzzle.p);
    expect(await c.submit(puzzle.p), DailySubmitOutcome.ignored);
  });

  test('streak is loaded after clearing', () async {
    final c = make();
    addTearDown(c.dispose);
    await c.load();
    expect(c.streak, isNull);
    await c.submit(puzzle.p);
    expect(c.streak, 1);
  });

  test('dispose during a pending save does not notify', () async {
    final c = make();
    await c.load();
    var notified = 0;
    c
      ..addListener(() => notified++)
      ..submit(puzzle.p).ignore()
      ..dispose();
    final n = notified;
    await Future<void>.delayed(Duration.zero);
    expect(notified, n);
  });
}
