import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:prime_fact/calculator/calculator.dart';
import 'package:prime_fact/calculator/calculator_controller.dart';
import 'package:prime_fact/calculator/factorization.dart';
import 'package:prime_fact/calculator/judge.dart';
import 'package:prime_fact/calculator/trivia.dart';

import 'helpers/factorization.dart';

final _t0 = DateTime(2026, 11, 21, 9, 30);

CalculatorController _make(Calculator calculator) =>
    CalculatorController(calculator, now: () => _t0);

void main() {
  test('a result is shown and returned as a history entry', () async {
    BigInt? seen;
    final result = fact('60', '2^2x3x5');
    final c = _make((n, cancel) async {
      seen = n;
      return result;
    });
    addTearDown(c.dispose);

    final entry = await c.calculate(BigInt.from(60));

    expect(c.isLoading, isFalse);
    final output = c.output;
    expect(output, isA<CalculatedOutput>());
    expect((output! as CalculatedOutput).factorization, same(result));
    expect((output as CalculatedOutput).trivia, isNull);
    expect(entry?.input, '60');
    expect(entry?.factors, '2^2x3x5');
    expect(entry?.timestamp, _t0);
    expect(seen, BigInt.from(60));
  });

  test('a prime is saved to history without factors', () async {
    final c = _make((n, cancel) async => fact('7'));
    addTearDown(c.dispose);
    final entry = await c.calculate(BigInt.from(7));
    expect(entry?.input, '7');
    expect(entry?.factors, isNull);
  });

  test('a special number carries its trivia', () async {
    final c = _make((n, cancel) async => fact('6', '2x3'));
    addTearDown(c.dispose);
    await c.calculate(BigInt.from(6));
    expect((c.output! as CalculatedOutput).trivia, Trivia.perfect);
  });

  test('a failure shows the failed text and leaves no history', () async {
    final c = _make((n, cancel) async => throw Exception());
    addTearDown(c.dispose);

    final entry = await c.calculate(BigInt.from(7));

    expect(entry, isNull);
    expect(c.isLoading, isFalse);
    expect(c.output, isA<FailedOutput>());
  });

  test('cancel keeps the previous output and leaves no history', () async {
    final gate = Completer<Factorization>();
    var calls = 0;
    final c = _make((n, cancel) {
      if (calls++ == 0) return Future.value(fact('6', '2x3'));
      return gate.future;
    });
    addTearDown(c.dispose);
    await c.calculate(BigInt.from(6));

    final pending = c.calculate(BigInt.from(10));
    expect(c.isLoading, isTrue);
    c.cancel();
    gate.complete(fact('10', '2x5'));

    expect(await pending, isNull);
    expect(c.isLoading, isFalse);
    expect((c.output! as CalculatedOutput).factorization.notation, '2x3');
  });

  test(
    'a call while calculating is ignored and keeps cancel working',
    () async {
      final gate = Completer<Factorization>();
      var calls = 0;
      CancelToken? token;
      final c = _make((n, cancel) {
        calls++;
        token = cancel;
        return gate.future;
      });
      addTearDown(c.dispose);

      final first = c.calculate(BigInt.from(10));
      expect(await c.calculate(BigInt.from(12)), isNull);
      expect(calls, 1);
      expect(c.isLoading, isTrue);

      c.cancel();
      expect(token?.isCancelled, isTrue);
      gate.complete(fact('10', '2x5'));
      expect(await first, isNull);
      expect(c.isLoading, isFalse);
    },
  );

  test('clearOutput empties the output', () async {
    final c = _make((n, cancel) async => fact('7'));
    addTearDown(c.dispose);
    await c.calculate(BigInt.from(7));
    c.clearOutput();
    expect(c.output, isNull);
  });

  test('dispose cancels a running calculation and stays silent', () async {
    final gate = Completer<Factorization>();
    CancelToken? token;
    final c = _make((n, cancel) {
      token = cancel;
      return gate.future;
    });
    var notified = 0;
    c.addListener(() => notified++);
    final pending = c.calculate(BigInt.from(10));
    final before = notified;
    c.dispose();
    gate.complete(fact('10', '2x5'));

    expect(await pending, isNull);
    expect(token?.isCancelled, isTrue);
    expect(notified, before);
  });
}
