import 'package:flutter_test/flutter_test.dart';
import 'package:prime_fact/number_style.dart';
import 'package:prime_fact/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('plain leaves text unchanged', () {
    expect(
      formatNumbers('12345=3x5', NumberStyle.plain, ja: true),
      '12345=3x5',
    );
  });

  test('comma groups by three and skips exponents', () {
    expect(
      formatNumbers('1234567=1000x2^1234', NumberStyle.comma, ja: true),
      '1,234,567=1,000x2^1234',
    );
  });

  test('units in Japanese', () {
    expect(
      formatDigits('123456789', NumberStyle.units, ja: true),
      '1億2345万6789',
    );
    expect(formatDigits('100000000', NumberStyle.units, ja: true), '1億');
    expect(formatDigits('9999', NumberStyle.units, ja: true), '9999');
  });

  test('units are not used in English', () {
    expect(formatDigits('1234567', NumberStyle.units, ja: false), '1234567');
    expect(formatNumbers('1234567', NumberStyle.units, ja: false), '1234567');
    expect(effectiveStyle(NumberStyle.units, ja: false), NumberStyle.plain);
    expect(effectiveStyle(NumberStyle.comma, ja: false), NumberStyle.comma);
  });

  test('setting persists and defaults to plain', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = SettingsRepository();
    expect(await repo.loadNumberStyle(), NumberStyle.plain);
    await repo.saveNumberStyle(NumberStyle.units);
    expect(await repo.loadNumberStyle(), NumberStyle.units);
  });
}
