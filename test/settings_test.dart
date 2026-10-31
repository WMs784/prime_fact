import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
