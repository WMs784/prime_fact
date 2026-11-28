import 'package:flutter_test/flutter_test.dart';
import 'package:prime_fact/app/settings_repository.dart';
import 'package:prime_fact/format/number_style.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('plain leaves digits unchanged', () {
    expect(formatDigits('12345', NumberStyle.plain, ja: true), '12345');
  });

  test('comma and apostrophe group by three', () {
    expect(formatDigits('1234567', NumberStyle.comma, ja: true), '1,234,567');
    expect(formatDigits('123', NumberStyle.comma, ja: true), '123');
    expect(
      formatDigits('1234567', NumberStyle.apostrophe, ja: false),
      "1'234'567",
    );
    expect(
      effectiveStyle(NumberStyle.apostrophe, ja: false),
      NumberStyle.apostrophe,
    );
  });

  test('units in Japanese', () {
    expect(
      formatDigits('123456789', NumberStyle.units, ja: true),
      '1億2345万6789',
    );
    expect(formatDigits('100000000', NumberStyle.units, ja: true), '1億');
    expect(formatDigits('9999', NumberStyle.units, ja: true), '9999');
    // 単位（穰まで）より桁が多いときは整形せずそのまま返す（落ちない）
    final tooLong = '1${'0' * 32}'; // 33 桁 = 9 グループ
    expect(formatDigits(tooLong, NumberStyle.units, ja: true), tooLong);
  });

  test('units are not used in English', () {
    expect(formatDigits('1234567', NumberStyle.units, ja: false), '1234567');
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
