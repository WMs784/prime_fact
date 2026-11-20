import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:prime_fact/daily/daily_banner_controller.dart';
import 'package:prime_fact/daily/daily_page.dart';
import 'package:prime_fact/daily/daily_progress.dart';
import 'package:prime_fact/daily/daily_records_page.dart';
import 'package:prime_fact/daily/daily_repository.dart';
import 'package:prime_fact/l10n/app_localizations.dart';
import 'package:prime_fact/shared/share.dart';

/// ホーム画面の「今日の素因数分解に挑戦する」バナー。
class DailyBanner extends StatefulWidget {
  const new({
    required this.repository,
    required this.now,
    required this.share,
    super.key,
  });
  final DailyRepository repository;
  final DateTime Function() now;

  /// 「今日の素因数分解」の結果の共有の仕方。
  final ResultSharer share;

  @override
  State<DailyBanner> createState() => _DailyBannerState();
}

class _DailyBannerState extends State<DailyBanner> with WidgetsBindingObserver {
  late final DailyBannerController _controller;
  Timer? _dateCheck;

  @override
  void initState() {
    super.initState();
    _controller = DailyBannerController(
      repository: widget.repository,
      now: widget.now,
    );
    WidgetsBinding.instance.addObserver(this);
    _dateCheck = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _controller.checkDate(),
    );
    unawaited(_controller.reload());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dateCheck?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_controller.reload());
  }

  Future<void> _open() async {
    final puzzle = await _controller.puzzleToOpen();
    if (puzzle == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DailyPage(
          puzzle: puzzle,
          repository: widget.repository,
          now: widget.now,
          onShare: widget.share,
        ),
      ),
    );
    if (!mounted) return;
    await _controller.reload();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) => _banner(context),
  );

  Widget _banner(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final snapshot = _controller.snapshot;
    final loaded = snapshot != null;
    final progress = snapshot?.progress;

    final String title;
    final String subtitle;
    if (!loaded) {
      // 読み込み中。「挑戦する」を一瞬見せてから切り替わるのを避ける
      title = loc.dailyTitle;
      subtitle = '';
    } else if (progress == null) {
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
    final streak = _controller.streakToShow;
    final subtitleStyle = TextStyle(color: colors.onPrimaryContainer);
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      color: colors.primaryContainer,
      child: ListTile(
        enabled: loaded,
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
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle, style: subtitleStyle),
            if (streak != null)
              Text(loc.dailyStreak(streak), style: subtitleStyle),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.bar_chart, color: colors.onPrimaryContainer),
              tooltip: loc.dailyRecords,
              onPressed: loaded
                  ? () => DailyRecordsPage.open(
                      context,
                      repository: widget.repository,
                      now: widget.now,
                    )
                  : null,
            ),
            Icon(Icons.chevron_right, color: colors.onPrimaryContainer),
          ],
        ),
        onTap: loaded ? _open : null,
      ),
    );
  }
}
