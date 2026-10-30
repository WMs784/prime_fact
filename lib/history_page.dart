import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:prime_fact/l10n/app_localizations.dart';

import 'history_entry.dart';
import 'trivia.dart';

/// 保存データから、現在の言語で結果の表示行を組み立てる。
List<String> _describe(AppLocalizations loc, HistoryEntry entry) {
  final n = BigInt.tryParse(entry.input) ?? BigInt.zero;
  final header = '${entry.input}${headerFor(loc, n)}';
  final factors = entry.factors;
  return factors == null ? [header] : [header, '${entry.input}=$factors'];
}

class HistoryPage extends StatelessWidget {
  final List<HistoryEntry> history;

  const HistoryPage({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final reversed = history.reversed.toList();
    final dateFormat = DateFormat.yMd(loc.localeName).add_Hm();

    return Scaffold(
      appBar: AppBar(title: Text(loc.historyTitle)),
      body: reversed.isEmpty
          ? Center(child: Text(loc.historyEmpty))
          : ListView.builder(
              itemCount: reversed.length,
              itemBuilder: (context, index) {
                final entry = reversed[index];
                final lines = _describe(loc, entry);
                final dateStr = dateFormat.format(entry.timestamp);

                return ListTile(
                  title: Text(lines[0]),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (lines.length > 1) Text(lines[1]),
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                  isThreeLine: lines.length > 1,
                );
              },
            ),
    );
  }
}
