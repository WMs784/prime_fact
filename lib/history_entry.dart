/// 計算履歴の1件。表示文言は言語依存なので保存せず、表示時に生成する。
class HistoryEntry {
  new({required this.input, required this.timestamp, this.factors});

  /// `factorizeSync` の結果文字列（`"12 is not prime\n12=2^2x3"`）から作る。
  factory fromResult({
    required String input,
    required String result,
    required DateTime timestamp,
  }) => HistoryEntry(
    input: input,
    factors: _factorsFromResult(result),
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

  /// 合成数のときの因数分解（例: `2^2x3`）。素数・1以下のときは null。
  final String? factors;
  final DateTime timestamp;

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
