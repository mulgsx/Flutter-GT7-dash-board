import 'package:flutter/material.dart';

/// Lap Analyzer画面共通の副次アクションボタン(OutlinedButtonラッパー)
/// Shared secondary-action button for the Lap Analyzer screens (wraps
/// OutlinedButton)
class LASecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const LASecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      child: Text(label, textAlign: TextAlign.center),
    );
  }
}
