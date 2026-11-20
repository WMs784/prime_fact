import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:prime_fact/app/app_dependencies.dart';
import 'package:prime_fact/app/app_drawer.dart';
import 'package:prime_fact/app/home_controller.dart';
import 'package:prime_fact/calculator/calculator_form.dart';
import 'package:prime_fact/daily/daily_banner.dart';
import 'package:prime_fact/l10n/app_localizations.dart';

class HomePage extends StatefulWidget {
  const new({required this.dependencies, super.key});

  /// このアプリで依存を読むのは、ここだけ。必要なものを子の Widget に引数で渡す。
  final AppDependencies dependencies;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final AppDependencies _deps = widget.dependencies;
  late final HomeController _home = HomeController(
    historyRepository: _deps.historyRepository,
    settingsRepository: _deps.settingsRepository,
  );

  @override
  void initState() {
    super.initState();
    unawaited(_home.load());
  }

  @override
  void dispose() {
    _home.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _home,
    builder: (context, _) => _scaffold(context),
  );

  Widget _scaffold(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(loc.title)),
      drawer: AppDrawer(
        history: _home.history,
        showDaily: _home.showDailyOrDefault,
        onShowDailyChanged: _home.setShowDaily,
        numberStyle: _home.numberStyle,
        onNumberStyleChanged: _home.setNumberStyle,
        openUrl: _deps.openUrl,
      ),
      // AppBar がステータスバー側のインセットを処理するため、本文は上以外を保護する
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (_home.showDaily ?? false)
              DailyBanner(
                repository: _deps.dailyRepository,
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
                    now: _deps.now,
                    onCalculated: _home.addHistory,
                    numberStyle: _home.numberStyle,
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
