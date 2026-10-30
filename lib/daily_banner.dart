import 'dart:async';

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

class _DailyBannerState extends State<DailyBanner> with WidgetsBindingObserver {
  DailyProgress? _progress;

  /// [_progress] を読み込んだ日。今日と違えば読み込み直しが済むまで「読み込み中」扱いにする。
  int? _loadedKey;
  Timer? _midnight;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reload();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnight?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _reload();
  }

  Future<void> _reload() async {
    final now = widget.now();
    final key = jstDateKey(now);
    DailyProgress? progress;
    try {
      progress = await widget.repository.load(key);
    } catch (_) {
      // 読めなければ未開始として扱う。挑戦画面側でエラーを表示する
    }
    if (!mounted) return;
    setState(() {
      _progress = progress;
      _loadedKey = key;
    });
    _scheduleMidnight(now);
  }

  /// アプリを開いたまま JST 0 時をまたいでも、表示が前日のままにならないようにする。
  void _scheduleMidnight(DateTime now) {
    _midnight?.cancel();
    final jst = now.toUtc().add(const Duration(hours: 9));
    final nextMidnight = DateTime.utc(jst.year, jst.month, jst.day + 1);
    _midnight = Timer(
      nextMidnight.difference(jst) + const Duration(seconds: 1),
      _reload,
    );
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
    final colors = Theme.of(context).colorScheme;
    final loaded = _loadedKey == jstDateKey(widget.now());
    final progress = loaded ? _progress : null;

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
        subtitle: Text(
          subtitle,
          style: TextStyle(color: colors.onPrimaryContainer),
        ),
        trailing: Icon(Icons.chevron_right, color: colors.onPrimaryContainer),
        onTap: loaded ? _open : null,
      ),
    );
  }
}
