import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:prime_fact/calculator/factorization.dart';
import 'package:prime_fact/calculator/judge.dart';
import 'package:prime_fact/calculator/judge_isolate.dart';

/// [n] を因数分解する関数。[cancel] されたら [CancelledException] を投げる。
typedef Calculator = Future<Factorization> Function(
  BigInt n,
  CancelToken cancel,
);

/// Web には Isolate がないので、メインスレッドで区切りながら計算する（画面が固まらない）。
/// それ以外は別 Isolate で計算する（メインスレッドを塞がず、描画も落ちない）。
/// どちらも [CancelToken] で中止できる。
Future<Factorization> defaultCalculator(BigInt n, CancelToken cancel) =>
    kIsWeb ? factorizeAsync(n, cancel) : factorizeInIsolate(n, cancel);
