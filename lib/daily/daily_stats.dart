import 'package:prime_fact/daily/daily_progress.dart';
import 'package:prime_fact/daily/daily_repository.dart';
import 'package:prime_fact/shared/date_key.dart';

/// 「今日の素因数分解」の累計成績。出題日（JST の `yyyyMMdd`）ごとの記録から求める。
class DailyStats {
  const new({
    required this.cleared,
    required this.noMiss,
    required this.currentStreak,
    required this.bestStreak,
    required this.bestTime,
  });

  /// [records] の全記録と [todayKey]（今日の出題日）から求める。
  ///
  /// [todayKey] より後の日の記録は数えない。端末の時計を進めて挑戦すると未来の日付の記録が
  /// 残るが、それが累計や最長連続に混ざらないようにする（その日が実際に来れば数える）。
  ///
  /// 今日がまだ未クリアでも、昨日までの連続は「続行中」として [currentStreak] に数える
  /// （今日のうちにクリアすれば続く）。
  factory compute(Map<int, DailyProgress> records, int todayKey) {
    final clearedKeys = _clearedKeysUpTo(records, todayKey);
    final (:noMiss, :bestTime) = _tally(records, clearedKeys);
    final runEndingAt = _runLengths(clearedKeys);

    // 今日がクリア済みなら今日まで、そうでなければ昨日までの連続を数える
    final lastDay = records[todayKey]?.isCleared == true
        ? todayKey
        : dateKeyOfDayIndex(dayIndexOf(todayKey) - 1);
    return DailyStats(
      cleared: clearedKeys.length,
      noMiss: noMiss,
      currentStreak: runEndingAt[lastDay] ?? 0,
      bestStreak: runEndingAt.values.fold(0, (a, b) => a > b ? a : b),
      bestTime: bestTime,
    );
  }

  /// [todayKey] 以前にクリアした日（昇順）。未来の日付の記録は含めない。
  static List<int> _clearedKeysUpTo(
    Map<int, DailyProgress> records,
    int todayKey,
  ) =>
      records.entries
          .where((e) => e.key <= todayKey && e.value.isCleared)
          .map((e) => e.key)
          .toList()
        ..sort();

  /// クリアした日のうち、ノーミスの日数と最速のクリアタイム。
  static ({int noMiss, Duration? bestTime}) _tally(
    Map<int, DailyProgress> records,
    List<int> clearedKeys,
  ) {
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
    return (noMiss: noMiss, bestTime: bestTime);
  }

  /// 昇順の [clearedKeys] について、各日で終わる連続クリア日数（出題日 → 日数）。
  static Map<int, int> _runLengths(List<int> clearedKeys) {
    final runEndingAt = <int, int>{};
    var run = 0;
    int? previous;
    for (final key in clearedKeys) {
      run = previous != null && dayIndexOf(key) - dayIndexOf(previous) == 1
          ? run + 1
          : 1;
      runEndingAt[key] = run;
      previous = key;
    }
    return runEndingAt;
  }

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
}

/// バナーと挑戦画面が付加情報として出す累計を読む。読めなければ null（表示を省くだけにする）。
///
/// 今日の記録は呼び出し側が画面に出している [today] を使い、表示と累計がずれないようにする
/// （保存済みの記録を読み直すと、読む間に状態が変わり得る）。
Future<DailyStats?> loadDailyStats(
  DailyRepository repository,
  int todayKey, {
  DailyProgress? today,
}) async {
  try {
    final records = await repository.loadAll();
    if (today != null) records[todayKey] = today;
    return DailyStats.compute(records, todayKey);
  } catch (_) {
    return null;
  }
}
