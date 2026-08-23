import 'package:flutter/material.dart';
import 'package:gt7_trj_log/theme/la_colors.dart';

/// Lap Analyzer画面共通の主要アクションボタン(ElevatedButtonラッパー)。
/// 見た目を変えたいときはここだけ直せばよい
/// Shared primary-action button for the Lap Analyzer screens (wraps
/// ElevatedButton) — change the look in one place here.
class LAButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  // データ未読み込みなどで「非活性に見せたいが、タップ自体は受け付けたい」場合に
  // true にする(案内ダイアログを出すため、onPressed は null にしない運用を想定)
  // Set true when the button should *look* disabled (e.g. data not loaded
  // yet) while still accepting taps — typically so the tap can show a
  // guidance dialog, so onPressed usually stays non-null in that case.
  final bool looksDisabled;

  const LAButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.looksDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: looksDisabled
          ? ElevatedButton.styleFrom(
              backgroundColor: LAColors.disabledBackground,
              foregroundColor: LAColors.disabledForeground,
              elevation: 0,
            )
          : null,
      child: Text(label, textAlign: TextAlign.center),
    );
  }
}
