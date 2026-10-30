import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'daily_progress.dart';

class DailyRepository {
  static String _key(int dateKey) => 'daily_$dateKey';

  Future<DailyProgress?> load(int dateKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(dateKey));
    if (raw == null) return null;
    try {
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
