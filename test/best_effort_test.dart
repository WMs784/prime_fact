import 'package:flutter_test/flutter_test.dart';
import 'package:prime_fact/shared/best_effort.dart';

void main() {
  test('runs the action', () async {
    var ran = false;
    await bestEffort(() async => ran = true);
    expect(ran, isTrue);
  });

  test('swallows a failure and completes normally', () async {
    await bestEffort(() async => throw StateError('disk full'));
  });

  test('swallows a synchronous throw as well', () async {
    await bestEffort(() => throw Exception('no storage'));
  });
}
