/// 計算履歴の1件。表示文言は言語依存なので保存せず、表示時に生成する。
class HistoryEntry {
  final String input;

  /// 合成数のときの因数分解（例: `2^2x3`）。素数・1以下のときは null。
  final String? factors;
  final DateTime timestamp;

  HistoryEntry({required this.input, this.factors, required this.timestamp});

  /// `pri_fact_isolate` の結果文字列（`"12 is not prime\n12=2^2x3"`）から作る。
  factory HistoryEntry.fromResult({
    required String input,
    required String result,
    required DateTime timestamp,
  }) => HistoryEntry(
    input: input,
    factors: _factorsFromResult(result),
    timestamp: timestamp,
  );

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

  /// 旧形式（`result` に表示文字列を保存）も読み込める。
  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
    input: json['input'].toString(),
    factors: json.containsKey('result')
        ? _factorsFromResult(json['result'] as String)
        : json['factors'] as String?,
    timestamp: DateTime.parse(json['timestamp'] as String),
  );
}
