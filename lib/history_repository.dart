import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'history_entry.dart';

class HistoryRepository {
  static const _key = 'calculation_history';

  /// 保存済みの履歴を読む。保存データが壊れている場合は空にする（上書きしてよい）。
  /// ストレージ自体にアクセスできない場合は例外を投げる（呼び出し側は上書き保存を控えること）。
  Future<List<HistoryEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = prefs.getString(_key);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<HistoryEntry> history) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(history.map((e) => e.toJson()).toList());
    await prefs.setString(_key, encoded);
  }
}
