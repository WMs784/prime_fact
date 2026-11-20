import 'package:flutter_test/flutter_test.dart';
import 'package:prime_fact/shared/date_key.dart';

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
  });

  test('formatDateKey', () {
    expect(formatDateKey(20261031), '2026-10-31');
    expect(formatDateKey(20270105), '2027-01-05');
  });

  group('dayIndexOf / dateKeyOfDayIndex', () {
    test('consecutive days differ by 1, across month, year and leap day', () {
      expect(dayIndexOf(20261101) - dayIndexOf(20261031), 1);
      expect(dayIndexOf(20270101) - dayIndexOf(20261231), 1);
      expect(dayIndexOf(20280229) - dayIndexOf(20280228), 1);
      expect(dayIndexOf(20280301) - dayIndexOf(20280229), 1);
      expect(dayIndexOf(20270301) - dayIndexOf(20270228), 1);
    });

    test('the epoch is day 0', () {
      expect(dayIndexOf(19700101), 0);
      expect(dateKeyOfDayIndex(0), 19700101);
    });

    test('round trip', () {
      for (final key in [20260101, 20261031, 20271231, 20280229, 20281231]) {
        expect(dateKeyOfDayIndex(dayIndexOf(key)), key);
      }
    });
  });
}
