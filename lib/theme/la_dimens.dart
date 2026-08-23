/// Lap Analyzer画面共通のサイズ定義(パネルの角丸・余白・間隔など)。
/// ここを変えるだけで全画面のスペーシングが揃う
/// Shared sizing constants for the Lap Analyzer screens (panel corner radius,
/// padding, gaps). Changing values here keeps spacing consistent everywhere.
class LADimens {
  LADimens._();

  static const double panelRadius = 14;
  static const double barRadius = 6;
  static const double lineIndicatorRadius = 10;

  static const double screenPadding = 12;
  static const double appBarElevation = 1;

  static const double gapXSmall = 4;
  static const double gapSmall = 8;
  static const double gapMedium = 12;
  static const double gapLarge = 16;
  static const double gapXLarge = 20;
  static const double gapXXLarge = 32;
}
