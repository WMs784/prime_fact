import 'package:flutter_test/flutter_test.dart';
import 'package:prime_fact/daily_puzzle.dart';

bool _isPrime(int n) {
  if (n < 2) return false;
  for (var i = 2; i * i <= n; i++) {
    if (n % i == 0) return false;
  }
  return true;
}

int _smallestFactor(int n) {
  for (var i = 2; i * i <= n; i++) {
    if (n % i == 0) return i;
  }
  return n;
}

/// 2026-01-01 から 3000 日分の dateKey。
Iterable<int> _dateKeys() sync* {
  var d = DateTime.utc(2026, 1, 1);
  for (var i = 0; i < 3000; i++) {
    yield jstDateKey(d);
    d = d.add(const Duration(days: 1));
  }
}

void main() {
  group('jstDateKey', () {
    test('rolls over at 00:00 JST (15:00 UTC)', () {
      expect(jstDateKey(DateTime.utc(2026, 10, 31, 14, 59, 59)), 20261031);
      expect(jstDateKey(DateTime.utc(2026, 10, 31, 15)), 20261101);
    });

    test('does not depend on the device time zone', () {
      final utc = DateTime.utc(2026, 12, 31, 16);
      expect(jstDateKey(utc), 20270101);
      expect(jstDateKey(utc.toLocal()), 20270101);
    });

    test('formatDateKey', () {
      expect(formatDateKey(20261031), '2026-10-31');
      expect(formatDateKey(20270105), '2027-01-05');
    });
  });

  group('DailyPuzzle', () {
    test('is deterministic', () {
      for (final key in _dateKeys().take(50)) {
        final a = DailyPuzzle.forDateKey(key);
        final b = DailyPuzzle.forDateKey(key);
        expect((a.p, a.q, a.difficulty), (b.p, b.q, b.difficulty));
      }
    });

    test('is a semiprime whose smallest prime factor is p (7..53)', () {
      for (final key in _dateKeys()) {
        final puzzle = DailyPuzzle.forDateKey(key);
        expect(_isPrime(puzzle.p), isTrue, reason: '$key p');
        expect(_isPrime(puzzle.q), isTrue, reason: '$key q');
        expect(puzzle.p, inInclusiveRange(7, 53), reason: '$key');
        expect(puzzle.q, inInclusiveRange(puzzle.p, 293), reason: '$key');
        expect(puzzle.n % puzzle.p, 0);
        expect(_smallestFactor(puzzle.n), puzzle.p, reason: '$key');
        expect(puzzle.n, lessThan(16000));
      }
    });

    test('only the smallest prime factor is accepted', () {
      final puzzle = DailyPuzzle.forDateKey(20261031);
      expect(puzzle.isCorrect(puzzle.p), isTrue);
      for (final wrong in [1, 2, 3, 5, puzzle.n]) {
        expect(puzzle.isCorrect(wrong), isFalse, reason: '$wrong');
      }
      if (puzzle.q != puzzle.p) expect(puzzle.isCorrect(puzzle.q), isFalse);
    });

    test('difficulty tiers match their p range and appear as weighted', () {
      final counts = {for (final d in Difficulty.values) d: 0};
      for (final key in _dateKeys()) {
        final puzzle = DailyPuzzle.forDateKey(key);
        counts[puzzle.difficulty] = counts[puzzle.difficulty]! + 1;
        switch (puzzle.difficulty) {
          case Difficulty.easy:
            expect(puzzle.p, inInclusiveRange(7, 13));
          case Difficulty.medium:
            expect(puzzle.p, inInclusiveRange(17, 31));
          case Difficulty.hard:
            expect(puzzle.p, inInclusiveRange(37, 53));
        }
      }
      // 3000 日で 50% / 35% / 15%（±5%）
      expect(counts[Difficulty.easy]! / 3000, closeTo(0.5, 0.05));
      expect(counts[Difficulty.medium]! / 3000, closeTo(0.35, 0.05));
      expect(counts[Difficulty.hard]! / 3000, closeTo(0.15, 0.05));
    });

    test('puzzles for fixed dates never change (regression)', () {
      final actual = {
        for (final key in [20260101, 20261031, 20270101])
          key: DailyPuzzle.forDateKey(key).n,
      };
      expect(actual, {20260101: 3107, 20261031: 6509, 20270101: 4097});
    });
  });
}
