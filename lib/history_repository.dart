import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'history_entry.dart';

class HistoryRepository {
  static const _key = 'calculation_history';

  /// 保持する最大件数。超えた分は古いものから捨てる。
  static const maxEntries = 100;

  static List<HistoryEntry> limit(List<HistoryEntry> history) =>
      history.length <= maxEntries
      ? history
      : history.sublist(history.length - maxEntries);

  Future<List<HistoryEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return limit(
        list
            .map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<HistoryEntry> history) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(limit(history).map((e) => e.toJson()).toList());
    await prefs.setString(_key, encoded);
  }
}
