import 'package:flutter_test/flutter_test.dart';
import 'package:prime_fact/judge.dart';

const _notPrime = ' NP';
const _prime = ' P';

String run(String n) => pri_fact_isolate([BigInt.parse(n), _notPrime, _prime]);

/// "n NP\nn=factors" 形式の結果から因数分解部分だけを取り出す。
String factorsOf(String n) {
  final out = run(n);
  expect(out, startsWith('$n$_notPrime\n$n='), reason: 'n=$n out=$out');
  return out.split('=').last;
}

void main() {
  group('pri_fact_isolate: trivial inputs', () {
    test('0 and 1 are neither prime nor factorable', () {
      expect(run('0'), '0$_notPrime');
      expect(run('1'), '1$_notPrime');
    });

    test('negative numbers are treated as not prime', () {
      expect(run('-7'), '-7$_notPrime');
    });
  });

  group('pri_fact_isolate: Grothendieck prime (57)', () {
    const g = ' G';
    String runG(String n) =>
        pri_fact_isolate([BigInt.parse(n), _notPrime, _prime, g]);

    test('57 gets the joke header but keeps its factorization', () {
      expect(runG('57'), '57$g\n57=3x19');
    });

    test('neighbouring numbers are unaffected', () {
      expect(runG('56'), startsWith('56$_notPrime'));
      expect(runG('58'), startsWith('58$_notPrime'));
      expect(runG('59'), '59$_prime');
    });

    test('57 is plain composite when no joke string is given', () {
      expect(run('57'), '57$_notPrime\n57=3x19');
    });
  });

  group('pri_fact_isolate: primality', () {
    test('small primes', () {
      for (final p in [2, 3, 5, 7, 11, 13, 97, 997, 1009, 7919]) {
        expect(run('$p'), '$p$_prime', reason: 'p=$p');
      }
    });

    test('large primes', () {
      for (final p in [
        '1000000007',
        '998244353',
        '2305843009213693951', // 2^61 - 1
        '618970019642690137449562111', // 2^89 - 1
      ]) {
        expect(run(p), '$p$_prime', reason: 'p=$p');
      }
    });

    test('Carmichael numbers are detected as composite', () {
      for (final c in [561, 1105, 1729, 2465, 2821, 6601, 8911]) {
        expect(run('$c'), startsWith('$c$_notPrime'), reason: 'c=$c');
      }
    });

    test('strong pseudoprimes to many bases are detected as composite', () {
      // 3825123056546413051 は底 2..23 の強擬素数
      expect(factorsOf('3825123056546413051'), '149491x747451x34233211');
      // 底 2..41 の強擬素数
      expect(
        factorsOf('318665857834031151167461'),
        '399165290221x798330580441',
      );
    });
  });

  group('pri_fact_isolate: factorization', () {
    test('small composites', () {
      expect(factorsOf('4'), '2^2');
      expect(factorsOf('6'), '2x3');
      expect(factorsOf('12'), '2^2x3');
      expect(factorsOf('100'), '2^2x5^2');
      expect(factorsOf('360'), '2^3x3^2x5');
      expect(factorsOf('1001'), '7x11x13');
    });

    test('factors are sorted ascending with exponents', () {
      expect(factorsOf('2310'), '2x3x5x7x11');
      expect(factorsOf('${4 * 343 * 961}'), '2^2x7^3x31^2');
    });

    test('prime powers', () {
      expect(factorsOf('1125899906842624'), '2^50');
      expect(factorsOf('3486784401'), '3^20');
      expect(factorsOf('1000000014000000049'), '1000000007^2');
    });

    test('trial-division boundary (primes around 1000)', () {
      expect(factorsOf('${997 * 1009}'), '997x1009');
      expect(factorsOf('${1009 * 1013}'), '1009x1013');
    });

    test('semiprime of two ~10-digit primes', () {
      final n = BigInt.from(1000000007) * BigInt.from(998244353);
      expect(factorsOf(n.toString()), '998244353x1000000007');
    });

    test('~30-digit semiprime', () {
      final p = BigInt.parse('1000000000039');
      final q = BigInt.parse('1000000000000037');
      final n = p * q;
      expect(n.toString().length, greaterThanOrEqualTo(28));
      expect(factorsOf(n.toString()), '${p}x$q');
    });

    test('product of the factors reproduces the input', () {
      for (final n in [
        '123456789',
        '9876543210',
        '600851475143',
        '123456789012345678901234567890',
      ]) {
        final factors = factorsOf(n).split('x').map((t) {
          final parts = t.split('^');
          return BigInt.parse(parts[0])
              .pow(parts.length > 1 ? int.parse(parts[1]) : 1);
        });
        final product = factors.fold(BigInt.one, (a, b) => a * b);
        expect(product, BigInt.parse(n), reason: 'n=$n');
      }
    });
  });
}
