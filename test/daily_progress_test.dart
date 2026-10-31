import 'package:flutter_test/flutter_test.dart';
import 'package:prime_fact/daily_progress.dart';
import 'package:prime_fact/daily_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final start = DateTime(2026, 10, 31, 9);

  group('DailyProgress', () {
    test('elapsed keeps running until cleared, then stops', () {
      final p = DailyProgress(startedAt: start);
      expect(p.elapsed(start.add(const Duration(seconds: 12))).inSeconds, 12);

      final cleared = p.copyWith(
        clearedAt: start.add(const Duration(seconds: 30)),
      );
      expect(cleared.isCleared, isTrue);
      expect(
        cleared.elapsed(start.add(const Duration(hours: 5))).inSeconds,
        30,
      );
    });

    test('elapsed is never negative when the clock goes back', () {
      final p = DailyProgress(startedAt: start);
      expect(
        p.elapsed(start.subtract(const Duration(minutes: 1))),
        Duration.zero,
      );
    });

    test('JSON round trip', () {
      final p = DailyProgress(
        startedAt: start,
        wrong: 3,
        clearedAt: start.add(const Duration(seconds: 45)),
      );
      final back = DailyProgress.fromJson(p.toJson());
      expect(back.startedAt, p.startedAt);
      expect(back.wrong, 3);
      expect(back.clearedAt, p.clearedAt);
    });

    test('formatElapsed', () {
      expect(formatElapsed(const Duration(milliseconds: 12345)), '0:12.3');
      expect(
        formatElapsed(const Duration(seconds: 65, milliseconds: 300)),
        '1:05.3',
      );
      expect(
        formatElapsed(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '1:02:03.0',
      );
    });
  });

  group('DailyRepository', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('returns null when nothing is saved', () async {
      expect(await DailyRepository().load(20261031), isNull);
    });

    test('saves per date and loads back', () async {
      final repo = DailyRepository();
      await repo.save(20261031, DailyProgress(startedAt: start, wrong: 2));
      final loaded = await repo.load(20261031);
      expect(loaded?.wrong, 2);
      expect(loaded?.startedAt, start);
      expect(await repo.load(20261101), isNull);
    });

    test(
      'a non-string value is treated as not started, not an error',
      () async {
        SharedPreferences.setMockInitialValues({'daily_20261031': 123});
        expect(await DailyRepository().load(20261031), isNull);
      },
    );

    test('corrupted data is treated as not started', () async {
      SharedPreferences.setMockInitialValues({'daily_20261031': 'not json'});
      expect(await DailyRepository().load(20261031), isNull);
    });
  });
}
