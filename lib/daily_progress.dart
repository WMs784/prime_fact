/// その日の挑戦の進行状況。画面を閉じても時間が進み続けるよう、開始時刻を保存する。
class DailyProgress {
  final DateTime startedAt;
  final int wrong;
  final DateTime? clearedAt;

  const DailyProgress({
    required this.startedAt,
    this.wrong = 0,
    this.clearedAt,
  });

  bool get isCleared => clearedAt != null;

  /// 開始からの経過時間。端末の時計が巻き戻されても負にはしない。
  Duration elapsed(DateTime now) {
    final d = (clearedAt ?? now).difference(startedAt);
    return d.isNegative ? Duration.zero : d;
  }

  DailyProgress copyWith({int? wrong, DateTime? clearedAt}) => DailyProgress(
    startedAt: startedAt,
    wrong: wrong ?? this.wrong,
    clearedAt: clearedAt ?? this.clearedAt,
  );

  Map<String, dynamic> toJson() => {
    'startedAt': startedAt.millisecondsSinceEpoch,
    'wrong': wrong,
    'clearedAt': clearedAt?.millisecondsSinceEpoch,
  };

  factory DailyProgress.fromJson(Map<String, dynamic> json) {
    final cleared = json['clearedAt'] as int?;
    return DailyProgress(
      startedAt: DateTime.fromMillisecondsSinceEpoch(json['startedAt'] as int),
      wrong: json['wrong'] as int,
      clearedAt: cleared == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(cleared),
    );
  }
}

/// `1:05.3` / `1:02:03.4` 形式。言語に依存しない。
String formatElapsed(Duration d) {
  final tenths = d.inMilliseconds ~/ 100;
  final t = tenths % 10;
  final totalSec = tenths ~/ 10;
  final s = (totalSec % 60).toString().padLeft(2, '0');
  final totalMin = totalSec ~/ 60;
  if (totalMin < 60) return '$totalMin:$s.$t';
  final m = (totalMin % 60).toString().padLeft(2, '0');
  return '${totalMin ~/ 60}:$m:$s.$t';
}
