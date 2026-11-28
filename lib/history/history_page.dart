import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:prime_fact/calculator/trivia.dart';
import 'package:prime_fact/format/number_style.dart';
import 'package:prime_fact/format/result_text.dart';
import 'package:prime_fact/format/spoken.dart';
import 'package:prime_fact/history/history_entry.dart';
import 'package:prime_fact/l10n/app_localizations.dart';

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

  /// 行ごとの豆知識（なければ null）。導出は素数判定を伴い、30 桁では重いので、
  /// スクロールで再び表示されるたびに計算し直さないよう、初めて表示したときに覚える。
  /// 言語には依存しないので、言語が変わっても覚えたままでよい。
  final _trivia = <int, Trivia?>{};

  Trivia? _triviaAt(int index, BigInt n) => _trivia.containsKey(index)
      ? _trivia[index]
      : (_trivia[index] = triviaFor(n));

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final numberStyle = widget.numberStyle;
    final reversed = _reversed;
    final dateFormat = DateFormat.yMd(loc.localeName).add_Hm();

    return Scaffold(
      appBar: AppBar(title: Text(loc.historyTitle)),
      body: reversed.isEmpty
          ? Center(child: Text(loc.historyEmpty))
          : ListView.builder(
              itemCount: reversed.length,
              itemBuilder: (context, index) {
                final entry = reversed[index];
                final f = entry.factorization;
                final trivia = _triviaAt(index, f.n);
                final lines = resultLines(loc, f, trivia, numberStyle);
                final dateStr = dateFormat.format(entry.timestamp);
                final spoken = spokenResult(
                  loc,
                  f,
                  trivia,
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
