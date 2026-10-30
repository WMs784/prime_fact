import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:prime_fact/l10n/app_localizations.dart';
import 'package:share_plus/share_plus.dart';

import 'daily_progress.dart';
import 'daily_puzzle.dart';
import 'daily_repository.dart';

const playStoreUrl =
    'https://play.google.com/store/apps/details?id=project.My_prime_nember';
const webAppUrl = 'https://wms784.github.io/prime_fact/app/';

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

/// 共有シートで共有する。使えない環境ではクリップボードにコピーして false を返す。
Future<bool> shareText(String text) async {
  try {
    final result = await SharePlus.instance.share(ShareParams(text: text));
    if (result.status != ShareResultStatus.unavailable) return true;
  } catch (_) {}
  await Clipboard.setData(ClipboardData(text: text));
  return false;
}

/// 今日の問題に挑戦する画面。開いた時点で計時が始まる（初回のみ。以降は保存した開始時刻から続く）。
class DailyPage extends StatefulWidget {
  final DailyPuzzle puzzle;
  final DailyRepository repository;
  final DateTime Function() now;
  final Future<bool> Function(String text) onShare;

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
  Timer? _ticker;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final key = widget.puzzle.dateKey;
    var progress = await widget.repository.load(key);
    if (progress == null) {
      progress = DailyProgress(startedAt: widget.now());
      await widget.repository.save(key, progress);
    }
    if (!mounted) return;
    setState(() => _progress = progress);
    if (!progress.isCleared) {
      _ticker = Timer.periodic(
        const Duration(milliseconds: 100),
        (_) => setState(() {}),
      );
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final progress = _progress;
    if (progress == null || progress.isCleared) return;
    final loc = AppLocalizations.of(context)!;
    final answer = int.tryParse(_controller.text.trim());
    if (answer == null) {
      setState(() => _errorText = loc.errorEmpty);
      return;
    }
    final correct = widget.puzzle.isCorrect(answer);
    final next = correct
        ? progress.copyWith(clearedAt: widget.now())
        : progress.copyWith(wrong: progress.wrong + 1);
    setState(() {
      _progress = next;
      _errorText = correct ? null : loc.dailyWrong;
    });
    _controller.clear();
    if (correct) _ticker?.cancel();
    await widget.repository.save(widget.puzzle.dateKey, next);
  }

  Future<void> _share(AppLocalizations loc, DailyProgress progress) async {
    final text = dailyShareText(loc, progress, widget.now());
    final messenger = ScaffoldMessenger.of(context);
    final shared = await widget.onShare(text);
    if (!shared) {
      messenger.showSnackBar(SnackBar(content: Text(loc.dailyCopied)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final progress = _progress;
    return Scaffold(
      appBar: AppBar(title: Text(loc.dailyTitle)),
      body: SafeArea(
        child: progress == null
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: progress.isCleared
                        ? _result(loc, progress)
                        : _play(loc, progress),
                  ),
                ),
              ),
      ),
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

  Widget _play(AppLocalizations loc, DailyProgress progress) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(formatDateKey(widget.puzzle.dateKey), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(
          loc.dailyElapsed(formatElapsed(progress.elapsed(widget.now()))),
          textAlign: TextAlign.center,
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
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18),
          maxLength: 6,
          decoration: InputDecoration(
            hintText: loc.dailyAnswerHint,
            errorText: _errorText,
          ),
          onChanged: (_) {
            if (_errorText != null) setState(() => _errorText = null);
          },
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: _submit,
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
        ElevatedButton.icon(
          onPressed: () => _share(loc, progress),
          icon: const Icon(Icons.share),
          label: Text(loc.dailyShare),
        ),
        const SizedBox(height: 12),
        _backHome(loc),
      ],
    );
  }
}
