import 'package:cupertino_ui/cupertino_ui.dart'
    show GlobalCupertinoLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:material_ui/material_ui.dart';
import 'package:prime_fact/calculator_widget.dart';
import 'package:prime_fact/daily_repository.dart';
import 'package:prime_fact/history_repository.dart';
import 'package:prime_fact/home_page.dart';
import 'package:prime_fact/l10n/app_localizations.dart';
import 'package:prime_fact/links.dart';
import 'package:prime_fact/share.dart';

void main() => runApp(const MyApp());

ThemeData _buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  return ThemeData(
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.teal,
      brightness: brightness,
      primary: dark ? Colors.teal[300]! : Colors.teal[700]!,
    ),
    focusColor: Colors.teal[200],
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: dark ? Colors.teal[200] : Colors.teal[700],
        foregroundColor: dark ? Colors.grey[900] : Colors.white,
      ),
    ),
  );
}

/// gen-l10n の `AppLocalizations.localizationsDelegates` は旧 flutter_localizations
/// の Material/Cupertino デリゲートを含むため、material_ui / cupertino_ui 版を使う。
const appLocalizationsDelegates = <LocalizationsDelegate<dynamic>>[
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

class MyApp extends StatelessWidget {
  const new({
    super.key,
    this.now = DateTime.now,
    this.dailyRepository,
    this.historyRepository,
    this.calculator = defaultCalculator,
    this.openUrl = defaultUrlOpener,
    this.share = shareText,
  });

  /// 「今日の素因数分解」の現在時刻。テストで差し替える。
  final DateTime Function() now;

  /// テストで差し替える。
  final DailyRepository? dailyRepository;

  /// テストで差し替える。
  final HistoryRepository? historyRepository;

  /// 計算の実行。テストで差し替える。
  final Calculator calculator;

  /// 外部リンクの開き方。テストで差し替える。
  final UrlOpener openUrl;

  /// 結果の共有の仕方。テストで差し替える。
  final ResultSharer share;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.title,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      debugShowCheckedModeBanner: false,
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: const [Locale('ja'), Locale('en')],
      home: MyLayout(
        now: now,
        dailyRepository: dailyRepository,
        historyRepository: historyRepository,
        calculator: calculator,
        openUrl: openUrl,
        share: share,
      ),
    );
  }
}
