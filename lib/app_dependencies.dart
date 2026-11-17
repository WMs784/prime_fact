import 'package:material_ui/material_ui.dart';
import 'package:prime_fact/calculator.dart';
import 'package:prime_fact/daily_repository.dart';
import 'package:prime_fact/history_repository.dart';
import 'package:prime_fact/links.dart';
import 'package:prime_fact/settings_repository.dart';
import 'package:prime_fact/share.dart';

/// アプリが外の世界（時計・保存先・計算・共有・URL）に触れる口をまとめたもの。
///
/// 既定は本番の実装。テストでは必要なものだけ差し替える。
class AppDependencies {
  new({
    DateTime Function()? now,
    Calculator? calculator,
    UrlOpener? openUrl,
    ResultSharer? share,
    DailyRepository? dailyRepository,
    HistoryRepository? historyRepository,
    SettingsRepository? settingsRepository,
  }) : now = now ?? DateTime.now,
       calculator = calculator ?? defaultCalculator,
       openUrl = openUrl ?? defaultUrlOpener,
       share = share ?? shareText,
       dailyRepository = dailyRepository ?? DailyRepository(),
       historyRepository = historyRepository ?? HistoryRepository(),
       settingsRepository = settingsRepository ?? SettingsRepository();

  /// 「今日の素因数分解」の現在時刻。
  final DateTime Function() now;

  /// 計算の実行。
  final Calculator calculator;

  /// 外部リンクの開き方。
  final UrlOpener openUrl;

  /// 結果の共有の仕方。
  final ResultSharer share;
  final DailyRepository dailyRepository;
  final HistoryRepository historyRepository;
  final SettingsRepository settingsRepository;
}

/// 下の Widget に [AppDependencies] を渡す。
///
/// 依存は起動中に変わらないので、読んでも再構築の購読はしない（`initState` からも読める）。
/// [AppScope] がない場所（Widget 単体のテストなど）では、本番の実装を使う。
class AppScope extends InheritedWidget {
  const new({required this.dependencies, required super.child, super.key});

  final AppDependencies dependencies;

  static final AppDependencies _fallback = AppDependencies();

  static AppDependencies of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()?.dependencies ??
      _fallback;

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      dependencies != oldWidget.dependencies;
}
