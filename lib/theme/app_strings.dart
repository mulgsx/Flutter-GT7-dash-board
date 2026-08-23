/// アプリ全体で共通の文言(接続設定Drawerなど、特定機能に閉じない箇所)。
/// Lap Analyzer機能専用の文言は LAStrings 側に置く
/// App-wide shared text (e.g. the connection-settings drawer, which isn't
/// scoped to any one feature). Lap Analyzer-specific text lives in LAStrings instead.
class AppStrings {
  AppStrings._();

  // ---- 接続設定Drawer / Connection settings drawer ----
  static const String ipSettingsTitle = 'IP設定';
  static const String ps5IpAddressLabel = 'PS5 IP Address';
  static const String ipAddressHint = 'ex: 192.168.0.50';
  static const String revWarningRpmLabel = 'Rev Warning RPM';
  static const String revWarningRpmHint = 'ex: 6800';
  static const String connectToGt7First = 'Connect to GT7 first';
  static const String startReceiving = 'Start Receiving';
  static const String stopReceiving = 'Stop Receiving';
  static String statusLabel(String status) => 'Status: $status';
}
