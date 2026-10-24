import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:prime_fact/l10n/app_localizations.dart';

String s = '18桁以下の正整数を入力してください';//デフォルトメッセージ
String e = '18桁以下の正整数を入力してください';
String message(String message, BuildContext context){
  if(message == '18桁以下の正整数を入力してください') return AppLocalizations.of(context)!.description;
  else return message;
}
int prime(int n){
  if(n <= 1)return 0;
  else if(n == 2)return 1;
  else if(n%2 == 0)return 2;
  else{
    for(int i = 3;i <= sqrt(n);i+=2){
      if(n%i == 0){
        return i;
      }
    }
    return 1;
  }
}
// args = [n, isNotPrimeStr, isPrimeStr]
// compute() から呼び出せるよう BuildContext を使わない形にしている
String pri_fact_isolate(List<dynamic> args){
  int n             = args[0] as int;
  String isNotPrime = args[1] as String;
  String isPrime    = args[2] as String;

  final fact = <int,int>{};
  int i = prime(n);
  String s = n.toString();
  String d = s + isNotPrime;
  if(i == 0)return d;
  else if(i == 1)return s + isPrime;
  int p;
  while((p = prime(n)) > 1){
    fact.update(p, (int value) => value+1, ifAbsent: () => 1);
    n ~/= p;
  }
  fact.update(n, (int value) => value+1, ifAbsent: () => 1);
  s += '=';
  fact.forEach((key,value){
    if(key == 1)s += '';
    else if(value == 1)s+= key.toString() + 'x';
    else s += key.toString() + '^' + value.toString() + 'x';
  });
  return d + '\n' + s.substring(0,s.length-1);
}