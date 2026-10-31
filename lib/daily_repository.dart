import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'daily_progress.dart';

class DailyRepository {
  static String _key(int dateKey) => 'daily_$dateKey';

  Future<DailyProgress?> load(int dateKey) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      // 文字列以外が入っていると getString が TypeError を投げるので、破損として扱う
      final raw = prefs.getString(_key(dateKey));
      if (raw == null) return null;
      return DailyProgress.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(int dateKey, DailyProgress progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(dateKey), jsonEncode(progress.toJson()));
  }
}
