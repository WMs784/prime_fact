import 'package:flutter/material.dart';
import 'judge.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {//MyWidgetの配置を決めるクラス
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
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
  String s = '18桁以下の数を入力してください';//デフォルトメッセージ
  // データを元にWidgetを作る
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        TextField(
          onChanged: (text){
            count = int.parse(text);//入力内容を文字列として取得
          },
        ),
        TextButton(
          onPressed: () {
            // データを更新する時は setState を呼ぶ
            setState(() {
              // データを更新
              s = pri_fact(count);//先ほど作った関数に入れて文字列を更新
            });
          },
          child: Text('素因数分解'),
        ),
        Text(s),//ここで表示
      ],
    );
  }
}