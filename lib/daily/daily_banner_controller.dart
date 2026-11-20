import 'package:flutter/foundation.dart';

import 'package:prime_fact/daily/daily_progress.dart';
import 'package:prime_fact/daily/daily_puzzle.dart';
import 'package:prime_fact/daily/daily_repository.dart';
import 'package:prime_fact/daily/daily_stats.dart';
import 'package:prime_fact/shared/date_key.dart';

/// バナーが読み込んだ、ある日の状態。表示と、タップ先の問題はこの [key] の日に揃える。
///
/// [progress] が null なら未開始（または読めなかった）。[stats]（連続日数などの累計）が
/// null なら、記録を読めなかったので連続の表示を省く。
typedef DailySnapshot = ({int key, DailyProgress? progress, DailyStats? stats});

/// ホーム画面の「今日の素因数分解」バナーの状態。表示する日の記録の読み込みと、日付の変化への
/// 追従を持ち、Widget には依存しない。
///
/// いつ読み直すか（定期的な日付の確認、アプリが前面に戻ったとき、挑戦画面から戻ったとき）は
/// 画面が決めて [checkDate] / [reload] を呼ぶ。
class DailyBannerController extends ChangeNotifier {
  new({required this.repository, required this.now});

  final DailyRepository repository;
  final DateTime Function() now;

  DailySnapshot? _snapshot;

  /// 読み込み中の日。null は読み込み中ではない。
  int? _loadingKey;

  /// 読み込みの世代。後から始めた読み込みより先に始めた読み込みが遅れて終わっても、捨てる。
  int _generation = 0;
  bool _disposed = false;

  /// 最後に読み込めた、ある日の状態。null は読み込み中（まだ一度も読めていない）。
  DailySnapshot? get snapshot => _snapshot;

  /// 出す連続日数。出さないときは null。
  ///
  /// 今日クリア済みなら 2 日以上のとき（1 日目は「クリア」の表示で足りる）、
  /// 未クリアなら昨日までの連続があるときに出す。
  int? get streakToShow {
    final snapshot = _snapshot;
    if (snapshot == null) return null;
    final streak = snapshot.stats?.currentStreak ?? 0;
    final cleared = snapshot.progress?.isCleared ?? false;
    return streak >= (cleared ? 2 : 1) ? streak : null;
  }

  /// いまの日付の記録を読み直す。
  Future<void> reload() async {
    if (_disposed) return;
    final generation = ++_generation;
    final key = jstDateKey(now());
    _loadingKey = key;
    DailyProgress? progress;
    try {
      progress = await repository.load(key);
    } catch (_) {
      // 読めなければ未開始として扱う。挑戦画面側でエラーを表示する
    }
    // 累計は付加情報なので、読めなくてもバナー自体は出す
    final stats = await loadDailyStats(repository, key, today: progress);
    if (_disposed || generation != _generation) return;
    _loadingKey = null;
    _snapshot = (key: key, progress: progress, stats: stats);
    notifyListeners();
  }

  /// 表示している日がもう今日でなければ読み直す。
  ///
  /// 前面に出したまま JST 0 時をまたいだり、端末の時計・タイムゾーンを変えたりしても、
  /// 表示が古い日のままにならないよう、画面が定期的に呼ぶ。
  void checkDate() {
    final today = jstDateKey(now());
    // 同じ日の読み込みが進行中なら待つ（世代で破棄して読み込みを永久に延期しない）
    if (_snapshot?.key != today && _loadingKey != today) reload();
  }

  /// タップで開く問題。まだ読めていない、または日付が変わっていたら null を返す
  /// （日付が変わっていたら、開かずに表示を更新する）。
  ///
  /// 「クリア済み」を見てタップしたら新しい日の計時が始まる、を避けるため。開くのは
  /// 表示している日の問題（now() から取り直すと、表示と遷移先が食い違い得る）。
  Future<DailyPuzzle?> puzzleToOpen() async {
    final key = _snapshot?.key;
    if (key == null) return null;
    if (key != jstDateKey(now())) {
      await reload();
      return null;
    }
    return DailyPuzzle.forDateKey(key);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
