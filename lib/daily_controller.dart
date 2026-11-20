import 'package:flutter/foundation.dart';

import 'package:prime_fact/daily_progress.dart';
import 'package:prime_fact/daily_puzzle.dart';
import 'package:prime_fact/daily_repository.dart';
import 'package:prime_fact/daily_stats.dart';

/// [DailyController.submit] の結果。
enum DailySubmitOutcome {
  /// 受け付けなかった（読み込み前、クリア済み、保存中）。
  ignored,

  /// 保存に失敗した。画面には反映していない。
  saveFailed,

  /// 正解。クリアを保存した。
  correct,

  /// 不正解。ミスの回数を保存した。
  wrong,
}

/// 「今日の素因数分解」の挑戦画面の状態。読み込み・回答・保存・連続日数を持ち、Widget には依存しない。
///
/// 記録は作成時の問題の日付（[DailyPuzzle.dateKey]）で保存する。0 時をまたいで答えても
/// 前日の問題の記録として残る。
class DailyController extends ChangeNotifier {
  new({required this.puzzle, required this.repository, required this.now});

  final DailyPuzzle puzzle;
  final DailyRepository repository;
  final DateTime Function() now;

  DailyProgress? _progress;
  bool _loadFailed = false;
  int? _streak;
  bool _busy = false;
  bool _disposed = false;

  /// 読み込んだ記録。null は読み込み中（または [loadFailed]）。
  DailyProgress? get progress => _progress;

  /// 記録を読めなかった（再試行は [load]）。
  bool get loadFailed => _loadFailed;

  /// クリア後に出す連続日数。記録を読めなければ null（表示を省く）。
  int? get streak => _streak;

  /// 保存中は回答を受け付けない（連打で保存の順序が入れ替わるのを防ぐ）。
  bool get busy => _busy;

  /// いま回答を受け付けるか。
  bool get canSubmit {
    final progress = _progress;
    return progress != null && !progress.isCleared && !_busy;
  }

  /// 保存した記録を読む。なければ今を開始時刻として保存する。
  Future<void> load() async {
    _loadFailed = false;
    try {
      final key = puzzle.dateKey;
      final saved = await repository.load(key);
      final progress = saved ?? DailyProgress(startedAt: now());
      if (saved == null) await repository.save(key, progress);
      if (_disposed) return;
      _progress = progress;
      notifyListeners();
      if (progress.isCleared) await _loadStreak(progress);
    } catch (_) {
      if (_disposed) return;
      _loadFailed = true;
      notifyListeners();
    }
  }

  Future<void> _loadStreak(DailyProgress cleared) async {
    final stats = await loadDailyStats(
      repository,
      puzzle.dateKey,
      today: cleared,
    );
    // 連続日数は付加情報なので、読めなければ出さない
    if (!_disposed && stats != null) {
      _streak = stats.currentStreak;
      notifyListeners();
    }
  }

  /// [answer] を採点して保存する。保存に成功してから状態に反映する
  /// （保存できなかったクリアやミスを見せない）。
  Future<DailySubmitOutcome> submit(int answer) async {
    final progress = _progress;
    if (progress == null || !canSubmit) return DailySubmitOutcome.ignored;
    final correct = puzzle.isCorrect(answer);
    final next = correct
        ? progress.copyWith(clearedAt: now())
        : progress.copyWith(wrong: progress.wrong + 1);

    _busy = true;
    notifyListeners();
    try {
      await repository.save(puzzle.dateKey, next);
    } catch (_) {
      if (_disposed) return DailySubmitOutcome.saveFailed;
      _busy = false;
      notifyListeners();
      return DailySubmitOutcome.saveFailed;
    }
    if (_disposed) {
      return correct ? DailySubmitOutcome.correct : DailySubmitOutcome.wrong;
    }
    _progress = next;
    _busy = false;
    notifyListeners();
    if (correct) await _loadStreak(next);
    return correct ? DailySubmitOutcome.correct : DailySubmitOutcome.wrong;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
