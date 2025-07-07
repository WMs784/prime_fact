import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:styled_text/styled_text.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

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
                  text: '<set/>&space;'+AppLocalizations.of(context)!.info,
                  style: TextStyle(
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
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                ),
              ),
              ListTile(
                title: Text(AppLocalizations.of(context)!.privacyPolicy),
                onTap: (){
                  launchUrlString("https://wms784.github.io/prime_fact/");
                },
              ),
              ListTile(
                title: Text(AppLocalizations.of(context)!.review),
                onTap: (){
                  launchUrlString("https://play.google.com/store/apps/details?id=project.My_prime_nember");
                },
              ),
              ListTile(
                title: Text(AppLocalizations.of(context)!.contact),
                onTap: (){
                  launchUrlString("https://forms.gle/YvXNAPHupB1wJFCR8");
                },
              ),
              ListTile(
                title: Text(AppLocalizations.of(context)!.aboutUs),
                onTap: (){
                  launchUrlString("https://play.google.com/store/apps/dev?id=6078644560561044674");
                },
              )
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
          child: Text(message(s, context),
            style: TextStyle(fontSize: 20),
          ),
        ),
      ],
    );
  }
}