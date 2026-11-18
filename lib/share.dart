import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

/// 共有の結果。
enum ShareOutcome {
  /// 共有シートを開いた（共有したか閉じたかは判別しない）。
  sheet,

  /// 共有シートを持たない環境のため、クリップボードにコピーした。
  copied,
}

/// 共有シートで共有する。共有シートを持たない環境（プラグイン未実装）のときだけ、
/// クリップボードにコピーして [ShareOutcome.copied] を返す。
///
/// `ShareResultStatus.unavailable` は「共有の成否を判別できない」という意味で、
/// Android・Windows・Web では共有に成功しても返るので、コピーの理由にしてはいけない。
/// それ以外の失敗は例外のまま呼び出し側に伝える。
/// [origin] は iPad の共有ポップオーバーの基準位置。
Future<ShareOutcome> shareText(
  String text,
  Rect? origin, {
  Future<ShareResult> Function(ShareParams)? share,
}) async {
  try {
    await (share ?? SharePlus.instance.share)(
      ShareParams(text: text, sharePositionOrigin: origin),
    );
    return ShareOutcome.sheet;
  } on MissingPluginException {
    await Clipboard.setData(ClipboardData(text: text));
    return ShareOutcome.copied;
  } on UnimplementedError {
    await Clipboard.setData(ClipboardData(text: text));
    return ShareOutcome.copied;
  }
}

/// [context]（共有ボタンの `Builder` の中など）のウィジェットの画面上の位置。
/// iPad の共有ポップオーバーの基準位置（[shareText] の `origin`）に渡す。
Rect? originOf(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  return box == null ? null : box.localToGlobal(Offset.zero) & box.size;
}
