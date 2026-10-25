import 'package:flutter/material.dart';
import 'package:prime_fact/l10n/app_localizations.dart';
import 'history_entry.dart';

class HistoryPage extends StatelessWidget {
  final List<HistoryEntry> history;

  const HistoryPage({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final reversed = history.reversed.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.historyTitle),
      ),
      body: reversed.isEmpty
          ? Center(child: Text(loc.historyEmpty))
          : ListView.builder(
              itemCount: reversed.length,
              itemBuilder: (context, index) {
                final entry = reversed[index];
                final lines = entry.result.split('\n');
                final t = entry.timestamp;
                final dateStr =
                    '${t.year}/${t.month.toString().padLeft(2, '0')}/${t.day.toString().padLeft(2, '0')}'
                    ' ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

                return ListTile(
                  title: Text(lines[0]),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (lines.length > 1) Text(lines[1]),
                      Text(dateStr,
                          style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.5))),
                    ],
                  ),
                  isThreeLine: lines.length > 1,
                );
              },
            ),
    );
  }
}
