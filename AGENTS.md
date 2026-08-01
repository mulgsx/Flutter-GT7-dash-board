# GT7 Dashboard

GT7 テレメトリを受信して表示する Flutter アプリ。横向き固定・iOS/Android 対応。  
A Flutter app that receives and displays GT7 telemetry. Landscape-only, iOS/Android.

プロトコル仕様の詳細 / Protocol details → [`docs/gt7_protocol_reference.md`](docs/gt7_protocol_reference.md)  
全パケットフィールド定義 / All packet fields → [`docs/packet_structure.md`](docs/packet_structure.md)

---

## コード固有の注意点 / Code-specific Notes

> プロトコルの仕組みは `docs/gt7_protocol_reference.md` を参照。  
> For protocol details, see `docs/gt7_protocol_reference.md`.

### `_heartbeatTimer` は消さない / Do not remove `_heartbeatTimer`

これを止めると PS5 へのハートビートが途絶え、数秒でテレメトリ受信が止まる。  
Stopping this timer cuts the heartbeat to the PS5 — telemetry stops within seconds.

### `decodeSalsa20` は例外を投げない / `decodeSalsa20` never throws

失敗時は空の `Uint8List` を返す。呼び出し側は **必ず `isEmpty` チェック**が必要。省くとサイレントバグになる。  
On failure it returns an empty `Uint8List`. Callers **must check `isEmpty`** — skipping this causes a silent bug.

---

## `docs/gt7_protocol_reference.md` を読むと実装できること
## What You Can Build by Reading `docs/gt7_protocol_reference.md`

### ハートビート文字を変えるだけでより多くのデータが取れる
### Change one character to unlock richer data

現在のアプリは `'A'` を送り続けており、296 バイトの Packet A を受信している。  
ハートビート文字を変えると GT7 が送るパケット種別が切り替わる。

The app currently sends `'A'` and receives 296-byte Packet A.  
Changing the heartbeat character switches the packet type GT7 sends.

| 送る文字 / Send | パケット / Packet | サイズ / Size | 追加データ / Extra data | 制限 / Restriction |
|---|---|---|---|---|
| `'A'` | Packet A | 296 bytes | 基本テレメトリ / Base telemetry（現在 / current） | なし / None |
| `'B'` | Packet B | 316 bytes | 慣性力・ホイール回転 / Inertial forces, wheel rotation | スポーツモード不可 / No Sport Mode |
| `'~'` | Packet C | 344 bytes | アクティブエアロ・回生 / Active aero, energy recovery | リプレイ不可 / No Replay |

変更箇所は `gt7_telemetry_service.dart` の `_sendHeartbeat()` 内、  
`socket.send('A'.codeUnits, ...)` の `'A'` を書き換えるだけ。  
Change `'A'` in `socket.send('A'.codeUnits, ...)` inside `_sendHeartbeat()` in `gt7_telemetry_service.dart`.

### `docs/packet_structure.md` と組み合わせると実装できる機能の例
### Features you can build using `docs/packet_structure.md`

| 機能 / Feature | 必要なフィールド / Fields | パケット / Packet |
|---|---|---|
| スピードメーター / Speedometer | `car_speed` × 3.6 | A |
| ギアインジケーター / Gear indicator | `gears & 0x0F`（現在 / current）、`gears >> 4`（推奨 / suggested） | A |
| ペダルグラフ / Pedal graph | `throttle / 255`、`brake / 255` | A |
| ラップタイム / Lap times | `last_lap`、`best_lap`、`current_lap` | A |
| タイヤ温度 / Tyre temperatures | `tyre_temp_FL/FR/RL/RR` | A |
| レブリミット警告 / Rev warning | `rpm_rev_warning`、`rpm_rev_limiter` | A |
| ターボ圧 / Boost pressure | `(boost - 1.0) * 100` kPa | A |
| 燃料残量 / Fuel level | `current_fuel / fuel_capacity` | A |
| TCS / ASM インジケーター / Indicator | `simulator_flags` のビット演算 / bit ops | A |
| 車両 ID / Car ID | `car_id` | A |
| タイヤスリップ比 / Tyre slip ratio | `tyre_speed_FL * tyre_radius_FL` vs `car_speed` | B |

Packet A だけで大半の機能は実現できる。  
Packet A alone is sufficient for most features.

---

## 現在の実装状態 / Current Implementation State

`GT7Packet` でデコード済みの値と UI への表示状態の一覧。  
Fields decoded in `GT7Packet` and their current display status.

| フィールド / Field | デコード / Decoded | Notifier | Widget 表示 / Displayed |
|---|---|---|---|
| `engineRPM` | ✅ | `rpmNotifier` ✅ | `RpmDisplay` ✅ |
| `speedKmh` | ✅ | — | — |
| `gear` | ✅ | — | — |
| `gas` | ✅ | — | — |
| `brake` | ✅ | — | — |
| `lapTime` | ✅ | — | — |

`speedKmh` 以降はすでにパケットから届いており、Notifier と Widget を繋ぐだけで表示できる。  
All fields below `engineRPM` are already received — only a Notifier and Widget need to be wired up.

---

## 設計の意図 / Design Decisions

### なぜ ValueNotifier か / Why ValueNotifier

60Hz でパケットが届くため、`setState` を毎回呼ぶと画面全体が再ビルドされる。  
ValueNotifier + ValueListenableBuilder は**変化した値だけ**を再ビルドするため採用。  
Riverpod/Provider は不要な複雑さになるため使わない。

Packets arrive at 60 Hz — calling `setState` every packet rebuilds the entire screen.  
ValueNotifier + ValueListenableBuilder rebuilds **only the widget bound to the changed value**.  
Riverpod/Provider would add unnecessary complexity.

### なぜ `_displayUpdateTimer`（200ms）が別立てか / Why a separate `_displayUpdateTimer`

`_rawPacketCount` は 60Hz でインクリメントされるが、`packetCountNotifier` に毎回書くと  
60fps の UI 再ビルドが走る。200ms タイマーで間引くことで抑制している。

`_rawPacketCount` increments at 60 Hz, but writing to `packetCountNotifier` every time  
would trigger 60 fps UI rebuilds. The 200 ms timer throttles updates to suppress this.

### なぜ service を StatefulWidget で生成するか / Why the service is created in a StatefulWidget

`TelemetryAppScreen` の `initState` で生成し `dispose` で破棄する。  
シングルトンにしないことで、将来マルチ接続や画面遷移での再生成に対応しやすい。

Created in `initState` and destroyed in `dispose` of `TelemetryAppScreen`.  
Avoiding a singleton makes it easier to support multiple connections or re-creation on navigation in the future.

---

## 新しいゲージを追加する手順 / How to Add a New Gauge

**ケース A / Case A: すでに `GT7Packet` にあるフィールドを表示する / Display a field already in `GT7Packet`**  
（例 / e.g. `speedKmh`, `gear`, `gas`, `brake`, `lapTime`）

1. `gt7_telemetry_service.dart` に `ValueNotifier` を追加（例: `speedNotifier`）  
   Add a `ValueNotifier` (e.g. `speedNotifier`)
2. `_handlePacket` 内で値を書き込む / Write the value in `_handlePacket`:  
   `speedNotifier.value = packet.speedKmh;`
3. `dispose()` に追加 / Add to `dispose()`:  
   `speedNotifier.dispose();`
4. `lib/widgets/` に表示ウィジェットを作成 / Create a display widget
5. `telemetry_screen.dart` の body に配置 / Place it in the `TelemetryScreen` body

**ケース B / Case B: まだデコードされていないフィールドを追加する / Add a field not yet decoded**

1. `docs/packet_structure.md` でオフセットと型を確認 / Check offset and type
2. `gt7_models.dart` にオフセット定数を追加 / Add offset constant
3. `GT7Packet` にフィールドを追加し `fromBytes` で読み取り / Add field and read in `fromBytes`
4. ケース A の手順へ / Continue with Case A

---

## 落とし穴 / Pitfalls

| 症状 / Symptom | 原因 / Cause |
|---|---|
| 受信中なのに値が変わらない / Values don't update despite receiving packets | `_handlePacket` が IP フィルタで弾いている。受信元 IP と `_targetIp` を確認 / IP filter is dropping packets — verify source IP matches `_targetIp` |
| 停止後も ERROR が残る / ERROR message persists after stop | `stopListening` は `statusNotifier` が `ERROR` で始まる場合は上書きしない仕様 / `stopListening` intentionally does not overwrite an ERROR status |
| マジックナンバーチェックが常に失敗 / Magic number check always fails | IV の XOR 定数またはバイト順が違う / Wrong XOR constant or byte order — verify `DEADBEAF` and `iv2_LE + iv1_LE` ordering |
| ギア値がおかしい / Gear value is wrong | 現在ギアは下位 4 ビット `& 0x0F`、推奨ギアは上位 4 ビット `>> 4` で別フィールド / Current gear is lower 4 bits `& 0x0F`; suggested gear is upper 4 bits `>> 4` |
