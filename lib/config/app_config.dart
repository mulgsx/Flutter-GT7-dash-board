const int receivePort = 33740;
const int sendPort = 33739;
const String defaultIp = '192.168.0.0';
const String prefIpKey = 'gt7_ps5_ip';

// car_id ごとに手動設定した rev warning RPM を保存するキーの接頭辞
// Prefix for the per-car_id manual rev-warning override storage key
const String prefRevWarningKeyPrefix = 'gt7_rev_warning_';

// 車ごとに異なるキーで保存/読込するためのヘルパー
// Builds a car_id-scoped SharedPreferences key
String revWarningPrefKey(int carId) => '$prefRevWarningKeyPrefix$carId';
