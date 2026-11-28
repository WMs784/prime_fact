import 'package:prime_fact/calculator/factorization.dart';

/// 計算履歴の1件。表示文言は言語依存なので保存せず、表示時に生成する。
class HistoryEntry {
  /// [factors] が読めなければ [FormatException]（保存データの破損として扱う）。
  new({required this.input, required this.timestamp, this.factors})
    : factorization = Factorization.fromNotation(
        BigInt.tryParse(input) ?? BigInt.zero,
        factors,
      );

  /// 計算結果から作る。因数分解は合成数のときだけ残す（素数・1 以下は数だけで決まる）。
  factory fromFactorization(Factorization f, {required DateTime timestamp}) =>
      HistoryEntry(
        input: f.n.toString(),
        factors: f.isComposite ? f.notation : null,
        timestamp: timestamp,
      );

  /// 旧形式（`result` に表示文字列を保存）も読み込める。
  ///
  /// 旧形式は、保存し直すたびに新形式（`factors`）へ置き換わる。履歴がすべて新形式になる
  /// 見込みが立ったら、この分岐と `test/history_test.dart` の旧形式のテストごと消してよい。
  factory fromJson(Map<String, dynamic> json) => HistoryEntry(
    input: json['input'].toString(),
    factors: json.containsKey('result')
        ? _factorsFromResult(json['result'] as String)
        : json['factors'] as String?,
    timestamp: DateTime.parse(json['timestamp'] as String),
  );
  final String input;

  /// 合成数のときの因数分解（例: `2^2x3`。[Factorization.notation] の形）。素数・1以下のときは null。
  final String? factors;
  final DateTime timestamp;

  /// [input] と [factors] から戻した因数分解（表示用）。
  final Factorization factorization;

  /// 旧形式の表示文字列（`"12は素数ではありません\n12=2^2x3"`）から因数分解を取り出す。
  static String? _factorsFromResult(String result) {
    final lines = result.split('\n');
    if (lines.length < 2) return null;
    final eq = lines[1].indexOf('=');
    return eq < 0 ? null : lines[1].substring(eq + 1);
  }

  Map<String, dynamic> toJson() => {
    'input': input,
    'factors': factors,
    'timestamp': timestamp.toIso8601String(),
  };
}
