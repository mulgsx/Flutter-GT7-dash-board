import 'package:flutter/material.dart';
import 'package:gt7_trj_log/theme/la_strings.dart';

/// アプリ共通の確認/案内ダイアログ。個々の画面でAlertDialogを書き並べる代わりに
/// これを使うことで、文言や見た目の変更を1箇所で行えるようにする
/// Shared confirmation / info dialog for the app. Using this instead of an
/// inline AlertDialog in every screen keeps wording and look changes to one place.
class LAConfirmDialog {
  LAConfirmDialog._();

  /// キャンセル/確認の2択ダイアログ。確認が選ばれた場合のみ true を返す
  /// A cancel/confirm two-choice dialog. Returns true only when confirmed.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String cancelLabel = LAStrings.cancel,
    String confirmLabel = LAStrings.ok,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// OKのみの案内ダイアログ / An OK-only informational dialog
  static Future<void> showInfo(
    BuildContext context, {
    required String title,
    required String message,
    String okLabel = LAStrings.ok,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(okLabel),
          ),
        ],
      ),
    );
  }
}
