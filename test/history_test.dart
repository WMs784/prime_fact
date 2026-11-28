import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:prime_fact/history/history_entry.dart';
import 'package:prime_fact/history/history_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/factorization.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('HistoryEntry', () {
    test('toJson / fromJson round trip', () {
      final e = HistoryEntry(
        input: '12',
        factors: '2^2x3',
        timestamp: DateTime.utc(2026, 1, 2, 3, 4, 5),
      );
      final back = HistoryEntry.fromJson(
        jsonDecode(jsonEncode(e.toJson())) as Map<String, dynamic>,
      );
      expect(back.input, e.input);
      expect(back.factors, '2^2x3');
      expect(back.timestamp, e.timestamp);
    });

    test('fromJson accepts a numeric input (legacy data)', () {
      final e = HistoryEntry.fromJson({
        'input': 12,
        'result': 'r',
        'timestamp': '2026-01-02T03:04:05.000Z',
      });
      expect(e.input, '12');
    });

    test('fromJson migrates legacy result strings to factors', () {
      for (final result in [
        '12 is not prime\n12=2^2x3',
        '12は素数ではありません\n12=2^2x3',
      ]) {
        final e = HistoryEntry.fromJson({
          'input': '12',
          'result': result,
          'timestamp': '2026-01-02T03:04:05.000Z',
        });
        expect(e.factors, '2^2x3');
      }
      final prime = HistoryEntry.fromJson({
        'input': '7',
        'result': '7 is a prime number!',
        'timestamp': '2026-01-02T03:04:05.000Z',
      });
      expect(prime.factors, isNull);
    });

    test('fromFactorization keeps factors only for a composite', () {
      final t = DateTime.utc(2026);
      final composite = HistoryEntry.fromFactorization(
        fact('12', '2^2x3'),
        timestamp: t,
      );
      expect(composite.input, '12');
      expect(composite.factors, '2^2x3');
      expect(composite.timestamp, t);
      for (final n in ['7', '1']) {
        final e = HistoryEntry.fromFactorization(fact(n), timestamp: t);
        expect(e.input, n);
        expect(e.factors, isNull, reason: n);
      }
    });

    test('factorization is restored from the stored data', () {
      final composite = HistoryEntry(
        input: '12',
        factors: '2^2x3',
        timestamp: DateTime.utc(2026),
      ).factorization;
      expect(composite.n, BigInt.from(12));
      expect(composite.notation, '2^2x3');
      expect(composite.isComposite, isTrue);

      final prime = HistoryEntry(input: '7', timestamp: DateTime.utc(2026));
      expect(prime.factorization.isPrime, isTrue);
    });
  });

  group('HistoryRepository', () {
    test('load returns empty list when nothing is stored', () async {
      expect(await HistoryRepository().load(), isEmpty);
    });

    test('save then load preserves order and content', () async {
      final repo = HistoryRepository();
      final entries = [
        HistoryEntry(input: '7', timestamp: DateTime.utc(2026)),
        HistoryEntry(
          input: '8',
          factors: '2^3',
          timestamp: DateTime.utc(2026, 1, 2),
        ),
      ];
      await repo.save(entries);
      final loaded = await repo.load();
      expect(loaded.map((e) => e.input), ['7', '8']);
      expect(loaded.map((e) => e.factors), [null, '2^3']);
      expect(loaded.last.timestamp, DateTime.utc(2026, 1, 2));
    });

    test('load returns empty list for corrupted data', () async {
      SharedPreferences.setMockInitialValues({
        'calculation_history': 'not json',
      });
      expect(await HistoryRepository().load(), isEmpty);
    });

    test('load treats unreadable factors as corrupted data', () async {
      SharedPreferences.setMockInitialValues({
        'calculation_history': jsonEncode([
          {
            'input': '12',
            'factors': '2^2*3',
            'timestamp': '2026-01-02T03:04:05.000Z',
          },
        ]),
      });
      expect(await HistoryRepository().load(), isEmpty);
    });
  });
}
