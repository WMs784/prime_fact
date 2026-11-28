import 'package:prime_fact/calculator/factorization.dart';

/// `fact('60', '2^2x3x5')` のように記法から作る。素数・1 以下は [notation] を省く。
Factorization fact(String n, [String? notation]) =>
    Factorization.fromNotation(BigInt.parse(n), notation);
