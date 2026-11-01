import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'judge.dart';

void _entry((SendPort, FactorRequest) args) =>
    args.$1.send(pri_fact_isolate(args.$2));

/// `pri_fact_isolate` を別 Isolate で実行する。[token] が中止されたら Isolate を止めて
/// [CancelledException] を投げる。Web では Isolate が使えないので `factorizeAsync` を使うこと。
///
/// Isolate が結果もエラーも送らずに終了したとき（メモリ不足など）は [StateError] を投げる。
/// [entry] はテスト用に差し替える。
Future<String> factorizeInIsolate(
  FactorRequest request,
  CancelToken token, {
  @visibleForTesting void Function((SendPort, FactorRequest)) entry = _entry,
}) async {
  if (token.isCancelled) throw const CancelledException();
  final result = ReceivePort();
  final errors = ReceivePort();
  final exit = ReceivePort();
  final isolate = await Isolate.spawn(
    entry,
    (result.sendPort, request),
    onError: errors.sendPort,
    onExit: exit.sendPort,
  );
  final done = Completer<String>();
  result.listen((m) {
    if (!done.isCompleted) done.complete(m as String);
  });
  errors.listen((e) {
    if (!done.isCompleted) done.completeError(StateError('isolate failed: $e'));
  });
  exit.listen((_) {
    // 正常終了でも通知は来る。メッセージは送信順に届くので、結果が先に処理される。
    // それでも完了していなければ、結果を送らずに終了したことになる
    Future.microtask(() {
      if (!done.isCompleted) {
        done.completeError(StateError('isolate exited without a result'));
      }
    });
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
    exit.close();
  }
}
