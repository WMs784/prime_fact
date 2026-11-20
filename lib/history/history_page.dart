import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:prime_fact/calculator/trivia.dart';
import 'package:prime_fact/format/number_style.dart';
import 'package:prime_fact/format/spoken.dart';
import 'package:prime_fact/history/history_entry.dart';
import 'package:prime_fact/l10n/app_localizations.dart';

/// 保存データから、現在の言語で結果の表示行を組み立てる。
List<String> _describe(AppLocalizations loc, HistoryEntry entry) {
  final n = BigInt.tryParse(entry.input) ?? BigInt.zero;
  final header = '${entry.input}${headerFor(loc, n)}';
  final factors = entry.factors;
  return factors == null ? [header] : [header, '${entry.input}=$factors'];
}

class HistoryPage extends StatefulWidget {
  const new({
    required this.history,
    super.key,
    this.numberStyle = NumberStyle.plain,
  });
  final List<HistoryEntry> history;

  final NumberStyle numberStyle;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  /// 新しい順。
  late final List<HistoryEntry> _reversed = widget.history.reversed.toList();

  /// 行ごとの表示文（整形前）。見出しの導出は素数判定を伴い、30 桁では重いので、
  /// スクロールで再び表示されるたびに計算し直さないよう、初めて表示したときに覚える。
  final _described = <int, List<String>>{};
  String? _describedLocale;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final numberStyle = widget.numberStyle;
    final reversed = _reversed;
    // 言語が変わったら文言が変わるので、覚えた表示文は捨てる
    if (_describedLocale != loc.localeName) {
      _described.clear();
      _describedLocale = loc.localeName;
    }
    final dateFormat = DateFormat.yMd(loc.localeName).add_Hm();

    return Scaffold(
      appBar: AppBar(title: Text(loc.historyTitle)),
      body: reversed.isEmpty
          ? Center(child: Text(loc.historyEmpty))
          : ListView.builder(
              itemCount: reversed.length,
              itemBuilder: (context, index) {
                final entry = reversed[index];
                final raw = _described[index] ??= _describe(loc, entry);
                final lines = raw
                    .map((l) => formatForLocale(loc, l, numberStyle))
                    .toList();
                final dateStr = dateFormat.format(entry.timestamp);
                final spoken = spokenResult(
                  loc,
                  raw.join('\n'),
                  numberStyle: numberStyle,
                );

                return Semantics(
                  label: '$spoken${loc.spokenLineSeparator}$dateStr',
                  excludeSemantics: true,
                  child: ListTile(
                    title: Text(lines[0]),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (lines.length > 1) Text(lines[1]),
                        Text(
                          dateStr,
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                    isThreeLine: lines.length > 1,
                  ),
                );
              },
            ),
    );
  }
}
