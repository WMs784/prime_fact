import 'dart:async';
import 'dart:isolate';

import 'judge.dart';

void _entry((SendPort, FactorRequest) args) =>
    args.$1.send(pri_fact_isolate(args.$2));

/// `pri_fact_isolate` を別 Isolate で実行する。[token] が中止されたら Isolate を止めて
/// [CancelledException] を投げる。Web では Isolate が使えないので `factorizeAsync` を使うこと。
Future<String> factorizeInIsolate(
  FactorRequest request,
  CancelToken token,
) async {
  if (token.isCancelled) throw const CancelledException();
  final result = ReceivePort();
  final errors = ReceivePort();
  final isolate = await Isolate.spawn(_entry, (
    result.sendPort,
    request,
  ), onError: errors.sendPort);
  final done = Completer<String>();
  result.listen((m) {
    if (!done.isCompleted) done.complete(m as String);
  });
  errors.listen((e) {
    if (!done.isCompleted) done.completeError(StateError('isolate failed: $e'));
  });
  token.whenCancelled.then((_) {
    if (!done.isCompleted) done.completeError(const CancelledException());
  });
  try {
    return await done.future;
  } finally {
    isolate.kill(priority: Isolate.immediate);
    result.close();
    errors.close();
  }
}
