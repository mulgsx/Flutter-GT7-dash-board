# GT7 Dashboard - File Structure Specification
# GT7 ダッシュボード - ファイル構造仕様書

## Directory Structure
## ディレクトリ構成
Flutter-GT7-dash-board/
├── lib/
│   ├── main.dart                         # Application entry point / アプリケーションエントリーポイント
│   ├── config/
│   │   └── app_config.dart              # Constants and configuration / 定数・設定
│   ├── models/
│   │   └── gt7_models.dart              # Data structures and decoders / データ構造・デコード処理
│   ├── services/
│   │   └── gt7_telemetry_service.dart   # UDP communication and business logic / UDP通信・ビジネスロジック
│   ├── widgets/
│   │   ├── telemetry_drawer_widget.dart # Settings menu drawer / 設定メニュー
│   │   ├── rpm_display_widget.dart      # RPM display component / RPM表示コンポーネント
│   │   └── packet_info_widget.dart      # Packet info display / パケット情報表示
│   └── screens/
│       └── telemetry_screen.dart        # Main screen layout / メイン画面
├── pubspec.yaml
├── FILE_STRUCTURE.md                     # This file / このファイル
└── .claude/
└── CLAUDE.md                         # Development guidelines for Claude Code / Claude Code 開発ガイド

---

## File Roles and Responsibilities
## 各ファイルの役割と責務

### `lib/main.dart`
| Aspect | Details |
|--------|---------|
| **Purpose** | Initialize system settings and app lifecycle management |
| **目的** | システム設定とアプリケーションライフサイクル管理 |
| **Contains** | `void main()`, `GT7DashboardApp`, `TelemetryAppScreen` |
| **Responsibility** | System UI mode, orientation, app entry / システムUI、画面向き、アプリ開始 |
| **Key Methods** | `initState()`, `dispose()` |

### `lib/config/app_config.dart`
| Aspect | Details |
|--------|---------|
| **Purpose** | Centralize all constants and configuration values |
| **目的** | 全ての定数・設定値を一元管理 |
| **Contains** | `class GT7Config` with static constants |
| **Constants** | `receivePort`, `sendPort`, `defaultIp`, `prefKey` |
| **Example** | `static const int receivePort = 33740;` |

### `lib/models/gt7_models.dart`
| Aspect | Details |
|--------|---------|
| **Purpose** | Define data structures and decryption logic |
| **目的** | データ構造と暗号化処理の定義 |
| **Contains** | `GT7Decoder`, `GT7Packet` classes |
| **Key Methods** | `decodeSalsa20()`, `fromBytes()`, `getFloat()` |
| **Constants** | `gt7MagicNumber`, `gt7KeyBytes`, `rpmOffset` |

**Classes:**

#### `class GT7Decoder`
```dart
// Static methods for packet decryption and data extraction
// パケット復号化とデータ抽出用の静的メソッド

static Uint8List decodeSalsa20(Uint8List encryptedData)
  // Decrypt Salsa20-encrypted GT7 packet
  // Salsa20暗号化されたGT7パケットを復号化

static double getFloat(Uint8List decoded, int offset)
  // Extract float value from decoded packet at specified offset
  // 復号化されたパケットから指定オフセットの浮動小数点値を抽出
```

#### `class GT7Packet`
```dart
// Data class representing GT7 telemetry packet structure
// GT7テレメトリーパケット構造を表現するデータクラス

final double speedKmh;
final double engineRPM;
final int gear;
final double gas;
final double brake;
final int lapTime;

factory GT7Packet.fromBytes(Uint8List bytes)
  // Parse raw packet bytes into GT7Packet instance
  // 生パケットをGT7Packetインスタンスに解析
```

### `lib/services/gt7_telemetry_service.dart`
| Aspect | Details |
|--------|---------|
| **Purpose** | Handle UDP communication, packet processing, and state management |
| **目的** | UDP通信・パケット処理・状態管理 |
| **Contains** | `class GT7TelemetryService` |
| **Responsibility** | Socket binding, heartbeat, IP validation, SharedPreferences |
| **責務** | ソケットバインド、ハートビート、IP検証、SharedPreferences |

**Key Methods:**

```dart
class GT7TelemetryService {
  // ===== State Notifiers / 状態Notifier =====
  final ValueNotifier<double> rpmNotifier;
  final ValueNotifier<int> packetCountNotifier;
  final ValueNotifier<String> statusNotifier;
  final ValueNotifier<String> currentIpNotifier;

  // ===== Lifecycle / ライフサイクル =====
  Future<void> startListening(String targetIp)
    // Bind UDP socket and begin listening for packets
    // UDPソケットをバインドしてパケット受信を開始

  void stopListening()
    // Stop listening and clean up resources
    // リスニング停止とリソース解放

  Future<void> loadSavedIp()
    // Load IP address from SharedPreferences
    // SharedPreferencesからIP アドレスをロード

  Future<void> saveIp(String ip)
    // Save IP address to SharedPreferences
    // IPアドレスをSharedPreferencesに保存

  // ===== Internal / 内部処理 =====
  void _handlePacket(Datagram datagram)
    // Decrypt and parse received packet
    // 受信パケットを復号化・解析

  Future<void> _sendHeartbeat()
    // Send heartbeat signal to PS5
    // PS5にハートビート信号を送信

  bool isValidIp(String ip)
    // Validate IPv4/IPv6 format
    // IPv4/IPv6フォーマットを検証

  void _stopAll()
    // Cleanup all resources in one place
    // 全リソースを一箇所で解放

  void dispose()
    // Dispose notifiers and close service
    // Notifierを破棄してサービスを終了
}
```

### `lib/widgets/telemetry_drawer_widget.dart`
| Aspect | Details |
|--------|---------|
| **Purpose** | Provide settings menu drawer UI |
| **目的** | 設定メニューDrawer UIの提供 |
| **Contains** | `class TelemetryDrawer extends StatelessWidget` |
| **Components** | IP input field, start/stop button, status display |
| **コンポーネント** | IP入力フィールド、開始/停止ボタン、ステータス表示 |

```dart
class TelemetryDrawer extends StatelessWidget {
  final TextEditingController ipController;      // IP address input
  final bool isListening;                        // Connection state
  final VoidCallback onStart;                    // Start listening callback
  final VoidCallback onStop;                     // Stop listening callback
  final int packetCount;                         // Received packet count
  final String status;                           // Connection status message
}
```

### `lib/widgets/rpm_display_widget.dart`
| Aspect | Details |
|--------|---------|
| **Purpose** | Display RPM value with ValueListenableBuilder |
| **目的** | RPM値をValueListenableBuilderで表示 |
| **Contains** | `class RpmDisplay extends StatelessWidget` |
| **Updates** | Real-time RPM display from `rpmNotifier` |
| **更新** | `rpmNotifier`からリアルタイムRPM表示 |

```dart
class RpmDisplay extends StatelessWidget {
  final ValueNotifier<double> rpmNotifier;       // RPM state notifier

  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: rpmNotifier,
      builder: (_, rpm, __) => Text(
        '${rpm.toStringAsFixed(0)} RPM',
        style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
      ),
    );
  }
}
```

### `lib/widgets/packet_info_widget.dart`
| Aspect | Details |
|--------|---------|
| **Purpose** | Display packet reception statistics |
| **目的** | パケット受信統計の表示 |
| **Contains** | Packet count, sender IP, connection status |
| **更新** | Multiple ValueListenableBuilder for reactive updates |

### `lib/screens/telemetry_screen.dart`
| Aspect | Details |
|--------|---------|
| **Purpose** | Compose main screen layout combining all widgets |
| **目的** | 全ウィジェットを組み合わせたメイン画面レイアウト |
| **Contains** | `class TelemetryScreen extends StatefulWidget` |
| **Layout** | Scaffold with AppBar, Drawer, and Body |
| **レイアウト** | Scaffold（AppBar、Drawer、Body） |

```dart
class TelemetryScreen extends StatefulWidget {
  final GT7TelemetryService service;

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: 'GT7 Dashboard'),
      drawer: TelemetryDrawer(...),
      body: SafeArea(
        child: Column(
          children: [
            RpmDisplay(rpmNotifier: service.rpmNotifier),
            PacketInfoWidget(...),
          ],
        ),
      ),
    );
  }
}
```

---

## Naming Conventions
## 命名規則

| Category | Convention | Example |
|----------|-----------|---------|
| **Files** | snake_case | `gt7_telemetry_service.dart` |
| **Classes** | PascalCase | `GT7TelemetryService` |
| **Methods** | camelCase | `startListening()` |
| **Constants** | camelCase or SCREAMING_SNAKE_CASE | `rpmOffset` or `GT7_MAGIC_NUMBER` |
| **Notifiers** | `[noun]Notifier` | `rpmNotifier`, `statusNotifier` |
| **Private Methods** | _camelCase | `_handlePacket()` |

---

## Import Organization
## インポート組織化

```dart
// 1. Dart core
import 'dart:typed_data';
import 'dart:async';
import 'dart:io';

// 2. Flutter
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 3. External packages
import 'package:udp/udp.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 4. Internal project files
import 'config/app_config.dart';
import 'models/gt7_models.dart';
import 'services/gt7_telemetry_service.dart';
import 'widgets/rpm_display_widget.dart';
import 'screens/telemetry_screen.dart';
```

---

## Data Flow Diagram
## データフロー図
┌─────────────────────────────────┐
│     PS5 (Gran Turismo 7)        │
│    sends UDP packets on         │
│  port 33740 (Salsa20 encrypted) │
└────────────────┬────────────────┘
│ UDP packet (296 bytes)
▼
┌────────────────────┐
│ GT7TelemetryService│
│  (listens on 33740)│
└────┬───────────────┘
│
├─→ GT7Decoder.decodeSalsa20()
│
├─→ GT7Packet.fromBytes()
│
└─→ rpmNotifier.value = packet.engineRPM
│
▼
┌─────────────────────────┐
│   RpmDisplay Widget     │
│ (ValueListenableBuilder)│
└─────────────────────────┘
│
▼
┌──────────────┐
│   UI Update  │
│ (RPM display)│
└──────────────┘

---

## Dependency Tree
## 依存関係ツリー
main.dart
├─ TelemetryAppScreen
│   └─ TelemetryScreen (renders)
│       ├─ TelemetryDrawer
│       ├─ RpmDisplay
│       └─ PacketInfoWidget
│
├─ GT7TelemetryService (created in initState)
│   ├─ uses: GT7Config
│   ├─ uses: GT7Decoder
│   ├─ uses: GT7Packet
│   └─ uses: SharedPreferences
│
└─ System: UDP, SharedPreferences

---

## File Checklist
## ファイルチェックリスト

- [ ] `lib/config/app_config.dart` - 定数定義
- [ ] `lib/models/gt7_models.dart` - GT7Decoder, GT7Packet
- [ ] `lib/services/gt7_telemetry_service.dart` - UDP通信・ロジック
- [ ] `lib/widgets/telemetry_drawer_widget.dart` - Drawer UI
- [ ] `lib/widgets/rpm_display_widget.dart` - RPM表示
- [ ] `lib/widgets/packet_info_widget.dart` - パケット情報
- [ ] `lib/screens/telemetry_screen.dart` - メイン画面
- [ ] `lib/main.dart` - アプリエントリー（システム設定のみ）
- [ ] `.claude/CLAUDE.md` - Claude Code開発ガイド
- [ ] `FILE_STRUCTURE.md` - このファイル

---

## Notes
## 注意事項

- **Single Responsibility**: Each file has exactly one role / 各ファイルは1つの責務のみ
- **Separation of Concerns**: UI (widgets/screens) is separate from logic (services/models) / UI層とロジック層を分離
- **State Management**: Use ValueNotifier + ValueListenableBuilder pattern / ValueNotifier + ValueListenableBuilderパターンを使用
- **Error Handling**: Log with `[LOG]`, `[ERROR]`, `[DEBUG]` prefixes / `[LOG]`、`[ERROR]`、`[DEBUG]`プリフィクス付きログ
- **Resource Cleanup**: Always implement `dispose()` and `_stopAll()` / 必ず`dispose()`と`_stopAll()`を実装