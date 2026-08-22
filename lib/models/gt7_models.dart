import 'package:pointycastle/api.dart';
import 'package:pointycastle/stream/salsa20.dart';
import 'package:flutter/foundation.dart';

const int gt7MagicNumber =
    0x47375330; // ASCII "GT70" — 復号成功の証明 / Proves successful decryption
const int _deadbeaf =
    0xDEADBEAF; // IV導出用XOR定数（BEEF ではなく BEAF）/ XOR constant for IV (BEAF not BEEF)

const int positionXOffset = 0x04;
const int positionYOffset = 0x08;
const int positionZOffset = 0x0C;
const int rpmOffset = 0x3C;
const int currentFuelOffset = 0x44;
const int fuelCapacityOffset = 0x48;
const int speedOffset = 0x4C;
const int tyreTempFLOffset = 0x60;
const int tyreTempFROffset = 0x64;
const int tyreTempRLOffset = 0x68;
const int tyreTempRROffset = 0x6C;
const int gearOffset = 0x90;
const int throttleOffset = 0x91;
const int brakeOffset = 0x92;
const int currentLapOffset = 0x74; // int16
const int totalLapsOffset = 0x76; // int16
const int bestLapOffset = 0x78; // int32, ms — 未設定=-1
const int lastLapOffset = 0x7C;
const int revWarningOffset = 0x88; // uint16, rpm — レブ警告開始RPM
const int revLimiterOffset = 0x8A; // uint16, rpm — RPMリミッター値
// ドキュメント上はuint8だがbit11(tcs_active)まで使うためuint16として読む
// Documented as uint8, but read as uint16 since bit 11 (tcs_active) requires it
const int simulatorFlagsOffset = 0x8E;
const int carIdOffset = 0x124; // int32 — 保存キーとしてのみ使用する車両ID

const int _tcsActiveBit = 11;

// Salsa20キー: 固定文字列の先頭32バイト / Salsa20 key: first 32 bytes of the fixed ASCII string
final Uint8List gt7KeyBytes = Uint8List.fromList(
  'Simulator Interface Packet GT7 ver 0.0'.codeUnits,
).sublist(0, 32);

class GT7Decoder {
  static Uint8List decodeSalsa20(Uint8List encryptedData) {
    if (encryptedData.length < 68) {
      debugPrint('[ERROR] Packet length too short: ${encryptedData.length}');
      return Uint8List(0);
    }

    try {
      // IV導出: encrypted[64:68] → iv1、iv2 = iv1 XOR DEADBEAF
      // iv = iv2_LE(4byte) + iv1_LE(4byte) ← 順序が逆になることに注意
      // IV derivation: iv2 = iv1 XOR DEADBEAF; iv = iv2_LE + iv1_LE (order matters)
      final ivBytesSource = encryptedData.sublist(64, 68);
      final data = ByteData.sublistView(ivBytesSource);

      final iv1 = data.getUint32(0, Endian.little);
      final iv2 = iv1 ^ _deadbeaf;

      final iv = Uint8List(8);
      final ivBuffer = ByteData.view(iv.buffer);
      ivBuffer.setUint32(0, iv2, Endian.little);
      ivBuffer.setUint32(4, iv1, Endian.little);

      final cipher = Salsa20Engine();
      final keyParam = KeyParameter(gt7KeyBytes);
      final params = ParametersWithIV(keyParam, iv);

      final decrypted = Uint8List(encryptedData.length);
      cipher.init(false, params);
      cipher.processBytes(encryptedData, 0, encryptedData.length, decrypted, 0);

      final magic = ByteData.view(decrypted.buffer).getUint32(0, Endian.little);
      if (magic != gt7MagicNumber) {
        debugPrint(
          '[ERROR] Magic number check failed. Found: ${magic.toRadixString(16).padLeft(8, '0')}, Expected: ${gt7MagicNumber.toRadixString(16)}',
        );
        return Uint8List(0);
      }

      return decrypted;
    } catch (e) {
      debugPrint('[ERROR] Decryption error: $e');
      return Uint8List(0);
    }
  }

  static double getFloat(Uint8List decoded, int offset) {
    return (decoded.length >= offset + 4)
        ? ByteData.sublistView(decoded).getFloat32(offset, Endian.little)
        : 0.0;
  }
}

class GT7Packet {
  // ワールド座標（メートル）。X-Z平面がコース平面、Yは高さ。
  // World-space coordinates in meters. X-Z is the track's ground plane; Y is height.
  final double positionX;
  final double positionY;
  final double positionZ;
  final double speedKmh;
  final double engineRPM;
  final int gear;
  final double gas;
  final double brake;
  final int lapTime;
  final int revWarningRpm; // -1 = パケット不足で未取得 / -1 when the packet was too short
  final int revLimiterRpm; // -1 = 同上 / -1 when the packet was too short
  final int
  carId; // -1 = 同上（未確定の車） / -1 when unknown (no reliable car identity yet)
  final double currentFuel;
  final double fuelCapacity; // 0.0 = EV
  final double tyreTempFL;
  final double tyreTempFR;
  final double tyreTempRL;
  final double tyreTempRR;
  final int currentLap; // -1 = 未取得 / -1 when not yet available
  final int totalLaps; // -1 = 未取得 / -1 when not yet available
  final int bestLapMs; // -1 = 未設定 / -1 when not set
  final bool tcsActive;

  const GT7Packet({
    required this.positionX,
    required this.positionY,
    required this.positionZ,
    required this.speedKmh,
    required this.engineRPM,
    required this.gear,
    required this.gas,
    required this.brake,
    required this.lapTime,
    required this.revWarningRpm,
    required this.revLimiterRpm,
    required this.carId,
    required this.currentFuel,
    required this.fuelCapacity,
    required this.tyreTempFL,
    required this.tyreTempFR,
    required this.tyreTempRL,
    required this.tyreTempRR,
    required this.currentLap,
    required this.totalLaps,
    required this.bestLapMs,
    required this.tcsActive,
  });

  factory GT7Packet.fromBytes(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    final speedMs = data.getFloat32(speedOffset, Endian.little);
    final gearByte = bytes.length > gearOffset ? bytes[gearOffset] : 0;
    final throttleByte = bytes.length > throttleOffset
        ? bytes[throttleOffset]
        : 0;
    final brakeByte = bytes.length > brakeOffset ? bytes[brakeOffset] : 0;
    final lapTimeMs = bytes.length >= lastLapOffset + 4
        ? data.getInt32(lastLapOffset, Endian.little)
        : -1;
    // GT7 は 500rpm 刻みでしか報告しない。手動入力で上書きできるようにするための土台
    // GT7 only reports this in 500rpm steps; decoded here so the UI can let the user override it
    final revWarningRpm = bytes.length >= revWarningOffset + 2
        ? data.getUint16(revWarningOffset, Endian.little)
        : -1;
    final revLimiterRpm = bytes.length >= revLimiterOffset + 2
        ? data.getUint16(revLimiterOffset, Endian.little)
        : -1;
    final carId = bytes.length >= carIdOffset + 4
        ? data.getInt32(carIdOffset, Endian.little)
        : -1;
    final currentLap = bytes.length >= currentLapOffset + 2
        ? data.getInt16(currentLapOffset, Endian.little)
        : -1;
    final totalLaps = bytes.length >= totalLapsOffset + 2
        ? data.getInt16(totalLapsOffset, Endian.little)
        : -1;
    final bestLapMs = bytes.length >= bestLapOffset + 4
        ? data.getInt32(bestLapOffset, Endian.little)
        : -1;
    final simulatorFlags = bytes.length >= simulatorFlagsOffset + 2
        ? data.getUint16(simulatorFlagsOffset, Endian.little)
        : 0;

    return GT7Packet(
      positionX: data.getFloat32(positionXOffset, Endian.little),
      positionY: data.getFloat32(positionYOffset, Endian.little),
      positionZ: data.getFloat32(positionZOffset, Endian.little),
      speedKmh: speedMs * 3.6,
      engineRPM: data.getFloat32(rpmOffset, Endian.little),
      gear:
          gearByte &
          0x0F, // 下位4ビット=現在ギア、上位4ビット=推奨ギア(15=提示なし) / lower=current, upper=suggested(15=none)
      gas:
          throttleByte /
          255.0, // 0〜255 → 0.0〜1.0 に正規化 / Normalize 0-255 to 0.0-1.0
      brake: brakeByte / 255.0,
      lapTime: lapTimeMs,
      revWarningRpm: revWarningRpm,
      revLimiterRpm: revLimiterRpm,
      carId: carId,
      currentFuel: GT7Decoder.getFloat(bytes, currentFuelOffset),
      fuelCapacity: GT7Decoder.getFloat(bytes, fuelCapacityOffset),
      tyreTempFL: GT7Decoder.getFloat(bytes, tyreTempFLOffset),
      tyreTempFR: GT7Decoder.getFloat(bytes, tyreTempFROffset),
      tyreTempRL: GT7Decoder.getFloat(bytes, tyreTempRLOffset),
      tyreTempRR: GT7Decoder.getFloat(bytes, tyreTempRROffset),
      currentLap: currentLap,
      totalLaps: totalLaps,
      bestLapMs: bestLapMs,
      tcsActive: (simulatorFlags & (1 << _tcsActiveBit)) != 0,
    );
  }
}
