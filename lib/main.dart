import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:styled_text/styled_text.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'judge.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {//MyWidgetの配置を決めるクラス
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.teal,
        primaryColor: Colors.teal[700],
        // accentColor: Colors.teal[300],
        focusColor: Colors.teal[200],
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.teal,
        primaryColor: Colors.teal[700],
        // accentColor: Colors.teal[300],
        focusColor: Colors.teal[200],
      ),
      debugShowCheckedModeBanner: false,
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [
        Locale('ja', ''), //日本語
        Locale('en', ''), //英語
      ],
      home: Scaffold(
        body: MyLayout(),
      ),
    );
  }
}
class MyLayout extends StatelessWidget {
  @override
  Widget build(BuildContext context){
    return SafeArea(
      child:Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.title),
        ),
        drawer: Drawer(
          child: ListView(
            children: <Widget>[
              DrawerHeader(
                child: StyledText(
                  text: '<set/>&space;'+AppLocalizations.of(context)!.settings,
                  style: TextStyle(
                      fontSize: 24,
                      color: Colors.white,
                  ),
                  tags: {
                    'set': StyledTextIconTag(
                      Icons.settings,
                      size: 30,
                      color: Colors.white,
                    ),
                  },
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                ),
              ),
              // DropdownButton<String>(
              //   items: [
              //     DropdownMenuItem(value: "en", child: Text("English")),
              //     DropdownMenuItem(value: "ja", child: Text("日本語")),
              //   ],
              //   onChanged: (value) {
              //     widget.onLanguageChanged(value!);
              //   },
              // ),
              ListTile(
                title: Text("日本語"),
                onTap: (){
                  s = '18桁以下の正整数を入力してください';
                  e = s;
                  Navigator.pop(context);
                  main();
                },
              ),
              ListTile(
                title: Text("English"),
                onTap: (){
                  s = "Please enter the number less than 18 digits.";
                  e = s;
                  Navigator.pop(context);
                  main();
                },
              ),
            ],
          ),
        ),
        body: Center(
          child:MyWidget(),
        ),
      ),
    );
  }
}

class MyWidget extends StatefulWidget {
  @override
  _MyWidgetState createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  int count = 0;
  bool b = true;


  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        TextField(
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: TextStyle(fontSize: 25),
          textAlign: TextAlign.center,
          maxLength: 18,
          onChanged: (text){
            try{
              count = int.parse(text);
              b = true;
            }catch(exception){
              b = false;
            }
          },
        ),
        ElevatedButton(
          onPressed: () {
            setState(() {
              if(b)s = pri_fact(count, context);
              else s = e;
            });
          },
          child: Text(AppLocalizations.of(context)!.button,
            style: TextStyle(fontSize: 20),
          ),
        ),
        SizedBox(
          height: 50,//間隔を空ける
        ),
        FittedBox(
          fit: BoxFit.fitWidth,
          child: Text(s,
            style: TextStyle(fontSize: 20),
          ),
        ),
      ],
    );
  }
}