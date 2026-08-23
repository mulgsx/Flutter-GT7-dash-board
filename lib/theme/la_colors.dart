import 'package:flutter/painting.dart';

/// Lap Analyzer機能(ホーム/キャプチャ/オフライン比較/リアルタイム比較)で共通の
/// 明るく視認性の高いメーター向けカラーパレット。ダッシュボード(HUD)画面は
/// 別の暗色パレット(AppColors)を使うため、ここでは変更しない
/// The bright, high-visibility "meter" color palette shared across the Lap
/// Analyzer screens (home / capture / offline compare / realtime compare).
/// The dashboard (HUD) screen uses its own dark palette (AppColors) and is
/// intentionally not touched here.
class LAColors {
  LAColors._();

  static const Color background = Color(0xFFEFF1F4);
  static const Color panelBackground = Color(0xFFFFFFFF);
  static const Color appBarBackground = Color(0xFFFFFFFF);
  static const Color appBarForeground = Color(0xDD000000); // Colors.black87と同じ値 / same value as Colors.black87

  static const Color label = Color(0xFF6B7280);
  static const Color value = Color(0xFF1F2430);

  // 自分が速い/良い方向 / self is faster or better
  static const Color good = Color(0xFF1E8E3E);
  // 自分が遅い/悪い方向 / self is slower or worse
  static const Color bad = Color(0xFFD93025);

  static const Color targetBar = Color(0xFFC7CBD1);
  static const Color throttle = Color(0xFF1E8E3E);
  static const Color brake = Color(0xFFD93025);
  static const Color selfDot = Color(0xFF1A73E8);
  // 自分と対象の差を強調する色 / Highlights the gap between self and target
  static const Color gapHighlight = Color(0xFFF9A825);
  // バー/ライン表示の下地 / Backing track for bars and the line-position indicator
  static const Color trackBase = Color(0xFFE4E6EA);

  static const Color disabledBackground = Color(0xFFE0E0E0); // Colors.grey.shade300相当
  static const Color disabledForeground = Color(0xFF757575); // Colors.grey.shade600相当
}
