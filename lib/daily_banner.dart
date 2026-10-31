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

  /// [_progress] を読み込んだ日。表示と、タップ先の問題はこの日に揃える。null は読み込み中。
  int? _loadedKey;
  Timer? _dateCheck;

  /// 読み込み中の日。null は読み込み中ではない。
  int? _loadingKey;

  /// 読み込みの世代。後から始めた読み込みより先に始めた読み込みが遅れて終わっても、捨てる。
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _dateCheck = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _checkDate(),
    );
    _reload();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dateCheck?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _reload();
  }

  Future<void> _reload() async {
    if (!mounted) return;
    final generation = ++_generation;
    final key = jstDateKey(widget.now());
    _loadingKey = key;
    DailyProgress? progress;
    try {
      progress = await widget.repository.load(key);
    } catch (_) {
      // 読めなければ未開始として扱う。挑戦画面側でエラーを表示する
    }
    if (!mounted || generation != _generation) return;
    _loadingKey = null;
    setState(() {
      _progress = progress;
      _loadedKey = key;
    });
  }

  /// 前面に出したまま JST 0 時をまたいだり、端末の時計・タイムゾーンを変えたりしても、
  /// 表示が古い日のままにならないよう、定期的に日付を確かめる。
  void _checkDate() {
    final today = jstDateKey(widget.now());
    // 同じ日の読み込みが進行中なら待つ（世代で破棄して読み込みを永久に延期しない）
    if (_loadedKey != today && _loadingKey != today) _reload();
  }

  Future<void> _open() async {
    final key = _loadedKey;
    if (key == null) return;
    // 日付が変わっていたら、古い日の問題を開かずに表示を更新するだけにする
    // （「クリア済み」を見てタップしたら新しい日の計時が始まる、を避ける）
    if (key != jstDateKey(widget.now())) {
      await _reload();
      return;
    }
    // 表示している日の問題を開く（now() を取り直すと、表示と遷移先が食い違い得る）
    final puzzle = DailyPuzzle.forDateKey(key);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DailyPage(
          puzzle: puzzle,
          repository: widget.repository,
          now: widget.now,
        ),
      ),
    );
    if (!mounted) return;
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final loaded = _loadedKey != null;
    final progress = _progress;

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
