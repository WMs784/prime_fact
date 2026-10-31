import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prime_fact/l10n/app_localizations.dart';
import 'package:prime_fact/main.dart';
import 'package:prime_fact/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  void ja(WidgetTester tester) {
    tester.platformDispatcher.localesTestValue = [const Locale('ja')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  }

  test('showDaily defaults to true and persists', () async {
    final repo = SettingsRepository();
    expect(await repo.loadShowDaily(), isTrue);
    await repo.saveShowDaily(false);
    expect(await repo.loadShowDaily(), isFalse);
  });

  testWidgets('drawer switch hides and shows the daily banner', (tester) async {
    ja(tester);
    await tester.pumpWidget(MyApp(now: () => DateTime.utc(2026, 5, 1, 3)));
    await tester.pumpAndSettle();
    expect(find.text('今日の素因数分解に挑戦する'), findsOneWidget);

    final scaffold = tester.state<ScaffoldState>(
      find.descendant(
        of: find.byType(MyLayout),
        matching: find.byType(Scaffold),
      ),
    );
    scaffold.openDrawer();
    await tester.pumpAndSettle();
    await tester.tap(find.text('今日の素因数分解を表示'));
    await tester.pumpAndSettle();
    expect(find.text('今日の素因数分解に挑戦する'), findsNothing);
    expect(await SettingsRepository().loadShowDaily(), isFalse);

    await tester.tap(find.text('今日の素因数分解を表示'));
    await tester.pumpAndSettle();
    expect(find.text('今日の素因数分解に挑戦する'), findsOneWidget);
  });

  Widget layout(SettingsRepository repo) => MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('ja')],
    home: MyLayout(
      now: () => DateTime.utc(2026, 5, 1, 3),
      settingsRepository: repo,
    ),
  );

  Future<void> openDrawer(WidgetTester tester) async {
    tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
    await tester.pumpAndSettle();
  }

  testWidgets('a saved false hides the banner and turns the switch off', (
    tester,
  ) async {
    ja(tester);
    SharedPreferences.setMockInitialValues({'show_daily_challenge': false});
    await tester.pumpWidget(MyApp(now: () => DateTime.utc(2026, 5, 1, 3)));
    await tester.pumpAndSettle();
    expect(find.text('今日の素因数分解に挑戦する'), findsNothing);

    tester.state<ScaffoldState>(find.byType(Scaffold).last).openDrawer();
    await tester.pumpAndSettle();
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
  });

  testWidgets('the switch still toggles when saving fails', (tester) async {
    ja(tester);
    await tester.pumpWidget(layout(_FailingSettings()));
    await tester.pumpAndSettle();
    await openDrawer(tester);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
    expect(find.text('今日の素因数分解に挑戦する'), findsNothing);
  });

  testWidgets('a toggle before loading finishes is not overwritten', (
    tester,
  ) async {
    ja(tester);
    final repo = _SlowSettings();
    await tester.pumpWidget(layout(repo));
    expect(find.text('今日の素因数分解に挑戦する'), findsNothing);
    await openDrawer(tester);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();
    repo.loaded.complete(true);
    await tester.pumpAndSettle();
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
  });
}

class _FailingSettings extends SettingsRepository {
  @override
  Future<void> saveShowDaily(bool value) async => throw Exception('disk full');
}

class _SlowSettings extends SettingsRepository {
  final loaded = Completer<bool>();

  @override
  Future<bool> loadShowDaily() => loaded.future;

  @override
  Future<void> saveShowDaily(bool value) async {}
}
