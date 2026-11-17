import 'package:cupertino_ui/cupertino_ui.dart'
    show GlobalCupertinoLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:material_ui/material_ui.dart';
import 'package:prime_fact/app_dependencies.dart';
import 'package:prime_fact/home_page.dart';
import 'package:prime_fact/l10n/app_localizations.dart';

void main() => runApp(const PrimeFactApp());

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

class PrimeFactApp extends StatelessWidget {
  const new({super.key, this.dependencies});

  /// 時計・保存先・計算・共有・URL の差し替え口。テストで差し替える。省くと本番の実装を使う。
  final AppDependencies? dependencies;

  @override
  Widget build(BuildContext context) {
    final app = MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.title,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      debugShowCheckedModeBanner: false,
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: const [Locale('ja'), Locale('en')],
      home: const HomePage(),
    );
    final dependencies = this.dependencies;
    return dependencies == null
        ? app
        : AppScope(dependencies: dependencies, child: app);
  }
}
