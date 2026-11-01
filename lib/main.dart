import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:styled_text/styled_text.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:prime_fact/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'daily_banner.dart';
import 'daily_page.dart' show shareText;
import 'daily_repository.dart';
import 'judge.dart';
import 'links.dart';
import 'settings_repository.dart';
import 'history_entry.dart';
import 'history_repository.dart';
import 'history_page.dart';
import 'trivia.dart';

void main() => runApp(const MyApp());

/// `pri_fact_isolate` に渡す引数から結果の文字列を作る関数。
typedef Calculator = Future<String> Function(FactorRequest request);

Future<String> _defaultCalculator(FactorRequest request) =>
    compute(pri_fact_isolate, request);

/// 外部 URL を開く。開けたら true。
typedef UrlOpener = Future<bool> Function(String url);

Future<bool> _defaultUrlOpener(String url) => launchUrlString(url);

ThemeData _buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  return ThemeData(
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.teal,
      brightness: brightness,
      primary: dark ? Colors.teal[300]! : Colors.teal[700]!,
    ),
    focusColor: Colors.teal[200],
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: dark ? Colors.teal[200] : Colors.teal[700],
        foregroundColor: dark ? Colors.grey[900] : Colors.white,
      ),
    ),
  );
}

/// ドロワーのヘッダーの色。白い文字が読めるよう、明暗どちらのテーマでも濃い青緑にする。
final _drawerHeaderColor = Colors.teal.shade700;

class MyApp extends StatelessWidget {
  /// 「今日の素因数分解」の現在時刻。テストで差し替える。
  final DateTime Function() now;

  /// テストで差し替える。
  final DailyRepository? dailyRepository;

  /// テストで差し替える。
  final HistoryRepository? historyRepository;

  /// 計算の実行。テストで差し替える。
  final Calculator calculator;

  /// 外部リンクの開き方。テストで差し替える。
  final UrlOpener openUrl;

  const MyApp({
    super.key,
    this.now = DateTime.now,
    this.dailyRepository,
    this.historyRepository,
    this.calculator = _defaultCalculator,
    this.openUrl = _defaultUrlOpener,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.title,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ja'), Locale('en')],
      home: MyLayout(
        now: now,
        dailyRepository: dailyRepository,
        historyRepository: historyRepository,
        calculator: calculator,
        openUrl: openUrl,
      ),
    );
  }
}

class MyLayout extends StatefulWidget {
  final DateTime Function() now;
  final DailyRepository? dailyRepository;
  final SettingsRepository? settingsRepository;
  final HistoryRepository? historyRepository;
  final Calculator calculator;
  final UrlOpener openUrl;

  const MyLayout({
    super.key,
    this.now = DateTime.now,
    this.dailyRepository,
    this.settingsRepository,
    this.historyRepository,
    this.calculator = _defaultCalculator,
    this.openUrl = _defaultUrlOpener,
  });

  @override
  State<MyLayout> createState() => _MyLayoutState();
}

class _MyLayoutState extends State<MyLayout> {
  List<HistoryEntry> _history = [];
  late final Future<void> _historyLoaded;
  late final HistoryRepository _repo =
      widget.historyRepository ?? HistoryRepository();

  /// 履歴を読めなかったとき true。保存済みの履歴を空で上書きしないよう、保存を控える。
  bool _historyLoadFailed = false;
  late final DailyRepository _dailyRepo =
      widget.dailyRepository ?? DailyRepository();
  late final SettingsRepository _settings =
      widget.settingsRepository ?? SettingsRepository();

  /// null は読み込み中。読み込み前に一瞬バナーが出ないよう、そのあいだは隠す。
  bool? _showDaily;

  @override
  void initState() {
    super.initState();
    // 読み込み完了前に追加された履歴を失わないよう、後ろに連結する
    _historyLoaded = _repo
        .load()
        .then((list) {
          if (mounted) setState(() => _history = [...list, ..._history]);
        })
        .catchError((_) {
          // 読めなくても、この起動中の履歴は使える（保存はしない）
          _historyLoadFailed = true;
        });
    _settings.loadShowDaily().then((v) {
      // 読み込み前に切り替えられていたら、その操作を優先する
      if (mounted && _showDaily == null) setState(() => _showDaily = v);
    });
  }

  /// ドロワーを閉じて外部リンクを開く。開けなければ知らせる。
  Future<void> _openLink(String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final failedText = AppLocalizations.of(context)!.linkOpenFailed;
    Navigator.pop(context);
    var opened = false;
    try {
      opened = await widget.openUrl(url);
    } catch (_) {
      // 開けなかった扱いにする
    }
    if (!opened) {
      messenger.showSnackBar(SnackBar(content: Text(failedText)));
    }
  }

  Future<void> _setShowDaily(bool value) async {
    setState(() => _showDaily = value);
    try {
      await _settings.saveShowDaily(value);
    } catch (_) {
      // 保存に失敗しても、この起動中は切り替えた状態を保つ
    }
  }

  Future<void> _addHistory(HistoryEntry entry) async {
    setState(() => _history.add(entry));
    // 読み込み前に保存すると、保存済みの履歴を上書きしてしまうので待つ
    await _historyLoaded;
    if (_historyLoadFailed) return;
    try {
      await _repo.save(_history);
    } catch (_) {
      // 保存に失敗しても、この起動中の履歴は保つ
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(loc.title)),
      drawer: Drawer(
        child: ListView(
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(color: _drawerHeaderColor),
              child: StyledText(
                text: '<set/>&space;${loc.info}',
                style: const TextStyle(fontSize: 24, color: Colors.white),
                tags: const {
                  'set': StyledTextIconTag(
                    Icons.info,
                    size: 30,
                    color: Colors.white,
                  ),
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: Text(loc.history),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HistoryPage(history: _history),
                  ),
                );
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.today),
              title: Text(loc.showDailyChallenge),
              value: _showDaily ?? true,
              onChanged: _setShowDaily,
            ),
            ListTile(
              title: Text(loc.privacyPolicy),
              onTap: () => _openLink(pagesUrl),
            ),
            ListTile(
              title: Text(loc.review),
              onTap: () => _openLink(playStoreUrl),
            ),
            ListTile(
              title: Text(loc.contact),
              onTap: () => _openLink(contactUrl),
            ),
            ListTile(
              title: Text(loc.aboutUs),
              onTap: () => _openLink(developerUrl),
            ),
          ],
        ),
      ),
      // AppBar がステータスバー側のインセットを処理するため、本文は上以外を保護する
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (_showDaily ?? false)
              DailyBanner(repository: _dailyRepo, now: widget.now),
            Expanded(
              // 結果の高さに関係なく入力欄の位置が変わらないよう、上からの余白を画面の高さの割合で固定する
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: EdgeInsets.only(top: constraints.maxHeight * 0.25),
                  child: MyWidget(
                    onCalculated: _addHistory,
                    calculator: widget.calculator,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 因数分解の行（2 行目以降）で、「x」の直前だけ折り返せるようにする。
/// 数字や「^」の途中では折り返さず、新しい行が「x」から始まる。
String wrapAtTimes(String result) {
  final i = result.indexOf('\n');
  if (i < 0) return result;
  return result.substring(0, i) +
      result.substring(i).replaceAll('x', '\u200Bx');
}

class MyWidget extends StatefulWidget {
  final void Function(HistoryEntry)? onCalculated;

  final Calculator calculator;

  const MyWidget({
    super.key,
    this.onCalculated,
    this.calculator = _defaultCalculator,
  });

  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  String _result = '';
  // 計算に成功した結果だけコピー・共有の対象にする（エラー文言は対象外）
  bool _resultShareable = false;
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 入力を検証して BigInt を返す。不正な場合は _errorText を設定して null を返す。
  BigInt? _validate(AppLocalizations loc) {
    final text = _controller.text.trim();
    final value = BigInt.tryParse(text);
    final error = (text.isEmpty || value == null) ? loc.errorEmpty : null;
    setState(() => _errorText = error);
    return error == null ? value : null;
  }

  Future<void> _calculate() async {
    final loc = AppLocalizations.of(context)!;
    final inputNumber = _validate(loc);
    if (inputNumber == null) {
      setState(() {
        _result = '';
        _resultShareable = false;
      });
      return;
    }
    final isNotPrime = loc.isNotPrime;
    final isPrime = loc.isPrime;
    final failedText = loc.calcFailed;
    final trivia = triviaFor(inputNumber);

    setState(() => _isLoading = true);

    String? result;
    try {
      result = await widget.calculator((
        n: inputNumber,
        isNotPrime: isNotPrime,
        isPrime: isPrime,
        special: trivia == null ? null : triviaHeader(loc, trivia),
      ));
    } catch (_) {
      // 失敗してもボタンが無効のまま残らないよう、下で必ず読み込み状態を戻す
    }

    if (!mounted) return;
    setState(() {
      _result = result ?? failedText;
      _resultShareable = result != null;
      _isLoading = false;
    });
    if (result == null) return;

    widget.onCalculated?.call(
      HistoryEntry.fromResult(
        input: inputNumber.toString(),
        result: result,
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> _copy(AppLocalizations loc) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: _result));
    messenger.showSnackBar(SnackBar(content: Text(loc.copied)));
  }

  Future<void> _share(BuildContext buttonContext) async {
    final box = buttonContext.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    try {
      await shareText(_result, origin);
    } catch (_) {
      // 共有に失敗しても結果の表示は変えない
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontSize: 18),
            textAlign: TextAlign.center,
            maxLength: 30,
            decoration: InputDecoration(
              errorText: _errorText,
              hintText: AppLocalizations.of(context)!.description,
              hintTextDirection: TextDirection.ltr,
              hintStyle: TextStyle(
                fontSize: 18,
                color: Theme.of(context).hintColor,
              ),
            ),
            textInputAction: TextInputAction.done,
            onChanged: (_) {
              if (_errorText != null) setState(() => _errorText = null);
            },
            onSubmitted: (_) {
              if (!_isLoading) _calculate();
            },
          ),
          ElevatedButton(
            onPressed: _isLoading ? null : _calculate,
            child: Text(
              AppLocalizations.of(context)!.button,
              style: const TextStyle(fontSize: 20),
            ),
          ),
          const SizedBox(height: 50),
          // 読み込み中と結果表示で高さが変わると入力欄が動くので、最低の高さを確保する
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 120),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        // 長い因数分解は折り返して表示する。コピーはボタンから（選択コピーだと折り返し用の不可視文字が混ざるため）
                        child: Text(
                          wrapAtTimes(_result),
                          key: const ValueKey('result'),
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                      if (_resultShareable)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              tooltip: loc.copyResult,
                              icon: const Icon(Icons.copy),
                              onPressed: () => _copy(loc),
                            ),
                            Builder(
                              builder: (buttonContext) => IconButton(
                                tooltip: loc.shareResult,
                                icon: const Icon(Icons.share),
                                onPressed: () => _share(buttonContext),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
