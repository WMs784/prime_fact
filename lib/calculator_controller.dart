import 'package:flutter/foundation.dart';
import 'package:prime_fact/calculator.dart';
import 'package:prime_fact/history_entry.dart';
import 'package:prime_fact/judge.dart';
import 'package:prime_fact/l10n/app_localizations.dart';
import 'package:prime_fact/trivia.dart';

/// 結果欄の内容。
sealed class CalculatorOutput {
  const new(this.text);

  /// 整形前の文字列。
  final String text;
}

/// 計算に成功した結果。コピー・共有の対象になる。
class CalculatedOutput extends CalculatorOutput {
  const new(super.text);
}

/// 計算に失敗したときの文言。コピー・共有の対象にしない。
class FailedOutput extends CalculatorOutput {
  const new(super.text);
}

/// 計算機の状態（計算中か・結果欄の内容）と、計算の実行・中止。Widget には依存しない。
class CalculatorController extends ChangeNotifier {
  new(this._calculator);

  final Calculator _calculator;

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
  Future<HistoryEntry?> calculate(BigInt n, AppLocalizations loc) async {
    // 計算中の再呼び出しは受け付けない（先に終わった方が計算中の状態と中止を消してしまうため）
    if (_isLoading) return null;
    final failedText = loc.calcFailed;
    final trivia = triviaFor(n);
    final request = (
      n: n,
      isNotPrime: loc.isNotPrime,
      isPrime: loc.isPrime,
      special: trivia == null ? null : triviaHeader(loc, trivia),
    );

    final cancel = CancelToken();
    _cancel = cancel;
    _isLoading = true;
    notifyListeners();

    String? result;
    try {
      result = await _calculator(request, cancel);
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
    _output = result == null
        ? FailedOutput(failedText)
        : CalculatedOutput(result);
    notifyListeners();
    if (result == null) return null;
    return HistoryEntry.fromResult(
      input: n.toString(),
      result: result,
      timestamp: DateTime.now(),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _cancel?.cancel();
    super.dispose();
  }
}
