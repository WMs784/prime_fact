import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show Locale;
import 'package:prime_fact/calculator/calculator_controller.dart';
import 'package:prime_fact/calculator/judge.dart';
import 'package:prime_fact/l10n/app_localizations.dart';

void main() {
  final loc = lookupAppLocalizations(const Locale('ja'));

  test('a result is shown and returned as a history entry', () async {
    FactorRequest? seen;
    final c = CalculatorController((request, cancel) async {
      seen = request;
      return '60=2^2x3x5';
    });
    addTearDown(c.dispose);

    final entry = await c.calculate(BigInt.from(60), loc);

    expect(c.isLoading, isFalse);
    expect(c.output, isA<CalculatedOutput>());
    expect(c.output?.text, '60=2^2x3x5');
    expect(entry?.input, '60');
    expect(seen?.n, BigInt.from(60));
    expect(seen?.isPrime, loc.isPrime);
  });

  test('a special number passes its header to the calculator', () async {
    String? special;
    final c = CalculatorController((request, cancel) async {
      special = request.special;
      return 'x';
    });
    addTearDown(c.dispose);
    await c.calculate(BigInt.from(6), loc);
    expect(special, isNotNull);
  });

  test('a failure shows the failed text and leaves no history', () async {
    final c = CalculatorController(
      (request, cancel) async => throw Exception(),
    );
    addTearDown(c.dispose);

    final entry = await c.calculate(BigInt.from(7), loc);

    expect(entry, isNull);
    expect(c.isLoading, isFalse);
    expect(c.output, isA<FailedOutput>());
    expect(c.output?.text, loc.calcFailed);
  });

  test('cancel keeps the previous output and leaves no history', () async {
    final gate = Completer<String>();
    var calls = 0;
    final c = CalculatorController((request, cancel) {
      if (calls++ == 0) return Future.value('6=2x3');
      return gate.future;
    });
    addTearDown(c.dispose);
    await c.calculate(BigInt.from(6), loc);

    final pending = c.calculate(BigInt.from(10), loc);
    expect(c.isLoading, isTrue);
    c.cancel();
    gate.complete('10=2x5');

    expect(await pending, isNull);
    expect(c.isLoading, isFalse);
    expect(c.output?.text, '6=2x3');
  });

  test('clearOutput empties the output', () async {
    final c = CalculatorController((request, cancel) async => '7');
    addTearDown(c.dispose);
    await c.calculate(BigInt.from(7), loc);
    c.clearOutput();
    expect(c.output, isNull);
  });

  test('dispose cancels a running calculation and stays silent', () async {
    final gate = Completer<String>();
    CancelToken? token;
    final c = CalculatorController((request, cancel) {
      token = cancel;
      return gate.future;
    });
    var notified = 0;
    c.addListener(() => notified++);
    final pending = c.calculate(BigInt.from(10), loc);
    final before = notified;
    c.dispose();
    gate.complete('10=2x5');

    expect(await pending, isNull);
    expect(token?.isCancelled, isTrue);
    expect(notified, before);
  });
}
