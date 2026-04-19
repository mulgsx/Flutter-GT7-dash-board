# GT7 Dashboard - Claude Code ガイドライン

## プロジェクト情報

- **言語**: Dart (Flutter)
- **ターゲット**: iOS / Android（横向き）
- **目的**: Gran Turismo 7 テレメトリー表示ダッシュボード
- **特徴**: AC ダッシュボードと統一設計

## ファイル配置ルール

### 1. モデル層 (`lib/models/`)
```dart
// lib/models/gt7_models.dart

class GT7Decoder {
  // 静的メソッド: Salsa20デコード
  static Uint8List decodeSalsa20(Uint8List encryptedData) { ... }
  static double getFloat(Uint8List decoded, int offset) { ... }
}

class GT7Packet {
  // データクラス: パケット構造
  final double speedKmh;
  final double engineRPM;
  final int gear;
  
  factory GT7Packet.fromBytes(Uint8List bytes) { ... }
}

// 定数
const int gt7MagicNumber = 0x47375330;
final Uint8List gt7KeyBytes = ...;
```

### 2. サービス層 (`lib/services/`)
```dart
// lib/services/gt7_telemetry_service.dart

class GT7TelemetryService {
  // 状態管理
  final ValueNotifier<double> rpmNotifier = ValueNotifier(0.0);
  final ValueNotifier<String> statusNotifier = ValueNotifier('IDLE');
  
  // メソッド
  Future<void> startListening(String targetIp) async { ... }
  void stopListening() { ... }
  void _handlePacket(Uint8List rawData) { ... }
}
```

### 3. ウィジェット層 (`lib/widgets/`)
```dart
// AC と共通: telemetry_drawer_widget.dart, rpm_display_widget.dart
// GT7固有: なし（全て共通化）
```

### 4. 画面層 (`lib/screens/`)
```dart
// AC と共通: telemetry_screen.dart
```

### 5. 設定層 (`lib/config/`)
```dart
// lib/config/app_config.dart

class GT7Config {
  static const int receivePort = 33740;
  static const int sendPort = 33739;
  static const String defaultIp = '192.168.0.0';
  static const String prefKey = 'gt7_ps5_ip';
}
```

## 命名規則

| 対象 | ルール | 例 |
|------|--------|-----|
| ファイル | `snake_case` | `gt7_models.dart` |
| クラス | `PascalCase` | `GT7Decoder` |
| メソッド | `camelCase` | `decodeSalsa20()` |
| 定数 | `camelCase` または `SCREAMING_SNAKE_CASE` | `gt7MagicNumber` |
| Notifier | `[名詞]Notifier` | `rpmNotifier` |

## StateManagement パターン

```dart
// ✅ 推奨: ValueNotifier + ValueListenableBuilder
final rpmNotifier = ValueNotifier<double>(0.0);

ValueListenableBuilder<double>(
  valueListenable: rpmNotifier,
  builder: (_, rpm, __) => Text('$rpm RPM'),
)

// ❌ 避ける: setState の多用
```

## エラーハンドリング

```dart
// ✅ 推奨: log + status notifier
try {
  final data = decodeSalsa20(rawData);
  if (data.isEmpty) {
    statusNotifier.value = 'ERROR: Decryption failed';
    return;
  }
} catch (e) {
  print('[ERROR] ${e}');
  statusNotifier.value = 'ERROR: ${e}';
}
```

## リソース管理

```dart
// ✅ 推奨: 一箇所に集約
void _stopAll() {
  _socket?.close();
  _heartbeatTimer?.cancel();
  _displayTimer?.cancel();
}

@override
void dispose() {
  _stopAll();
  super.dispose();
}
```

## ログ出力規則

```dart
print('[LOG] Connection started');      // ✅ 正常系
print('[DEBUG] Packet size: 296');      // ℹ️ デバッグ情報
print('[ERROR] Failed to bind: $e');    // ❌ エラー
```

## テーマング

```dart
// AC と共通: 同じカラースキーム
Colors.green.shade700   // 正常
Colors.red.shade700     // エラー
Colors.orange.shade700  // 警告
```

## 構成チェックリスト

- [ ] `lib/config/app_config.dart` に定数を集約
- [ ] `lib/models/gt7_models.dart` にクラス定義
- [ ] `lib/services/gt7_telemetry_service.dart` にロジック
- [ ] `lib/screens/telemetry_screen.dart` は AC と共通
- [ ] `lib/widgets/` は全て共通（GT7固有なし）
- [ ] `main.dart` は最小限（System設定のみ）
- [ ] エラーメッセージは `statusNotifier` で表示
- [ ] ログには `[LOG]`, `[ERROR]`, `[DEBUG]` プリフィクス