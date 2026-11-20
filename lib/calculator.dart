import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:prime_fact/judge.dart';
import 'package:prime_fact/judge_isolate.dart';

/// 計算の依頼から結果の文字列を作る関数。[cancel] されたら [CancelledException] を投げる。
typedef Calculator = Future<String> Function(
  FactorRequest request,
  CancelToken cancel,
);

/// Web には Isolate がないので、メインスレッドで区切りながら計算する（画面が固まらない）。
/// それ以外は別 Isolate で計算する（メインスレッドを塞がず、描画も落ちない）。
/// どちらも [CancelToken] で中止できる。
Future<String> defaultCalculator(FactorRequest request, CancelToken cancel) =>
    kIsWeb
    ? factorizeAsync(request, cancel)
    : factorizeInIsolate(request, cancel);
