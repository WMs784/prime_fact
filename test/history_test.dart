import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:prime_fact/history_entry.dart';
import 'package:prime_fact/history_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('HistoryEntry', () {
    test('toJson / fromJson round trip', () {
      final e = HistoryEntry(
        input: '12',
        result: '12 is not prime\n12=2^2x3',
        timestamp: DateTime.utc(2026, 1, 2, 3, 4, 5),
      );
      final back = HistoryEntry.fromJson(
        jsonDecode(jsonEncode(e.toJson())) as Map<String, dynamic>,
      );
      expect(back.input, e.input);
      expect(back.result, e.result);
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
  });

  group('HistoryRepository', () {
    test('load returns empty list when nothing is stored', () async {
      expect(await HistoryRepository().load(), isEmpty);
    });

    test('save then load preserves order and content', () async {
      final repo = HistoryRepository();
      final entries = [
        HistoryEntry(
            input: '7', result: 'prime', timestamp: DateTime.utc(2026, 1, 1)),
        HistoryEntry(
            input: '8', result: '2^3', timestamp: DateTime.utc(2026, 1, 2)),
      ];
      await repo.save(entries);
      final loaded = await repo.load();
      expect(loaded.map((e) => e.input), ['7', '8']);
      expect(loaded.map((e) => e.result), ['prime', '2^3']);
      expect(loaded.last.timestamp, DateTime.utc(2026, 1, 2));
    });

    test('load returns empty list for corrupted data', () async {
      SharedPreferences.setMockInitialValues(
          {'calculation_history': 'not json'});
      expect(await HistoryRepository().load(), isEmpty);
    });
  });
}
