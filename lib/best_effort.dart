/// 設定や履歴の保存の失敗方針。
///
/// 保存先（`shared_preferences`）が使えなくても、この起動中の操作は止めない。画面の状態は
/// すでに更新してあるので、保存だけを諦めて続ける。呼び出し側は [bestEffort] で包む。
///
/// 読み込み側の方針は Repository ごとに違う（型で見分けられないので、ここにまとめる）。
///
/// - `SettingsRepository.load*`: 失敗しても例外にせず、既定値を返す。
/// - `HistoryRepository.load`: データの破損は空の履歴を返す（上書きしてよい）。ストレージ自体に
///   アクセスできないときは例外を投げる。呼び出し側は、保存済みの履歴を空で上書きしないよう
///   保存を控える。
/// - `DailyRepository.load`: データの破損は null（未開始）を返す。ストレージ自体にアクセス
///   できないときは例外を投げ、画面がエラーと再試行を出す。
library;

/// [action]（保存など）を実行し、失敗しても例外を投げずに続ける。
Future<void> bestEffort(Future<void> Function() action) async {
  try {
    await action();
  } catch (_) {
    // 失敗しても、この起動中の状態は保つ
  }
}
