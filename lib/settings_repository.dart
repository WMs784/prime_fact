import 'package:shared_preferences/shared_preferences.dart';

import 'number_style.dart';

/// アプリの表示設定を `shared_preferences` に保存する。
class SettingsRepository {
  static const _showDailyKey = 'show_daily_challenge';

  /// ホームに「今日の素因数分解」を表示するか。未設定・読み込み失敗時は表示する。
  Future<bool> loadShowDaily() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_showDailyKey) ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> saveShowDaily(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showDailyKey, value);
  }

  static const _numberStyleKey = 'number_style';

  /// 数の表示形式。未設定・読み込み失敗時は [NumberStyle.plain]。
  Future<NumberStyle> loadNumberStyle() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return NumberStyle.fromName(prefs.getString(_numberStyleKey));
    } catch (_) {
      return NumberStyle.plain;
    }
  }

  Future<void> saveNumberStyle(NumberStyle style) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_numberStyleKey, style.name);
  }
}
