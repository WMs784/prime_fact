import 'package:material_ui/material_ui.dart';
import 'package:prime_fact/app_drawer.dart';
import 'package:prime_fact/best_effort.dart';
import 'package:prime_fact/calculator_widget.dart';
import 'package:prime_fact/daily_banner.dart';
import 'package:prime_fact/daily_repository.dart';
import 'package:prime_fact/history_entry.dart';
import 'package:prime_fact/history_repository.dart';
import 'package:prime_fact/l10n/app_localizations.dart';
import 'package:prime_fact/links.dart';
import 'package:prime_fact/number_style.dart';
import 'package:prime_fact/settings_repository.dart';
import 'package:prime_fact/share.dart';

class MyLayout extends StatefulWidget {
  const new({
    super.key,
    this.now = DateTime.now,
    this.dailyRepository,
    this.settingsRepository,
    this.historyRepository,
    this.calculator = defaultCalculator,
    this.openUrl = defaultUrlOpener,
    this.share = shareText,
  });
  final DateTime Function() now;
  final DailyRepository? dailyRepository;
  final SettingsRepository? settingsRepository;
  final HistoryRepository? historyRepository;
  final Calculator calculator;
  final UrlOpener openUrl;
  final ResultSharer share;

  @override
  State<MyLayout> createState() => _MyLayoutState();
}

class _MyLayoutState extends State<MyLayout> {
  List<HistoryEntry> _history = [];
  late final Future<void> _historyLoaded;
  late final HistoryRepository _repo =
      widget.historyRepository ?? HistoryRepository();

  /// 履歴を読めなかったとき true。保存済みの履歴を空で上書きしないよう、保存を控える。
  bool _historyLoadFailed = false;
  late final DailyRepository _dailyRepo =
      widget.dailyRepository ?? DailyRepository();
  late final SettingsRepository _settings =
      widget.settingsRepository ?? SettingsRepository();

  /// null は読み込み中。読み込み前に一瞬バナーが出ないよう、そのあいだは隠す。
  bool? _showDaily;
  NumberStyle _numberStyle = NumberStyle.plain;
  bool _numberStyleTouched = false;

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
      if (mounted && _showDaily == null) setState(() => _showDaily = v);
    });
    _settings.loadNumberStyle().then((v) {
      if (mounted && !_numberStyleTouched) setState(() => _numberStyle = v);
    });
  }

  Future<void> _setNumberStyle(NumberStyle style) async {
    _numberStyleTouched = true;
    setState(() => _numberStyle = style);
    await bestEffort(() => _settings.saveNumberStyle(style));
  }

  Future<void> _setShowDaily(bool value) async {
    setState(() => _showDaily = value);
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
      drawer: MyDrawer(
        history: _history,
        showDaily: _showDaily ?? true,
        onShowDailyChanged: _setShowDaily,
        numberStyle: _numberStyle,
        onNumberStyleChanged: _setNumberStyle,
        openUrl: widget.openUrl,
      ),
      // AppBar がステータスバー側のインセットを処理するため、本文は上以外を保護する
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (_showDaily ?? false)
              DailyBanner(repository: _dailyRepo, now: widget.now),
            Expanded(
              // 結果の高さに関係なく入力欄の位置が変わらないよう、上からの余白を画面の高さの割合で固定する
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: EdgeInsets.only(top: constraints.maxHeight * 0.25),
                  child: MyWidget(
                    onCalculated: _addHistory,
                    calculator: widget.calculator,
                    share: widget.share,
                    numberStyle: _numberStyle,
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
