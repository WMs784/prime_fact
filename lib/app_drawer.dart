import 'package:material_ui/material_ui.dart';
import 'package:prime_fact/history_entry.dart';
import 'package:prime_fact/history_page.dart';
import 'package:prime_fact/l10n/app_localizations.dart';
import 'package:prime_fact/language.dart';
import 'package:prime_fact/links.dart';
import 'package:prime_fact/number_style.dart';
import 'package:styled_text/styled_text.dart';

/// ドロワーのヘッダーの色。白い文字が読めるよう、明暗どちらのテーマでも濃い青緑にする。
final Color _drawerHeaderColor = Colors.teal.shade700;

/// ホームのドロワー（履歴・設定・アプリ情報）。状態は持たず、設定の変更は呼び出し側に任せる。
class MyDrawer extends StatelessWidget {
  const new({
    required this.history,
    required this.showDaily,
    required this.onShowDailyChanged,
    required this.numberStyle,
    required this.onNumberStyleChanged,
    required this.openUrl,
    super.key,
  });

  final List<HistoryEntry> history;

  /// 「今日の素因数分解」のバナーを表示するか。
  final bool showDaily;
  final ValueChanged<bool> onShowDailyChanged;
  final NumberStyle numberStyle;
  final ValueChanged<NumberStyle> onNumberStyleChanged;
  final UrlOpener openUrl;

  Future<void> _pickNumberStyle(BuildContext context) async {
    final loc = AppLocalizations.of(context)!;
    final ja = isJapanese(loc);
    final labels = {
      NumberStyle.plain: loc.numberFormatPlain,
      NumberStyle.comma: loc.numberFormatComma,
      NumberStyle.apostrophe: loc.numberFormatApostrophe,
      if (ja) NumberStyle.units: loc.numberFormatUnits,
    };
    final picked = await showDialog<NumberStyle>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(loc.numberFormat),
        children: [
          RadioGroup<NumberStyle>(
            groupValue: effectiveStyle(numberStyle, ja: ja),
            onChanged: (v) => Navigator.pop(context, v),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final e in labels.entries)
                  RadioListTile<NumberStyle>(
                    value: e.key,
                    title: Text(e.value),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    // ドロワーは開いたままにする（続けて他の設定を触れるように）
    if (picked != null && context.mounted) onNumberStyleChanged(picked);
  }

  /// ドロワーを閉じて外部リンクを開く。開けなければ知らせる。
  Future<void> _openLink(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final failedText = AppLocalizations.of(context)!.linkOpenFailed;
    Navigator.pop(context);
    var opened = false;
    try {
      opened = await openUrl(url);
    } catch (_) {
      // 開けなかった扱いにする
    }
    if (!opened) {
      messenger.showSnackBar(SnackBar(content: Text(failedText)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Drawer(
      child: ListView(
        children: <Widget>[
          DrawerHeader(
            decoration: BoxDecoration(color: _drawerHeaderColor),
            child: StyledText(
              text: '<set/>&space;${loc.settings}',
              style: const TextStyle(fontSize: 24, color: Colors.white),
              tags: const {
                'set': StyledTextIconTag(
                  Icons.settings,
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
                MaterialPageRoute<void>(
                  builder: (_) =>
                      HistoryPage(history: history, numberStyle: numberStyle),
                ),
              );
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.today),
            title: Text(loc.showDailyChallenge),
            value: showDaily,
            onChanged: onShowDailyChanged,
          ),
          ListTile(
            leading: const Icon(Icons.pin),
            title: Text(loc.numberFormat),
            subtitle: Text(switch (effectiveStyle(
              numberStyle,
              ja: isJapanese(loc),
            )) {
              NumberStyle.plain => loc.numberFormatPlain,
              NumberStyle.comma => loc.numberFormatComma,
              NumberStyle.apostrophe => loc.numberFormatApostrophe,
              NumberStyle.units => loc.numberFormatUnits,
            }),
            onTap: () => _pickNumberStyle(context),
          ),
          ExpansionTile(
            leading: const Icon(Icons.info_outline),
            title: Text(loc.appInfo),
            shape: const Border(),
            collapsedShape: const Border(),
            children: <Widget>[
              ListTile(
                title: Text(loc.privacyPolicy),
                onTap: () => _openLink(context, pagesUrl),
              ),
              ListTile(
                title: Text(loc.review),
                onTap: () => _openLink(context, playStoreUrl),
              ),
              ListTile(
                title: Text(loc.contact),
                onTap: () => _openLink(context, contactUrl),
              ),
              ListTile(
                title: Text(loc.aboutUs),
                onTap: () => _openLink(context, developerUrl),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
