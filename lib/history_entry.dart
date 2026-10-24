class HistoryEntry {
  final String input;
  final String result;
  final DateTime timestamp;

  HistoryEntry({
    required this.input,
    required this.result,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'input': input,
    'result': result,
    'timestamp': timestamp.toIso8601String(),
  };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
    input: json['input'].toString(),
    result: json['result'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
  );
}
