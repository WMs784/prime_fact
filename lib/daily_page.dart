import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:prime_fact/l10n/app_localizations.dart';
import 'package:share_plus/share_plus.dart';

import 'daily_progress.dart';
import 'daily_puzzle.dart';
import 'daily_repository.dart';
import 'links.dart';

/// 結果の共有文。問題の数・正解・難度はヒントになるので含めない。日付は投稿時刻で分かる。
String dailyShareText(
  AppLocalizations loc,
  DailyProgress progress,
  DateTime now,
) => loc.dailyShareText(
  formatElapsed(progress.elapsed(now)),
  progress.wrong,
  playStoreUrl,
  webAppUrl,
);

/// 共有シートで共有する。共有シートが使えない環境ではクリップボードにコピーして false を返す。
/// それ以外の失敗は例外のまま呼び出し側に伝える。
/// [origin] は iPad の共有ポップオーバーの基準位置。
Future<bool> shareText(String text, Rect? origin) async {
  final result = await SharePlus.instance.share(
    ShareParams(text: text, sharePositionOrigin: origin),
  );
  if (result.status != ShareResultStatus.unavailable) return true;
  await Clipboard.setData(ClipboardData(text: text));
  return false;
}

/// 今日の問題に挑戦する画面。開いた時点で計時が始まる（初回のみ。以降は保存した開始時刻から続く）。
class DailyPage extends StatefulWidget {
  final DailyPuzzle puzzle;
  final DailyRepository repository;
  final DateTime Function() now;
  final Future<bool> Function(String text, Rect? origin) onShare;

  const DailyPage({
    super.key,
    required this.puzzle,
    required this.repository,
    required this.now,
    this.onShare = shareText,
  });

  @override
  State<DailyPage> createState() => _DailyPageState();
}

class _DailyPageState extends State<DailyPage> {
  final _controller = TextEditingController();
  DailyProgress? _progress;
  bool _loadFailed = false;

  /// 保存中は回答を受け付けない（連打で保存の順序が入れ替わるのを防ぐ）。
  bool _busy = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _loadFailed = false);
    try {
      final key = widget.puzzle.dateKey;
      final saved = await widget.repository.load(key);
      final progress = saved ?? DailyProgress(startedAt: widget.now());
      if (saved == null) await widget.repository.save(key, progress);
      if (!mounted) return;
      setState(() => _progress = progress);
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final progress = _progress;
    if (progress == null || progress.isCleared || _busy) return;
    final loc = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final answer = int.tryParse(_controller.text.trim());
    if (answer == null) {
      setState(() => _errorText = loc.errorEmpty);
      return;
    }
    final correct = widget.puzzle.isCorrect(answer);
    final next = correct
        ? progress.copyWith(clearedAt: widget.now())
        : progress.copyWith(wrong: progress.wrong + 1);

    // 保存に成功してから画面に反映する（保存できなかったクリアやミスを見せない）
    setState(() => _busy = true);
    try {
      await widget.repository.save(widget.puzzle.dateKey, next);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(loc.dailySaveFailed)));
      return;
    }
    if (!mounted) return;
    _controller.clear();
    setState(() {
      _progress = next;
      _busy = false;
      _errorText = correct ? null : loc.dailyWrong;
    });
  }

  Future<void> _share(
    AppLocalizations loc,
    DailyProgress progress,
    Rect? origin,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final text = dailyShareText(loc, progress, widget.now());
    try {
      final shared = await widget.onShare(text, origin);
      if (!shared) {
        messenger.showSnackBar(SnackBar(content: Text(loc.dailyCopied)));
      }
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(loc.dailyShareFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final progress = _progress;
    final Widget body;
    if (_loadFailed) {
      body = _loadError(loc);
    } else if (progress == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      body = Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: progress.isCleared
                ? _result(loc, progress)
                : _play(loc, progress),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(loc.dailyTitle)),
      body: SafeArea(child: body),
    );
  }

  Widget _number(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(
      '${widget.puzzle.n}',
      style: Theme.of(context).textTheme.displayMedium
          ?.copyWith(fontWeight: FontWeight.bold),
    ),
  );

  Widget _backHome(AppLocalizations loc) => OutlinedButton.icon(
    onPressed: () => Navigator.of(context).pop(),
    icon: const Icon(Icons.home),
    label: Text(loc.dailyBackHome),
  );

  Widget _loadError(AppLocalizations loc) => Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(loc.dailyLoadFailed, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _init, child: Text(loc.dailyRetry)),
          const SizedBox(height: 12),
          _backHome(loc),
        ],
      ),
    ),
  );

  Widget _play(AppLocalizations loc, DailyProgress progress) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(formatDateKey(widget.puzzle.dateKey), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        _ElapsedText(
          progress: progress,
          now: widget.now,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(loc.dailyMisses(progress.wrong), textAlign: TextAlign.center),
        const SizedBox(height: 24),
        Text(loc.dailyQuestion, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        _number(context),
        const SizedBox(height: 16),
        TextField(
          controller: _controller,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18),
          maxLength: 6,
          decoration: InputDecoration(
            hintText: loc.dailyAnswerHint,
            errorText: _errorText,
            counterText: '',
          ),
          onChanged: (_) {
            if (_errorText != null) setState(() => _errorText = null);
          },
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: _busy ? null : _submit,
          child: Text(loc.dailySubmit, style: const TextStyle(fontSize: 20)),
        ),
        const SizedBox(height: 32),
        _backHome(loc),
      ],
    );
  }

  Widget _result(AppLocalizations loc, DailyProgress progress) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(formatDateKey(widget.puzzle.dateKey), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        _number(context),
        const SizedBox(height: 16),
        Text(
          loc.dailyCorrect(widget.puzzle.p),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        Text(
          loc.dailyStats(
            formatElapsed(progress.elapsed(widget.now())),
            progress.wrong,
          ),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 24),
        Builder(
          builder: (buttonContext) => ElevatedButton.icon(
            onPressed: () {
              final box = buttonContext.findRenderObject() as RenderBox?;
              final origin = box == null
                  ? null
                  : box.localToGlobal(Offset.zero) & box.size;
              _share(loc, progress, origin);
            },
            icon: const Icon(Icons.share),
            label: Text(loc.dailyShare),
          ),
        ),
        const SizedBox(height: 12),
        _backHome(loc),
      ],
    );
  }
}

/// 経過時間の表示。100ms ごとの再描画をこの Widget の中だけに閉じ込める。
class _ElapsedText extends StatefulWidget {
  final DailyProgress progress;
  final DateTime Function() now;
  final TextStyle? style;

  const _ElapsedText({
    required this.progress,
    required this.now,
    required this.style,
  });

  @override
  State<_ElapsedText> createState() => _ElapsedTextState();
}

class _ElapsedTextState extends State<_ElapsedText> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(
    AppLocalizations.of(context)!
        .dailyElapsed(formatElapsed(widget.progress.elapsed(widget.now()))),
    textAlign: TextAlign.center,
    style: widget.style,
  );
}
