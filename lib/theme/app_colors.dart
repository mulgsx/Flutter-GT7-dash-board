import 'package:flutter/painting.dart';

/// アプリ共通のカラーパレット / Shared color palette for the app.
class AppColors {
  AppColors._();

  static const Color statusReceiving = Color(0xFF4CAF50);
  static const Color statusError = Color(0xFFE53935);
  static const Color statusConnecting = Color(0xFFFB8C00);
  static const Color statusIdle = Color(0xFF9E9E9E);

  // ---- HUD ダッシュボード用パレット / HUD dashboard palette ----
  static const Color surface0 = Color(0xFF0D0D0D); // page plane
  static const Color surface1 = Color(0xFF1A1A19); // card surface
  static const Color surface2 = Color(0xFF232322); // raised card surface
  static const Color hudTextPrimary = Color(0xFFFFFFFF);
  static const Color hudTextSecondary = Color(0xFFC3C2B7);
  static const Color hudTextMuted = Color(0xFF898781);
  static const Color hairline = Color(0x1AFFFFFF); // rgba(255,255,255,0.10)
  static const Color gridline = Color(0xFF2C2C2A);
  // 実機筐体を思わせるパネル外枠のトーン / Instrument-bezel tone for panel outer frames
  static const Color bezel = Color(0xFF3A3A37);

  // 数値表示に使う7セグメントLCD風フォント / Segment-LCD font family for numeric readouts
  static const String segmentFontFamily = 'DSEG7Classic';

  static const Color good = Color(0xFF0CA30C);
  static const Color goodBright = Color(0xFF22C522);
  static const Color warning = Color(0xFFFAB219);
  static const Color serious = Color(0xFFEC835A);
  static const Color critical = Color(0xFFD03B3B);
  static const Color criticalBright = Color(0xFFE66767);
  static const Color cold = Color(0xFF3987E5);
  static const Color unlitSegment = Color(0xFF2A2A28);
}
