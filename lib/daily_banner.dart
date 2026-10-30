import 'package:flutter/material.dart';
import 'package:prime_fact/l10n/app_localizations.dart';

import 'daily_page.dart';
import 'daily_progress.dart';
import 'daily_puzzle.dart';
import 'daily_repository.dart';

/// ホーム画面の「今日の素因数分解に挑戦する」バナー。
class DailyBanner extends StatefulWidget {
  final DailyRepository repository;
  final DateTime Function() now;

  const DailyBanner({super.key, required this.repository, required this.now});

  @override
  State<DailyBanner> createState() => _DailyBannerState();
}

class _DailyBannerState extends State<DailyBanner> {
  DailyProgress? _progress;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final progress = await widget.repository.load(jstDateKey(widget.now()));
    if (mounted) setState(() => _progress = progress);
  }

  Future<void> _open() async {
    final puzzle = DailyPuzzle.forDate(widget.now());
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DailyPage(
          puzzle: puzzle,
          repository: widget.repository,
          now: widget.now,
        ),
      ),
    );
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final progress = _progress;
    final String title;
    final String subtitle;
    if (progress == null) {
      title = loc.dailyBannerStart;
      subtitle = loc.dailyBannerStartSub;
    } else if (progress.isCleared) {
      title = loc.dailyBannerCleared;
      subtitle = loc.dailyStats(
        formatElapsed(progress.elapsed(widget.now())),
        progress.wrong,
      );
    } else {
      title = loc.dailyBannerContinue;
      subtitle = loc.dailyBannerStartSub;
    }
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      color: colors.primaryContainer,
      child: ListTile(
        leading: Icon(
          progress?.isCleared == true ? Icons.check_circle : Icons.emoji_events,
          color: colors.onPrimaryContainer,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colors.onPrimaryContainer,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: colors.onPrimaryContainer),
        ),
        trailing: Icon(Icons.chevron_right, color: colors.onPrimaryContainer),
        onTap: _open,
      ),
    );
  }
}
