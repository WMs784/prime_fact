import 'daily_progress.dart';

/// 「今日の素因数分解」の累計成績。出題日（JST の `yyyyMMdd`）ごとの記録から求める。
class DailyStats {
  /// クリアした日数。
  final int cleared;

  /// ノーミスでクリアした日数。
  final int noMiss;

  /// 今日（クリア前なら昨日）まで途切れずにクリアしている日数。今日も昨日もクリアしていなければ 0。
  final int currentStreak;

  /// これまでで最長の連続クリア日数。
  final int bestStreak;

  /// 最速のクリアタイム。クリア記録がない、または時計の変更で 0 になった記録しかなければ null。
  final Duration? bestTime;

  const DailyStats({
    required this.cleared,
    required this.noMiss,
    required this.currentStreak,
    required this.bestStreak,
    required this.bestTime,
  });

  /// [records] の全記録と [todayKey]（今日の出題日）から求める。
  ///
  /// 今日がまだ未クリアでも、昨日までの連続は「続行中」として [currentStreak] に数える
  /// （今日のうちにクリアすれば続く）。
  factory DailyStats.compute(Map<int, DailyProgress> records, int todayKey) {
    final clearedKeys =
        records.entries
            .where((e) => e.value.isCleared)
            .map((e) => e.key)
            .toList()
          ..sort();

    var noMiss = 0;
    Duration? bestTime;
    for (final key in clearedKeys) {
      final progress = records[key]!;
      if (progress.wrong == 0) noMiss++;
      final t = progress.elapsed(progress.clearedAt!);
      // 端末の時計を変えると 0 になり得る。0 はベストにしない
      if (t > Duration.zero && (bestTime == null || t < bestTime)) {
        bestTime = t;
      }
    }

    var best = 0;
    var run = 0;
    int? previous;
    final runEndingAt = <int, int>{};
    for (final key in clearedKeys) {
      run = previous != null && _dayIndex(key) - _dayIndex(previous) == 1
          ? run + 1
          : 1;
      runEndingAt[key] = run;
      if (run > best) best = run;
      previous = key;
    }

    // 今日がクリア済みなら今日まで、そうでなければ昨日までの連続を数える
    final lastDay = records[todayKey]?.isCleared == true
        ? todayKey
        : _keyOf(_dayIndex(todayKey) - 1);
    return DailyStats(
      cleared: clearedKeys.length,
      noMiss: noMiss,
      currentStreak: runEndingAt[lastDay] ?? 0,
      bestStreak: best,
      bestTime: bestTime,
    );
  }
}

/// `yyyyMMdd` を、連続判定用の通し日数（UTC の 1970-01-01 からの日数）にする。
int _dayIndex(int dateKey) => DateTime.utc(
  dateKey ~/ 10000,
  dateKey ~/ 100 % 100,
  dateKey % 100,
).difference(DateTime.utc(1970)).inDays;

int _keyOf(int dayIndex) {
  final d = DateTime.utc(1970).add(Duration(days: dayIndex));
  return d.year * 10000 + d.month * 100 + d.day;
}
