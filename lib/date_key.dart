/// 出題日を表す `yyyyMMdd` の整数（例: `20261031`）の変換。
///
/// 「今日の素因数分解」の出題・保存・累計がこの形の日付を共有する。
library;

/// 出題日（JST）を `yyyyMMdd` の整数にする。端末のタイムゾーンに依存しない。
int jstDateKey(DateTime now) {
  final jst = now.toUtc().add(const Duration(hours: 9));
  return jst.year * 10000 + jst.month * 100 + jst.day;
}

/// `20261031` を `2026-10-31` にする。
String formatDateKey(int dateKey) {
  final y = dateKey ~/ 10000;
  final m = dateKey ~/ 100 % 100;
  final d = dateKey % 100;
  return '$y-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
}

/// `yyyyMMdd` を、連続判定用の通し日数（UTC の 1970-01-01 からの日数）にする。
int dayIndexOf(int dateKey) => DateTime.utc(
  dateKey ~/ 10000,
  dateKey ~/ 100 % 100,
  dateKey % 100,
).difference(DateTime.utc(1970)).inDays;

/// [dayIndexOf] の逆。
int dateKeyOfDayIndex(int dayIndex) {
  final d = DateTime.utc(1970).add(Duration(days: dayIndex));
  return d.year * 10000 + d.month * 100 + d.day;
}
