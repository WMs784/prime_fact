import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:prime_fact/app/home_controller.dart';
import 'package:prime_fact/app/settings_repository.dart';
import 'package:prime_fact/format/number_style.dart';
import 'package:prime_fact/history/history_entry.dart';
import 'package:prime_fact/history/history_repository.dart';

class _History extends HistoryRepository {
  new(this.onLoad);
  final Future<List<HistoryEntry>> Function() onLoad;
  bool failSave = false;
  final saved = <List<String>>[];

  @override
  Future<List<HistoryEntry>> load() => onLoad();

  @override
  Future<void> save(List<HistoryEntry> history) async {
    if (failSave) throw Exception('save');
    saved.add(history.map((e) => e.input).toList());
  }
}

class _Settings extends SettingsRepository {
  final showDaily = Completer<bool>();
  final numberStyle = Completer<NumberStyle>();
  bool failSave = false;
  final savedShowDaily = <bool>[];
  final savedStyles = <NumberStyle>[];

  @override
  Future<bool> loadShowDaily() => showDaily.future;

  @override
  Future<NumberStyle> loadNumberStyle() => numberStyle.future;

  @override
  Future<void> saveShowDaily(bool value) async {
    if (failSave) throw Exception('save');
    savedShowDaily.add(value);
  }

  @override
  Future<void> saveNumberStyle(NumberStyle style) async {
    if (failSave) throw Exception('save');
    savedStyles.add(style);
  }
}

HistoryEntry _entry(String input) =>
    HistoryEntry(input: input, timestamp: DateTime.utc(2026));

void main() {
  late _Settings settings;

  HomeController make(_History history) {
    final c = HomeController(
      historyRepository: history,
      settingsRepository: settings,
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() => settings = _Settings());

  group('history', () {
    test('loads the saved history', () async {
      final c = make(_History(() async => [_entry('7')]));
      unawaited(c.load());
      await pumpEventQueue();
      expect(c.history.map((e) => e.input), ['7']);
    });

    test(
      'an entry added before loading is kept after the saved ones',
      () async {
        final loading = Completer<List<HistoryEntry>>();
        final repo = _History(() => loading.future);
        final c = make(repo);
        unawaited(c.load());

        final adding = c.addHistory(_entry('0'));
        await pumpEventQueue();
        // 読み込みが終わるまでは保存しない
        expect(repo.saved, isEmpty);
        expect(c.history.map((e) => e.input), ['0']);

        loading.complete([_entry('7')]);
        await adding;
        expect(c.history.map((e) => e.input), ['7', '0']);
        expect(repo.saved.last, ['7', '0']);
      },
    );

    test('is not saved when loading it failed', () async {
      final repo = _History(() => Future.error(StateError('unavailable')));
      final c = make(repo);
      unawaited(c.load());
      await c.addHistory(_entry('0'));
      expect(c.history.map((e) => e.input), ['0']);
      expect(repo.saved, isEmpty);
    });

    test('a failed save keeps the entry', () async {
      final repo = _History(() async => [])..failSave = true;
      final c = make(repo);
      unawaited(c.load());
      await c.addHistory(_entry('0'));
      expect(c.history.map((e) => e.input), ['0']);
    });

    test('cannot be changed from outside', () async {
      final c = make(_History(() async => []));
      unawaited(c.load());
      expect(() => c.history.add(_entry('1')), throwsUnsupportedError);
    });
  });

  group('settings', () {
    test('showDaily is null until loaded, then the saved value', () async {
      final c = make(_History(() async => []));
      unawaited(c.load());
      expect(c.showDaily, isNull);
      expect(c.showDailyOrDefault, isTrue);

      settings.showDaily.complete(false);
      await pumpEventQueue();
      expect(c.showDaily, isFalse);
      expect(c.showDailyOrDefault, isFalse);
    });

    test('numberStyle is plain until loaded, then the saved value', () async {
      final c = make(_History(() async => []));
      unawaited(c.load());
      expect(c.numberStyle, NumberStyle.plain);
      settings.numberStyle.complete(NumberStyle.comma);
      await pumpEventQueue();
      expect(c.numberStyle, NumberStyle.comma);
    });

    test('a change before loading finishes is not overwritten', () async {
      final c = make(_History(() async => []));
      unawaited(c.load());
      await c.setShowDaily(false);
      await c.setNumberStyle(NumberStyle.apostrophe);

      settings.showDaily.complete(true);
      settings.numberStyle.complete(NumberStyle.comma);
      await pumpEventQueue();
      expect(c.showDaily, isFalse);
      expect(c.numberStyle, NumberStyle.apostrophe);
      expect(settings.savedShowDaily, [false]);
      expect(settings.savedStyles, [NumberStyle.apostrophe]);
    });

    test('a failed save keeps the change', () async {
      settings.failSave = true;
      final c = make(_History(() async => []));
      unawaited(c.load());
      await c.setShowDaily(false);
      await c.setNumberStyle(NumberStyle.comma);
      expect(c.showDaily, isFalse);
      expect(c.numberStyle, NumberStyle.comma);
    });
  });

  test('stays silent after dispose', () async {
    final loading = Completer<List<HistoryEntry>>();
    final c = HomeController(
      historyRepository: _History(() => loading.future),
      settingsRepository: settings,
    );
    var notified = 0;
    c.addListener(() => notified++);
    final pending = c.load();
    c.dispose();
    loading.complete([_entry('7')]);
    settings.showDaily.complete(true);
    settings.numberStyle.complete(NumberStyle.plain);
    await pending;
    expect(notified, 0);
  });
}
