import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:prime_fact/calculator.dart';
import 'package:prime_fact/history_entry.dart';
import 'package:prime_fact/judge.dart';
import 'package:prime_fact/l10n/app_localizations.dart';
import 'package:prime_fact/number_style.dart';
import 'package:prime_fact/share.dart';
import 'package:prime_fact/spoken.dart';
import 'package:prime_fact/trivia.dart';

/// 因数分解の行（2 行目以降）で、「=」の直後と「x」の直前だけ折り返せるようにする。
/// 数字や「^」の途中では折り返さない。
///
/// 「=」でも折り返すのは、`n=` と最初の因数が続けて 1 行に収まらないため。
/// これで `n=`（30 桁なら 31 文字）が 1 行に入る幅（20sp で約 350dp）なら、
/// 数字の途中で折り返さない。それより狭い画面では 30 桁の n だけは途中で折り返す。
String wrapAtTimes(String result) {
  final i = result.indexOf('\n');
  if (i < 0) return result;
  return result.substring(0, i) +
      result
          .substring(i)
          .replaceAllMapped(
            RegExp('[x=]'),
            (m) => m[0] == 'x' ? '\u200Bx' : '=\u200B',
          );
}

class CalculatorForm extends StatefulWidget {
  const new({
    required this.calculator,
    required this.share,
    super.key,
    this.numberStyle = NumberStyle.plain,
    this.onCalculated,
  });

  /// 計算の実行。
  final Calculator calculator;

  /// 結果の共有の仕方。
  final ResultSharer share;
  final void Function(HistoryEntry)? onCalculated;
  final NumberStyle numberStyle;

  @override
  State<CalculatorForm> createState() => _CalculatorFormState();
}

/// 結果欄の内容。
sealed class _Output {
  const new(this.text);

  /// 整形前の文字列。
  final String text;
}

/// 計算に成功した結果。コピー・共有の対象になる。
class _Calculated extends _Output {
  const new(super.text);
}

/// 計算に失敗したときの文言。コピー・共有の対象にしない。
class _CalcFailed extends _Output {
  const new(super.text);
}

class _CalculatorFormState extends State<CalculatorForm> {
  final _controller = TextEditingController();
  bool _isLoading = false;

  /// 結果欄の内容。null は何も表示しない。
  _Output? _output;
  String? _errorText;
  CancelToken? _cancel;

  @override
  void dispose() {
    _cancel?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// 入力・エラー・結果をすべて消して初期状態に戻す。
  void _clear() {
    _controller.clear();
    setState(() {
      _errorText = null;
      _output = null;
    });
  }

  /// 入力を検証して BigInt を返す。不正な場合は _errorText を設定して null を返す。
  BigInt? _validate(AppLocalizations loc) {
    final text = _controller.text.trim();
    final value = BigInt.tryParse(text);
    final error = (text.isEmpty || value == null) ? loc.errorEmpty : null;
    setState(() => _errorText = error);
    return error == null ? value : null;
  }

  Future<void> _calculate() async {
    final loc = AppLocalizations.of(context)!;
    final inputNumber = _validate(loc);
    if (inputNumber == null) {
      setState(() {
        _output = null;
      });
      return;
    }
    final isNotPrime = loc.isNotPrime;
    final isPrime = loc.isPrime;
    final failedText = loc.calcFailed;
    final trivia = triviaFor(inputNumber);

    final cancel = CancelToken();
    _cancel = cancel;
    setState(() => _isLoading = true);

    String? result;
    try {
      result = await widget.calculator((
        n: inputNumber,
        isNotPrime: isNotPrime,
        isPrime: isPrime,
        special: trivia == null ? null : triviaHeader(loc, trivia),
      ), cancel);
    } catch (_) {
      // 失敗してもボタンが無効のまま残らないよう、下で必ず読み込み状態を戻す
    }

    if (!mounted) return;
    _cancel = null;
    if (cancel.isCancelled) {
      // 中止: 履歴は残さず、直前の結果（あれば）をそのまま表示に戻す
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _output = result == null ? _CalcFailed(failedText) : _Calculated(result);
      _isLoading = false;
    });
    if (result == null) return;

    widget.onCalculated?.call(
      HistoryEntry.fromResult(
        input: inputNumber.toString(),
        result: result,
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> _copy(AppLocalizations loc) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: _displayed(loc)));
    messenger.showSnackBar(SnackBar(content: Text(loc.copied)));
  }

  Future<void> _share(BuildContext buttonContext, AppLocalizations loc) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final outcome = await widget.share(
        _displayed(loc),
        originOf(buttonContext),
      );
      // 共有シートがない環境ではコピーになるので、そのことを知らせる
      if (outcome == ShareOutcome.copied) {
        messenger.showSnackBar(SnackBar(content: Text(loc.copied)));
      }
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(loc.shareFailed)));
    }
  }

  /// 表示・コピー・共有に使う、形式を適用した結果。
  String _displayed(AppLocalizations loc) =>
      formatForLocale(loc, _output?.text ?? '', widget.numberStyle);

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final output = _output;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontSize: 18),
            textAlign: TextAlign.center,
            maxLength: 30,
            decoration: InputDecoration(
              errorText: _errorText,
              hintText: AppLocalizations.of(context)!.description,
              hintTextDirection: TextDirection.ltr,
              hintStyle: TextStyle(
                fontSize: 18,
                color: Theme.of(context).hintColor,
              ),
            ),
            textInputAction: TextInputAction.done,
            onChanged: (_) {
              if (_errorText != null) setState(() => _errorText = null);
            },
            onSubmitted: (_) {
              if (!_isLoading) _calculate();
            },
          ),
          // クリアは消すものがないときも置いておく（隠すと判定ボタンの位置が動くため）
          // 狭い画面や大きい文字では折り返す
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            children: [
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _controller,
                builder: (context, value, _) => OutlinedButton(
                  onPressed:
                      !_isLoading &&
                          (value.text.isNotEmpty ||
                              _output != null ||
                              _errorText != null)
                      ? _clear
                      : null,
                  child: Text(
                    loc.clearInput,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: _isLoading ? null : _calculate,
                child: Text(
                  AppLocalizations.of(context)!.button,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 50),
          // 読み込み中と結果表示で高さが変わると入力欄が動くので、最低の高さを確保する
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 120),
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          semanticsLabel: loc.calculating,
                        ),
                        TextButton(
                          onPressed: () => _cancel?.cancel(),
                          child: Text(loc.cancelCalculation),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        // 長い因数分解は折り返して表示する。コピーはボタンから（選択コピーだと折り返し用の不可視文字が混ざるため）
                        // 結果が出たらスクリーンリーダーが読み上げる。読み上げ用の文は
                        // 記号（^ x）や折り返し用の不可視文字を含まない形にする
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            wrapAtTimes(_displayed(loc)),
                            semanticsLabel: output == null
                                ? null
                                : spokenResult(
                                    loc,
                                    output.text,
                                    numberStyle: widget.numberStyle,
                                  ),
                            key: const ValueKey('result'),
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                      ),
                      if (output is _Calculated)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              tooltip: loc.copyResult,
                              icon: const Icon(Icons.copy),
                              onPressed: () => _copy(loc),
                            ),
                            Builder(
                              builder: (buttonContext) => IconButton(
                                tooltip: loc.shareResult,
                                icon: const Icon(Icons.share),
                                onPressed: () => _share(buttonContext, loc),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
