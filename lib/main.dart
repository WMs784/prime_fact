import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'judge.dart';

void main() => runApp(MyApp());

/*<color name="teal_200">#FF03DAC5</color>
<color name="teal_700">#FF018786</color>*/
//const int _kPurplePrimaryValue = ;

class MyApp extends StatelessWidget {//MyWidgetの配置を決めるクラス
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.teal,
        primaryColor: Colors.teal[700],
        accentColor: Colors.teal[300],
        focusColor: Colors.teal[200],
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.teal,
        primaryColor: Colors.teal[700],
        accentColor: Colors.teal[300],
        focusColor: Colors.teal[200],
      ),
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: Text("素因数分解計算機"),//上部のバーに表示される
        ),
        body: Center(
            child:MyWidget(),
        ),
      ),
    );
  }
}

// StatefulWidgetを継承するとStateを扱える
// このWidgetを表示すると、Stateを元にUIが作成される
class MyWidget extends StatefulWidget {
  // 使用するStateを指定
  @override
  _MyWidgetState createState() => _MyWidgetState();
}

// Stateを継承して使う
class _MyWidgetState extends State<MyWidget> {
  // データを宣言
  int count = 0;
  bool b = true;
  String s = '18桁以下の正整数を入力してください';//デフォルトメッセージ
  String e = '18桁以下の正整数を入力してください';
  // データを元にWidgetを作る
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        TextField(
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          //controller: _textEditingController,
          style: TextStyle(fontSize: 25),
          textAlign: TextAlign.center,
          maxLength: 18,
          maxLengthEnforced: false,
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
            // データを更新する時は setState を呼ぶ
            setState(() {
              // データを更新
              //_textEditingController.clear();
              if(b)s = pri_fact(count);//先ほど作った関数に入れて文字列を更新
              else s = e;
              //TextField text = '';
            });
          },
          child: Text('素因数分解',
            style: TextStyle(fontSize: 20),
          ),
        ),
        /*Text(s,
          style: TextStyle(fontSize: 20),
        ),*///ここで表示
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