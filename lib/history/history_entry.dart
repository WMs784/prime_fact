import 'package:prime_fact/calculator/factorization.dart';

/// 計算履歴の1件。表示文言は言語依存なので保存せず、表示時に生成する。
class HistoryEntry {
  const new(this.factorization, {required this.timestamp});

  /// 保存データ（[input] と [factors]）から作る。
  ///
  /// [factors] が読めなければ [FormatException]（保存データの破損として扱う）。
  factory parse({
    required String input,
    required DateTime timestamp,
    String? factors,
  }) => HistoryEntry(
    Factorization.fromNotation(BigInt.tryParse(input) ?? BigInt.zero, factors),
    timestamp: timestamp,
  );

  /// 旧形式（`result` に表示文字列を保存）も読み込める。
  ///
  /// 旧形式は、保存し直すたびに新形式（`factors`）へ置き換わる。履歴がすべて新形式になる
  /// 見込みが立ったら、この分岐と `test/history_test.dart` の旧形式のテストごと消してよい。
  factory fromJson(Map<String, dynamic> json) => HistoryEntry.parse(
    input: json['input'].toString(),
    factors: json.containsKey('result')
        ? _factorsFromResult(json['result'] as String)
        : json['factors'] as String?,
    timestamp: DateTime.parse(json['timestamp'] as String),
  );
  final Factorization factorization;
  final DateTime timestamp;

  /// 入力した数（保存形式）。
  String get input => factorization.n.toString();

  /// 合成数のときの因数分解（例: `2^2x3`。[Factorization.notation] の形。保存形式）。
  /// 素数・1以下のときは null（数だけで決まるので保存しない）。
  String? get factors =>
      factorization.isComposite ? factorization.notation : null;

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
