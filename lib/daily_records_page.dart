import 'package:flutter/material.dart';
import 'package:prime_fact/l10n/app_localizations.dart';

import 'daily_progress.dart';
import 'daily_puzzle.dart';
import 'daily_repository.dart';
import 'daily_stats.dart';

/// 「今日の素因数分解」の記録画面。連続日数などの累計と、日ごとの結果を出す。
class DailyRecordsPage extends StatefulWidget {
  final DailyRepository repository;
  final DateTime Function() now;

  const DailyRecordsPage({
    super.key,
    required this.repository,
    required this.now,
  });

  @override
  State<DailyRecordsPage> createState() => _DailyRecordsPageState();
}

class _DailyRecordsPageState extends State<DailyRecordsPage> {
  Map<int, DailyProgress>? _records;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final records = await widget.repository.loadAll();
      if (!mounted) return;
      setState(() => _records = records);
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final records = _records;
    final Widget body;
    if (_loadFailed) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(loc.dailyRecordsLoadFailed),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() => _loadFailed = false);
                _load();
              },
              child: Text(loc.dailyRetry),
            ),
          ],
        ),
      );
    } else if (records == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (records.isEmpty) {
      body = Center(child: Text(loc.dailyRecordsEmpty));
    } else {
      body = _content(loc, records);
    }
    return Scaffold(
      appBar: AppBar(title: Text(loc.dailyRecords)),
      body: SafeArea(child: body),
    );
  }

  Widget _content(AppLocalizations loc, Map<int, DailyProgress> records) {
    final now = widget.now();
    final todayKey = jstDateKey(now);
    final stats = DailyStats.compute(records, todayKey);
    final keys = records.keys.toList()..sort((a, b) => b.compareTo(a));
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: keys.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) return _statsGrid(loc, stats);
            final key = keys[index - 1];
            return _row(loc, key, records[key]!, todayKey, now);
          },
        ),
      ),
    );
  }

  Widget _statsGrid(AppLocalizations loc, DailyStats stats) {
    final tiles = [
      (loc.dailyStatCurrentStreak, loc.dailyDays(stats.currentStreak)),
      (loc.dailyStatBestStreak, loc.dailyDays(stats.bestStreak)),
      (loc.dailyStatCleared, loc.dailyDays(stats.cleared)),
      (loc.dailyStatNoMiss, loc.dailyDays(stats.noMiss)),
      (
        loc.dailyStatBestTime,
        stats.bestTime == null ? '-' : formatElapsed(stats.bestTime!),
      ),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (label, value) in tiles)
            SizedBox(
              width: 150,
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(
    AppLocalizations loc,
    int key,
    DailyProgress progress,
    int todayKey,
    DateTime now,
  ) {
    final String text;
    if (progress.isCleared) {
      text = loc.dailyStats(
        formatElapsed(progress.elapsed(now)),
        progress.wrong,
      );
    } else if (key == todayKey) {
      text = loc.dailyRecordInProgress;
    } else {
      text = loc.dailyRecordUnfinished;
    }
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        progress.isCleared ? Icons.check_circle : Icons.radio_button_unchecked,
        color: progress.isCleared ? Colors.teal : null,
      ),
      title: Text(formatDateKey(key)),
      subtitle: Text(text),
    );
  }
}
