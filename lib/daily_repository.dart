import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'daily_progress.dart';

class DailyRepository {
  static String _key(int dateKey) => 'daily_$dateKey';
  static final _keyPattern = RegExp(r'^daily_(\d{8})$');

  /// 破損している（文字列でない・JSON として読めない）記録は null にする。
  static DailyProgress? _read(SharedPreferences prefs, String key) {
    try {
      // 文字列以外が入っていると getString が TypeError を投げるので、破損として扱う
      final raw = prefs.getString(key);
      if (raw == null) return null;
      return DailyProgress.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<DailyProgress?> load(int dateKey) async {
    final prefs = await SharedPreferences.getInstance();
    return _read(prefs, _key(dateKey));
  }

  /// 保存されている全日の記録（出題日 `yyyyMMdd` → 進行状況）。破損した日は含めない。
  Future<Map<int, DailyProgress>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final result = <int, DailyProgress>{};
    for (final key in prefs.getKeys()) {
      final match = _keyPattern.firstMatch(key);
      if (match == null) continue;
      final progress = _read(prefs, key);
      if (progress != null) result[int.parse(match.group(1)!)] = progress;
    }
    return result;
  }

  Future<void> save(int dateKey, DailyProgress progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(dateKey), jsonEncode(progress.toJson()));
  }
}
