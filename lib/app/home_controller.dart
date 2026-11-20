import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:prime_fact/app/settings_repository.dart';
import 'package:prime_fact/format/number_style.dart';
import 'package:prime_fact/history/history_entry.dart';
import 'package:prime_fact/history/history_repository.dart';
import 'package:prime_fact/shared/best_effort.dart';

/// 保存された設定値。読み込みが終わる前に利用者が変えたら、その操作を優先する。
class _Setting<T> {
  new(this.fallback);

  /// 読み込み前に表示する値。
  final T fallback;

  /// 読み込み済み、または利用者が設定した値（利用者の操作は直接代入する）。
  /// null は読み込み中で、まだ操作もされていない。
  T? value;

  T get orFallback => value ?? fallback;

  /// 保存されていた値を反映する。すでに値があれば（読み込み前に操作されていれば）何もしない。
  void loaded(T v) => value ??= v;
}

/// ホーム画面の状態。履歴と表示設定の読み込み・追加・保存を持ち、Widget には依存しない。
///
/// 保存の失敗は [bestEffort] の方針で握りつぶし、この起動中の状態は保つ。
class HomeController extends ChangeNotifier {
  new({required this.historyRepository, required this.settingsRepository});

  final HistoryRepository historyRepository;
  final SettingsRepository settingsRepository;

  final _history = <HistoryEntry>[];

  /// 履歴の読み込み。[load] より前に [addHistory] を呼ぶのは誤り（保存済みの履歴を上書きし得る）。
  late final Future<void> _historyLoaded;

  /// 履歴を読めなかったとき true。保存済みの履歴を空で上書きしないよう、保存を控える。
  bool _historyLoadFailed = false;

  final _showDaily = _Setting<bool>(true);
  final _numberStyle = _Setting<NumberStyle>(NumberStyle.plain);
  bool _disposed = false;

  /// 計算の履歴（古い順）。読み込み前に追加したものは、読み込んだ履歴の後ろに続く。
  List<HistoryEntry> get history => UnmodifiableListView(_history);

  /// ホームに「今日の素因数分解」を出すか。null は読み込み中
  /// （読み込み前に一瞬バナーが出ないよう、画面は隠す）。
  bool? get showDaily => _showDaily.value;

  /// ドロワーのスイッチに出す値（読み込み中は既定値）。
  bool get showDailyOrDefault => _showDaily.orFallback;

  /// 数の表示形式（読み込み中は既定値）。
  NumberStyle get numberStyle => _numberStyle.orFallback;

  /// 履歴と設定を読む。読み込みの完了を待たずに操作してよい（その操作を優先する）。
  Future<void> load() {
    final history = _loadHistory();
    _historyLoaded = history;
    return Future.wait([
      history,
      settingsRepository.loadShowDaily().then((v) {
        // 読み込み前に切り替えられていたら、その操作を優先する
        _showDaily.loaded(v);
        _notify();
      }),
      settingsRepository.loadNumberStyle().then((v) {
        _numberStyle.loaded(v);
        _notify();
      }),
    ]);
  }

  Future<void> _loadHistory() async {
    try {
      final list = await historyRepository.load();
      // 読み込み完了前に追加された履歴を失わないよう、後ろに連結する
      _history.insertAll(0, list);
      _notify();
    } catch (_) {
      // 読めなくても、この起動中の履歴は使える（保存はしない）
      _historyLoadFailed = true;
    }
  }

  /// 履歴に [entry] を追加して保存する。
  Future<void> addHistory(HistoryEntry entry) async {
    _history.add(entry);
    _notify();
    // 読み込み前に保存すると、保存済みの履歴を上書きしてしまうので待つ
    await _historyLoaded;
    if (_historyLoadFailed) return;
    await bestEffort(() => historyRepository.save(_history));
  }

  Future<void> setShowDaily(bool value) async {
    _showDaily.value = value;
    _notify();
    await bestEffort(() => settingsRepository.saveShowDaily(value));
  }

  Future<void> setNumberStyle(NumberStyle style) async {
    _numberStyle.value = style;
    _notify();
    await bestEffort(() => settingsRepository.saveNumberStyle(style));
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
