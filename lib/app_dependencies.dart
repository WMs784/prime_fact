import 'package:prime_fact/calculator.dart';
import 'package:prime_fact/daily_repository.dart';
import 'package:prime_fact/history_repository.dart';
import 'package:prime_fact/links.dart';
import 'package:prime_fact/settings_repository.dart';
import 'package:prime_fact/share.dart';

/// アプリが外の世界（時計・保存先・計算・共有・URL）に触れる口をまとめたもの。
///
/// 具体的な実装を選んで組み立てる、コンポジションルート（`PrimeFactApp`）のためのもの。
/// 読んでよいのは入口の層（`main` と `HomePage`）だけで、`HomePage` が必要なものを子の
/// Widget に引数で渡す（`tool/deps/build.py` の層のルールで検査している）。
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
