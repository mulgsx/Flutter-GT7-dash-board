import 'package:flutter/widgets.dart';
import 'la_colors.dart';

/// Lap Analyzer画面共通のテキストスタイル定義
/// Shared text styles for the Lap Analyzer screens
class LATextStyles {
  LATextStyles._();

  static const TextStyle label = TextStyle(
    fontSize: 12,
    color: LAColors.label,
  );
  static const TextStyle labelMedium = TextStyle(
    fontSize: 13,
    color: LAColors.label,
  );
  static const TextStyle value = TextStyle(
    fontSize: 14,
    color: LAColors.value,
  );
  static const TextStyle valueEmphasis = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
  );
  static const TextStyle heading = TextStyle(
    fontSize: 16,
    color: LAColors.value,
  );
  static const TextStyle bigNumber = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.bold,
  );
}
