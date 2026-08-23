import 'package:flutter/material.dart';

/// Lap Analyzer画面共通のテキストボタン(TextButtonラッパー)
/// Shared text button for the Lap Analyzer screens (wraps TextButton)
class LATextButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final TextStyle? style;

  const LATextButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: Text(label, style: style),
    );
  }
}
