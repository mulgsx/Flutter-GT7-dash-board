# GT7 テレメトリ パケット構造リファレンス
# GT7 Telemetry Packet Structure Reference

UDPパケット（Packet A: 296 bytes, 60Hz）の全フィールド定義。  
Full field definitions for UDP packet (Packet A: 296 bytes, 60Hz).

エンディアン: **リトルエンディアン** / Endian: **Little-endian**  
暗号化: **Salsa20** / Encryption: **Salsa20**

---

## パケットタイプ / Packet Types

| ハートビスト / Heartbeat | タイプ / Type | サイズ / Size | 追加情報 / Added Data | 制限 / Restriction |
|---|---|---|---|---|
| `A` | Packet A | 296 bytes | 基本テレメトリ / Base telemetry | なし / None |
| `B` | Packet B | 316 bytes | 慣性力・ホイール回転 / Inertial forces, wheel rotation | スポーツモード不可 / No Sport Mode |
| `~` | Packet C | 344 bytes | アクティブエアロ・回生 / Active aero, energy recovery | リプレイ不可 / No Replay |

---

## 物理演算 / Physics — Position, Velocity, Rotation

| オフセット / Offset | 変数名 / Field Name | サイズ / Size | 型 / Type | 単位 / Unit | 説明 (JA) | Description (EN) |
|---|---|---|---|---|---|---|
| `0x04` | `position_x` | 4 | float | m | 車両位置（X座標） | Vehicle position X axis |
| `0x08` | `position_y` | 4 | float | m | 車両位置（Y座標） | Vehicle position Y axis |
| `0x0C` | `position_z` | 4 | float | m | 車両位置（Z座標） | Vehicle position Z axis |
| `0x10` | `velocity_x` | 4 | float | m/s | 速度（X軸） | World velocity X axis |
| `0x1C` | `rotation_pitch` | 4 | float | -1〜1 | 回転ピッチ角 | Rotation pitch angle |
| `0x20` | `rotation_yaw` | 4 | float | -1〜1 | 回転ヨー角・方位角 | Rotation yaw / heading |
| `0x24` | `rotation_roll` | 4 | float | -1〜1 | 回転ロール角 | Rotation roll angle |
| `0x2C` | `angular_velocity_x` | 4 | float | rad/s | 角速度（X軸） | Angular velocity X axis |

---

## サスペンション & タイヤ / Suspension & Tyres

| オフセット / Offset | 変数名 / Field Name | サイズ / Size | 型 / Type | 単位 / Unit | 説明 (JA) | Description (EN) |
|---|---|---|---|---|---|---|
| `0x38` | `ride_height` | 4 | float | m | 車体最低地上高 | Vehicle body height / ride height |
| `0x60` | `tyre_temp_FL` | 4 | float | °C | タイヤ温度（左前） | Tyre temperature Front Left |
| `0x64` | `tyre_temp_FR` | 4 | float | °C | タイヤ温度（右前） | Tyre temperature Front Right |
| `0x68` | `tyre_temp_RL` | 4 | float | °C | タイヤ温度（左後） | Tyre temperature Rear Left |
| `0x6C` | `tyre_temp_RR` | 4 | float | °C | タイヤ温度（右後） | Tyre temperature Rear Right |
| `0xA4` | `tyre_speed_FL` | 4 | float | rad/s | タイヤ角速度（左前） | Tyre angular velocity FL (wheelRPS) |
| `0xB4` | `tyre_radius_FL` | 4 | float | m | タイヤ半径（左前） | Tyre radius Front Left |
| `0xC4` | `suspension_FL` | 4 | float | m | サスペンションストローク（左前） | Suspension height / stroke FL |

---

## 車両情報 & エンジン / Engine & Vehicle

| オフセット / Offset | 変数名 / Field Name | サイズ / Size | 型 / Type | 単位 / Unit | 説明 (JA) | Description (EN) |
|---|---|---|---|---|---|---|
| `0x3C` | `rpm` | 4 | float | rpm | エンジン回転数 | Engine RPM |
| `0x4C` | `car_speed` | 4 | float | m/s | 車速（※変換式は下部参照） | Car speed (see conversions below) |
| `0x88` | `rpm_rev_warning` | 2 | uint16 | rpm | レブ警告開始RPM | RPM at which rev warning starts |
| `0x8A` | `rpm_rev_limiter` | 2 | uint16 | rpm | RPMリミッター値 | Rev limiter RPM |
| `0x8C` | `estimated_top_speed` | 2 | int16 | km/h | 推定最高速度 | Estimated top speed |
| `0x104` | `gear_ratios[8]` | 32 | float×8 | — | ギア比（1〜8速） | Gear ratios for gears 1-8 |
| `0x124` | `car_id` | 4 | int32 | — | 車両識別コード | Car identification code |

---

## 流体 & 温度 / Fluid & Temperature

| オフセット / Offset | 変数名 / Field Name | サイズ / Size | 型 / Type | 単位 / Unit | 説明 (JA) | Description (EN) |
|---|---|---|---|---|---|---|
| `0x44` | `current_fuel` | 4 | float | L | 現在の燃料残量 | Current fuel level |
| `0x48` | `fuel_capacity` | 4 | float | L | 燃料タンク容量（ガソリン≒100 / カート≒5 / EV=0） | Max fuel capacity |
| `0x50` | `boost` | 4 | float | +1offset | ターボ圧（実圧kPa = (boost−1)×100） | Boost pressure (+1 offset) |
| `0x54` | `oil_pressure` | 4 | float | bar | 油圧 | Oil pressure |
| `0x58` | `water_temp` | 4 | float | °C | 水温（常時85固定） | Water temp (always 85) |
| `0x5C` | `oil_temp` | 4 | float | °C | 油温（常時110固定） | Oil temp (always 110) |

---

## タイミング & レース状態 / Timing & Race State

| オフセット / Offset | 変数名 / Field Name | サイズ / Size | 型 / Type | 単位 / Unit | 説明 (JA) | Description (EN) |
|---|---|---|---|---|---|---|
| `0x70` | `package_id` | 4 | int32 | — | パケット連番ID | Packet sequence ID |
| `0x74` | `current_lap` | 2 | int16 | — | 現在のラップ番号 | Current lap number |
| `0x76` | `total_laps` | 2 | int16 | — | 総ラップ数 | Total number of laps |
| `0x78` | `best_lap` | 4 | int32 | ms | ベストラップタイム（未設定=-1） | Best lap time (-1 if not set) |
| `0x7C` | `last_lap` | 4 | int32 | ms | 直前ラップタイム（未設定=-1） | Last lap time (-1 if not set) |
| `0x80` | `time_on_track` | 4 | int32 | ms | トラック上の合計時間 | Total time on track |
| `0x84` | `current_position` | 2 | int16 | — | 現在の順位（レース前=-1） | Race position (-1 before start) |
| `0x86` | `total_positions` | 2 | int16 | — | 総出場台数（レース前=-1） | Total cars (-1 before start) |

---

## 入力 & ペダル / Input & Pedals

| オフセット / Offset | 変数名 / Field Name | サイズ / Size | 型 / Type | 範囲 / Range | 説明 (JA) | Description (EN) |
|---|---|---|---|---|---|---|
| `0x91` | `throttle` | 1 | uint8 | 0–255 | アクセル入力 | Throttle input |
| `0x92` | `brake` | 1 | uint8 | 0–255 | ブレーキ入力 | Brake input |
| `0xF4` | `clutch` | 4 | float | 0.0–1.0 | クラッチペダル位置 | Clutch pedal position |

---

## ビット演算フィールド / Bit-packed Fields

### `0x8E` — simulator_flags（uint8）

| ビット / Bit | フラグ名 / Flag Name | 説明 (JA) | Description (EN) |
|---|---|---|---|
| bit 0 | `car_on_track` | コース上にいる | Car is on track |
| bit 1 | `is_paused` | ポーズ中 | Game is paused |
| bit 2 | `is_loading` | ロード中 | Loading or processing |
| bit 3 | `in_gear` | ギアが入っている | Car is in gear |
| bit 4 | `has_turbo` | ターボ装備車 | Car has turbo |
| bit 5 | `rev_limit_alert` | レブリミット警告中 | Rev limit alert active |
| bit 6 | `handbrake_active` | ハンドブレーキ ON | Handbrake engaged |
| bit 7 | `lights_active` | ライト点灯中 | Lights on |
| bit 8 | `high_beams_active` | ハイビーム点灯中 | High beams on |
| bit 9 | `low_beams_active` | ロービーム点灯中 | Low beams on |
| bit 10 | `asm_active` | ASM 作動中 | ASM active |
| bit 11 | `tcs_active` | TCS 作動中 | TCS active |

```dart
// 判定例 / Example
bool isTcsActive = (flags & (1 << 11)) != 0;
bool isOnTrack   = (flags & (1 << 0))  != 0;
```

### `0x90` — gears（uint8）

| ビット分離 / Bit extraction | 変数名 / Name | 説明 (JA) | Description (EN) |
|---|---|---|---|
| `value & 0x0F`（下位4ビット / lower 4 bits） | `current_gear` | 現在のギア（0=N/R, 1〜8=前進） | Current gear (0=N/R, 1-8=forward) |
| `value >> 4`（上位4ビット / upper 4 bits） | `suggested_gear` | 推奨ギア（提示なし=15） | Suggested gear (15=no suggestion) |

```dart
// 取得例 / Example
int currentGear   = gearsRaw & 0x0F;
int suggestedGear = gearsRaw >> 4;
```

---

## 計算で導出する値 / Computed Values

| 変数名 / Name | 計算式 / Formula | 単位 / Unit | 説明 (JA) | Description (EN) |
|---|---|---|---|---|
| `speed_kph` | `car_speed * 3.6` | km/h | 車速（km/h） | Car speed in km/h |
| `speed_mph` | `car_speed * 2.237` | mph | 車速（mph） | Car speed in mph |
| `boost_kpa` | `(boost - 1.0) * 100.0` | kPa | ターボ圧（kPa） | Boost pressure in kPa |
| `tyre_linear_speed_FL` | `tyre_speed_FL * tyre_radius_FL` | m/s | タイヤ線速度（左前） | Tyre linear speed FL |
| `tyre_slip_ratio_FL` | `(tyre_linear_speed_FL - car_speed) / car_speed` | — | タイヤスリップ比（左前） | Tyre slip ratio FL |
| `fuel_ratio` | `current_fuel / fuel_capacity` | 0.0–1.0 | 燃料残量割合 | Fuel level ratio |
| `throttle_normalized` | `throttle / 255.0` | 0.0–1.0 | アクセル開度（正規化） | Normalized throttle |
| `brake_normalized` | `brake / 255.0` | 0.0–1.0 | ブレーキ踏力（正規化） | Normalized brake |

---

## パワートレイン判定 / Powertrain Detection

```dart
String get powertrainType {
  if (fuelCapacity == 0.0) return 'electric'; // EV / 電気自動車
  if (fuelCapacity <= 5.0) return 'kart';     // カート
  return 'combustion';                         // ガソリン・ディーゼル車
}
```
