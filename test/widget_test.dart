import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prime_fact/main.dart';

void main() {
  testWidgets('App renders calculator UI', (WidgetTester tester) async {
    await tester.pumpWidget(MyApp());
    await tester.pump();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);
  });

  testWidgets('Input field rejects non-numeric input', (WidgetTester tester) async {
    await tester.pumpWidget(MyApp());
    await tester.pump();

    final field = find.byType(TextField);
    await tester.enterText(field, 'abc');
    await tester.pump();

    final tf = tester.widget<TextField>(field);
    expect(tf.controller?.text ?? '', isEmpty);
  });
}
