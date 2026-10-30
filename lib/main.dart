import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:styled_text/styled_text.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:prime_fact/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'daily_banner.dart';
import 'daily_repository.dart';
import 'judge.dart';
import 'links.dart';
import 'history_entry.dart';
import 'history_repository.dart';
import 'history_page.dart';
import 'trivia.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  /// 「今日の素因数分解」の現在時刻。テストで差し替える。
  final DateTime Function() now;

  const MyApp({super.key, this.now = DateTime.now});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.title,
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          primary: Colors.teal[700]!,
        ),
        primaryColor: Colors.teal[700],
        focusColor: Colors.teal[200],
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal[700],
            foregroundColor: Colors.white,
          ),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
          primary: Colors.teal[300]!,
        ),
        primaryColor: Colors.teal[700],
        focusColor: Colors.teal[200],
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal[200],
            foregroundColor: Colors.grey[900],
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ja', ''), Locale('en', '')],
      home: Scaffold(body: MyLayout(now: now)),
    );
  }
}

class MyLayout extends StatefulWidget {
  final DateTime Function() now;

  const MyLayout({super.key, this.now = DateTime.now});

  @override
  State<MyLayout> createState() => _MyLayoutState();
}

class _MyLayoutState extends State<MyLayout> {
  List<HistoryEntry> _history = [];
  final _repo = HistoryRepository();
  final _dailyRepo = DailyRepository();

  @override
  void initState() {
    super.initState();
    // 読み込み完了前に追加された履歴を失わないよう、後ろに連結する
    _repo.load().then(
      (list) => setState(() => _history = [...list, ..._history]),
    );
  }

  void _addHistory(HistoryEntry entry) async {
    setState(() => _history.add(entry));
    await _repo.save(_history);
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
              decoration: BoxDecoration(color: Theme.of(context).primaryColor),
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
            ListTile(
              title: Text(loc.privacyPolicy),
              onTap: () {
                launchUrlString(pagesUrl);
              },
            ),
            ListTile(
              title: Text(loc.review),
              onTap: () {
                launchUrlString(playStoreUrl);
              },
            ),
            ListTile(
              title: Text(loc.contact),
              onTap: () {
                launchUrlString(contactUrl);
              },
            ),
            ListTile(
              title: Text(loc.aboutUs),
              onTap: () {
                launchUrlString(developerUrl);
              },
            ),
          ],
        ),
      ),
      // AppBar がステータスバー側のインセットを処理するため、本文は上以外を保護する
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            DailyBanner(repository: _dailyRepo, now: widget.now),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: MyWidget(onCalculated: _addHistory),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MyWidget extends StatefulWidget {
  final void Function(HistoryEntry)? onCalculated;

  const MyWidget({super.key, this.onCalculated});

  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  String _result = '';
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
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
            onChanged: (_) {
              if (_errorText != null) setState(() => _errorText = null);
            },
          ),
          ElevatedButton(
            onPressed: _isLoading
                ? null
                : () async {
                    final loc = AppLocalizations.of(context)!;
                    final inputNumber = _validate(loc);
                    if (inputNumber == null) {
                      setState(() => _result = '');
                      return;
                    }
                    final isNotPrime = loc.isNotPrime;
                    final isPrime = loc.isPrime;
                    final trivia = triviaFor(inputNumber);

                    setState(() => _isLoading = true);

                    final result = await compute(pri_fact_isolate, [
                      inputNumber,
                      isNotPrime,
                      isPrime,
                      trivia == null ? null : triviaHeader(loc, trivia),
                    ]);

                    if (!mounted) return;
                    setState(() {
                      _result = result;
                      _isLoading = false;
                    });

                    widget.onCalculated?.call(
                      HistoryEntry.fromResult(
                        input: inputNumber.toString(),
                        result: result,
                        timestamp: DateTime.now(),
                      ),
                    );
                  },
            child: Text(
              AppLocalizations.of(context)!.button,
              style: const TextStyle(fontSize: 20),
            ),
          ),
          const SizedBox(height: 50),
          _isLoading
              ? const CircularProgressIndicator()
              : Row(
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _result,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }
}
