// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get title => 'Prime Factorizationer';

  @override
  String get info => 'App Info';

  @override
  String get button => 'calculate';

  @override
  String get description =>
      'Please enter a positive integer of 18 digits or less';

  @override
  String get isPrime => ' is a prime number!';

  @override
  String get isNotPrime => ' is not a prime number';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get review => 'Review This App';

  @override
  String get contact => 'Contact Us';

  @override
  String get aboutUs => 'About Us';
}
