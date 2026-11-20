import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:prime_fact/calculator.dart';
import 'package:prime_fact/calculator_controller.dart';
import 'package:prime_fact/history_entry.dart';
import 'package:prime_fact/l10n/app_localizations.dart';
import 'package:prime_fact/number_style.dart';
import 'package:prime_fact/share.dart';
import 'package:prime_fact/spoken.dart';

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

class _CalculatorFormState extends State<CalculatorForm> {
  final _text = TextEditingController();
  late final CalculatorController _calc;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _calc = CalculatorController(widget.calculator);
  }

  @override
  void dispose() {
    _calc.dispose();
    _text.dispose();
    super.dispose();
  }

  /// 入力・エラー・結果をすべて消して初期状態に戻す。
  void _clear() {
    _text.clear();
    setState(() => _errorText = null);
    _calc.clearOutput();
  }

  /// 入力を検証して BigInt を返す。不正な場合は _errorText を設定して null を返す。
  BigInt? _validate(AppLocalizations loc) {
    final text = _text.text.trim();
    final value = BigInt.tryParse(text);
    final error = (text.isEmpty || value == null) ? loc.errorEmpty : null;
    setState(() => _errorText = error);
    return error == null ? value : null;
  }

  Future<void> _calculate() async {
    final loc = AppLocalizations.of(context)!;
    final inputNumber = _validate(loc);
    if (inputNumber == null) {
      _calc.clearOutput();
      return;
    }
    final entry = await _calc.calculate(inputNumber, loc);
    if (!mounted || entry == null) return;
    widget.onCalculated?.call(entry);
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
      formatForLocale(loc, _calc.output?.text ?? '', widget.numberStyle);

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _calc,
    builder: (context, _) => _form(context),
  );

  Widget _form(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final output = _calc.output;
    final isLoading = _calc.isLoading;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            controller: _text,
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
              if (!isLoading) _calculate();
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
                valueListenable: _text,
                builder: (context, value, _) => OutlinedButton(
                  onPressed:
                      !isLoading &&
                          (value.text.isNotEmpty ||
                              output != null ||
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
                onPressed: isLoading ? null : _calculate,
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
            child: isLoading
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          semanticsLabel: loc.calculating,
                        ),
                        TextButton(
                          onPressed: () => _calc.cancel(),
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
                      if (output is CalculatedOutput)
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
