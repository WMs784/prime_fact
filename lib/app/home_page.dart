import 'package:material_ui/material_ui.dart';
import 'package:prime_fact/app/app_dependencies.dart';
import 'package:prime_fact/app/app_drawer.dart';
import 'package:prime_fact/app/settings_repository.dart';
import 'package:prime_fact/calculator/calculator_form.dart';
import 'package:prime_fact/daily/daily_banner.dart';
import 'package:prime_fact/daily/daily_repository.dart';
import 'package:prime_fact/format/number_style.dart';
import 'package:prime_fact/history/history_entry.dart';
import 'package:prime_fact/history/history_repository.dart';
import 'package:prime_fact/l10n/app_localizations.dart';
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

class HomePage extends StatefulWidget {
  const new({required this.dependencies, super.key});

  /// このアプリで依存を読むのは、ここだけ。必要なものを子の Widget に引数で渡す。
  final AppDependencies dependencies;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<HistoryEntry> _history = [];
  late final Future<void> _historyLoaded;
  late final AppDependencies _deps = widget.dependencies;
  late final HistoryRepository _repo = _deps.historyRepository;

  /// 履歴を読めなかったとき true。保存済みの履歴を空で上書きしないよう、保存を控える。
  bool _historyLoadFailed = false;
  late final DailyRepository _dailyRepo = _deps.dailyRepository;
  late final SettingsRepository _settings = _deps.settingsRepository;

  /// 読み込み前に一瞬バナーが出ないよう、読み込み中（[_Setting.value] が null）は隠す。
  final _showDaily = _Setting<bool>(true);
  final _numberStyle = _Setting<NumberStyle>(NumberStyle.plain);

  @override
  void initState() {
    super.initState();
    // 読み込み完了前に追加された履歴を失わないよう、後ろに連結する
    _historyLoaded = _repo
        .load()
        .then((list) {
          if (mounted) setState(() => _history = [...list, ..._history]);
        })
        .catchError((_) {
          // 読めなくても、この起動中の履歴は使える（保存はしない）
          _historyLoadFailed = true;
        });
    _settings.loadShowDaily().then((v) {
      // 読み込み前に切り替えられていたら、その操作を優先する
      if (mounted) setState(() => _showDaily.loaded(v));
    });
    _settings.loadNumberStyle().then((v) {
      if (mounted) setState(() => _numberStyle.loaded(v));
    });
  }

  Future<void> _setNumberStyle(NumberStyle style) async {
    setState(() => _numberStyle.value = style);
    await bestEffort(() => _settings.saveNumberStyle(style));
  }

  Future<void> _setShowDaily(bool value) async {
    setState(() => _showDaily.value = value);
    await bestEffort(() => _settings.saveShowDaily(value));
  }

  Future<void> _addHistory(HistoryEntry entry) async {
    setState(() => _history.add(entry));
    // 読み込み前に保存すると、保存済みの履歴を上書きしてしまうので待つ
    await _historyLoaded;
    if (_historyLoadFailed) return;
    await bestEffort(() => _repo.save(_history));
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(loc.title)),
      drawer: AppDrawer(
        history: _history,
        showDaily: _showDaily.orFallback,
        onShowDailyChanged: _setShowDaily,
        numberStyle: _numberStyle.orFallback,
        onNumberStyleChanged: _setNumberStyle,
        openUrl: _deps.openUrl,
      ),
      // AppBar がステータスバー側のインセットを処理するため、本文は上以外を保護する
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (_showDaily.value ?? false)
              DailyBanner(
                repository: _dailyRepo,
                now: _deps.now,
                share: _deps.share,
              ),
            Expanded(
              // 結果の高さに関係なく入力欄の位置が変わらないよう、上からの余白を画面の高さの割合で固定する
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: EdgeInsets.only(top: constraints.maxHeight * 0.25),
                  child: CalculatorForm(
                    calculator: _deps.calculator,
                    share: _deps.share,
                    onCalculated: _addHistory,
                    numberStyle: _numberStyle.orFallback,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
