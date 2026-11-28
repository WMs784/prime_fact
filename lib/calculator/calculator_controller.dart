import 'package:flutter/foundation.dart';
import 'package:prime_fact/calculator/calculator.dart';
import 'package:prime_fact/calculator/factorization.dart';
import 'package:prime_fact/calculator/judge.dart';
import 'package:prime_fact/calculator/trivia.dart';
import 'package:prime_fact/history/history_entry.dart';

/// 結果欄の内容。文言は持たず、表示するときの言語で組み立てる
/// （表示中に言語が変わっても、その言語で出し直せるように）。
sealed class CalculatorOutput {
  const new();
}

/// 計算に成功した結果。コピー・共有の対象になる。
class CalculatedOutput extends CalculatorOutput {
  const new(this.factorization, this.trivia);

  final Factorization factorization;

  /// 素数/合成数の見出しの代わりに出す豆知識。なければ null。
  final Trivia? trivia;
}

/// 計算に失敗した。コピー・共有の対象にしない。
class FailedOutput extends CalculatorOutput {
  const new();
}

/// 計算機の状態（計算中か・結果欄の内容）と、計算の実行・中止。Widget には依存しない。
class CalculatorController extends ChangeNotifier {
  new(this._calculator, {required this.now});

  final Calculator _calculator;

  /// 履歴に残す計算時刻の取り方。
  final DateTime Function() now;

  bool _isLoading = false;
  CalculatorOutput? _output;
  CancelToken? _cancel;
  bool _disposed = false;

  /// 計算中か。
  bool get isLoading => _isLoading;

  /// 結果欄の内容。null は何も表示しない。
  CalculatorOutput? get output => _output;

  /// 結果欄を空にする。
  void clearOutput() {
    if (_output == null) return;
    _output = null;
    notifyListeners();
  }

  /// 計算中なら中止する。
  void cancel() => _cancel?.cancel();

  /// [n] を因数分解して結果欄に反映する。成功したときだけ、履歴に残す [HistoryEntry] を返す
  /// （失敗・中止・破棄後は null。中止では直前の結果をそのまま残す）。
  Future<HistoryEntry?> calculate(BigInt n) async {
    // 計算中の再呼び出しは受け付けない（先に終わった方が計算中の状態と中止を消してしまうため）
    if (_isLoading) return null;
    final cancel = CancelToken();
    _cancel = cancel;
    _isLoading = true;
    notifyListeners();

    Factorization? result;
    try {
      result = await _calculator(n, cancel);
    } catch (_) {
      // 失敗してもボタンが無効のまま残らないよう、下で必ず読み込み状態を戻す
    }

    if (_disposed) return null;
    _cancel = null;
    _isLoading = false;
    if (cancel.isCancelled) {
      notifyListeners();
      return null;
    }
    if (result == null) {
      _output = const FailedOutput();
      notifyListeners();
      return null;
    }
    _output = CalculatedOutput(result, triviaFor(n));
    notifyListeners();
    return HistoryEntry.fromFactorization(result, timestamp: now());
  }

  @override
  void dispose() {
    _disposed = true;
    _cancel?.cancel();
    super.dispose();
  }
}
