import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:styled_text/styled_text.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:prime_fact/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'judge.dart';
import 'history_entry.dart';
import 'history_repository.dart';
import 'history_page.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
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
      supportedLocales: const [
        Locale('ja', ''),
        Locale('en', ''),
      ],
      home: const Scaffold(
        body: MyLayout(),
      ),
    );
  }
}

class MyLayout extends StatefulWidget {
  const MyLayout({Key? key}) : super(key: key);

  @override
  State<MyLayout> createState() => _MyLayoutState();
}

class _MyLayoutState extends State<MyLayout> {
  List<HistoryEntry> _history = [];
  final _repo = HistoryRepository();

  @override
  void initState() {
    super.initState();
    _repo.load().then((list) => setState(() => _history = list));
  }

  void _addHistory(HistoryEntry entry) async {
    setState(() => _history.add(entry));
    await _repo.save(_history);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text(loc.title),
        ),
        drawer: Drawer(
          child: ListView(
            children: <Widget>[
              DrawerHeader(
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                ),
                child: StyledText(
                  text: '<set/>&space;${loc.info}',
                  style: const TextStyle(
                    fontSize: 24,
                    color: Colors.white,
                  ),
                  tags: {
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
                  launchUrlString('https://wms784.github.io/prime_fact/');
                },
              ),
              ListTile(
                title: Text(loc.review),
                onTap: () {
                  launchUrlString(
                      'https://play.google.com/store/apps/details?id=project.My_prime_nember');
                },
              ),
              ListTile(
                title: Text(loc.contact),
                onTap: () {
                  launchUrlString('https://forms.gle/YvXNAPHupB1wJFCR8');
                },
              ),
              ListTile(
                title: Text(loc.aboutUs),
                onTap: () {
                  launchUrlString(
                      'https://play.google.com/store/apps/dev?id=6078644560561044674');
                },
              ),
            ],
          ),
        ),
        body: Center(
          child: MyWidget(onCalculated: _addHistory),
        ),
      ),
    );
  }
}

class MyWidget extends StatefulWidget {
  final void Function(HistoryEntry)? onCalculated;

  const MyWidget({Key? key, this.onCalculated}) : super(key: key);

  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  int count = 0;
  bool b = true;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        TextField(
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 25),
          textAlign: TextAlign.center,
          maxLength: 18,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)!.description,
            hintTextDirection: TextDirection.ltr,
            hintStyle: TextStyle(
              fontSize: 14,
              color: Theme.of(context).hintColor,
            ),
          ),
          onChanged: (text) {
            try {
              count = int.parse(text);
              b = true;
            } catch (exception) {
              b = false;
            }
          },
        ),
        ElevatedButton(
          onPressed: _isLoading
              ? null
              : () async {
                  if (!b) {
                    setState(() => s = e);
                    return;
                  }
                  final loc = AppLocalizations.of(context)!;
                  final isNotPrime = loc.isNotPrime;
                  final isPrime = loc.isPrime;
                  final inputNumber = count;

                  setState(() => _isLoading = true);

                  final result = await compute(
                    pri_fact_isolate,
                    [inputNumber, isNotPrime, isPrime],
                  );

                  setState(() {
                    s = result;
                    _isLoading = false;
                  });

                  widget.onCalculated?.call(HistoryEntry(
                    input: inputNumber,
                    result: result,
                    timestamp: DateTime.now(),
                  ));
                },
          child: Text(
            AppLocalizations.of(context)!.button,
            style: const TextStyle(fontSize: 20),
          ),
        ),
        const SizedBox(height: 50),
        _isLoading
            ? const CircularProgressIndicator()
            : FittedBox(
                fit: BoxFit.fitWidth,
                child: Text(
                  message(s, context),
                  style: const TextStyle(fontSize: 20),
                ),
              ),
      ],
    );
  }
}
