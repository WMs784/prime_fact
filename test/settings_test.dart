import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:prime_fact/app_dependencies.dart';
import 'package:prime_fact/home_page.dart';
import 'package:prime_fact/main.dart';
import 'package:prime_fact/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/localized_app.dart';

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
    await tester.pumpWidget(
      PrimeFactApp(
        dependencies: AppDependencies(now: () => DateTime.utc(2026, 5, 1, 3)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('今日の素因数分解に挑戦する'), findsOneWidget);

    final scaffold = tester.state<ScaffoldState>(
      find.descendant(
        of: find.byType(HomePage),
        matching: find.byType(Scaffold),
      ),
    );
    // ignore: cascade_invocations -- 前後の行と別の対象への操作
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

  Widget layout(SettingsRepository repo) => localizedApp(
    AppScope(
      dependencies: AppDependencies(
        now: () => DateTime.utc(2026, 5, 1, 3),
        settingsRepository: repo,
      ),
      child: const HomePage(),
    ),
    locale: const Locale('ja'),
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
    await tester.pumpWidget(
      PrimeFactApp(
        dependencies: AppDependencies(now: () => DateTime.utc(2026, 5, 1, 3)),
      ),
    );
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
