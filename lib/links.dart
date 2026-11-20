import 'package:url_launcher/url_launcher_string.dart';

/// アプリから参照する外部リンク。
const pagesUrl = 'https://wms784.github.io/prime_fact/';
const webAppUrl = '${pagesUrl}app/';
const playStoreUrl =
    'https://play.google.com/store/apps/details?id=project.My_prime_nember';
const contactUrl = 'https://forms.gle/YvXNAPHupB1wJFCR8';
const developerUrl =
    'https://play.google.com/store/apps/dev?id=6078644560561044674';

/// 外部 URL を開く。開けたら true。
typedef UrlOpener = Future<bool> Function(String url);

Future<bool> defaultUrlOpener(String url) => launchUrlString(url);
