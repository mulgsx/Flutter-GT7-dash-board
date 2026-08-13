import 'package:pointycastle/api.dart';
import 'package:pointycastle/stream/salsa20.dart';
import 'package:flutter/foundation.dart';

const int gt7MagicNumber =
    0x47375330; // ASCII "GT70" — 復号成功の証明 / Proves successful decryption
const int _deadbeaf =
    0xDEADBEAF; // IV導出用XOR定数（BEEF ではなく BEAF）/ XOR constant for IV (BEAF not BEEF)

const int rpmOffset = 0x3C;
const int speedOffset = 0x4C;
const int gearOffset = 0x90;
const int throttleOffset = 0x91;
const int brakeOffset = 0x92;
const int lastLapOffset = 0x7C;
const int revWarningOffset = 0x88; // uint16, rpm — レブ警告開始RPM
const int revLimiterOffset = 0x8A; // uint16, rpm — RPMリミッター値
const int carIdOffset = 0x124; // int32 — 保存キーとしてのみ使用する車両ID

const int fuelLevelOffset = 0x44; // float, L — 現在の燃料残量
const int fuelCapacityOffset = 0x48; // float, L — タンク容量（EV=0）
const int tireTempFLOffset = 0x60; // float, °C
const int tireTempFROffset = 0x64; // float, °C
const int tireTempRLOffset = 0x68; // float, °C
const int tireTempRROffset = 0x6C; // float, °C
const int currentLapOffset = 0x74; // int16
const int totalLapsOffset = 0x76; // int16 — ラップ制限なし = -1
const int bestLapOffset = 0x78; // int32, ms — 未設定 = -1
const int flagsOffset = 0x8E; // uint16 bitfield — bit11 = tcs_active

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
  final double speedKmh;
  final double engineRPM;
  final int gear;
  final double gas;
  final double brake;
  final int lastLapTime;
  final int revWarningRpm; // -1 = パケット不足で未取得 / -1 when the packet was too short
  final int revLimiterRpm; // -1 = 同上 / -1 when the packet was too short
  final int
  carId; // -1 = 同上（未確定の車） / -1 when unknown (no reliable car identity yet)

  final double fuelLevel; // L
  final double fuelCapacity; // L, EV = 0
  final double tireTempFL;
  final double tireTempFR;
  final double tireTempRL;
  final double tireTempRR;
  final int currentLap; // -1 = 未取得
  final int totalLaps; // -1 = ラップ制限なし、または未取得
  final int bestLapTime; // ms, -1 = 未設定
  final bool tcsActive;

  const GT7Packet({
    required this.speedKmh,
    required this.engineRPM,
    required this.gear,
    required this.gas,
    required this.brake,
    required this.lastLapTime,
    required this.revWarningRpm,
    required this.revLimiterRpm,
    required this.carId,
    required this.fuelLevel,
    required this.fuelCapacity,
    required this.tireTempFL,
    required this.tireTempFR,
    required this.tireTempRL,
    required this.tireTempRR,
    required this.currentLap,
    required this.totalLaps,
    required this.bestLapTime,
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
    final lastLapTimeMs = bytes.length >= lastLapOffset + 4
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

    final fuelLevel = bytes.length >= fuelLevelOffset + 4
        ? data.getFloat32(fuelLevelOffset, Endian.little)
        : 0.0;
    final fuelCapacity = bytes.length >= fuelCapacityOffset + 4
        ? data.getFloat32(fuelCapacityOffset, Endian.little)
        : 0.0;
    final currentLap = bytes.length >= currentLapOffset + 2
        ? data.getInt16(currentLapOffset, Endian.little)
        : -1;
    final totalLaps = bytes.length >= totalLapsOffset + 2
        ? data.getInt16(totalLapsOffset, Endian.little)
        : -1;
    final bestLapTime = bytes.length >= bestLapOffset + 4
        ? data.getInt32(bestLapOffset, Endian.little)
        : -1;
    final flags = bytes.length >= flagsOffset + 2
        ? data.getUint16(flagsOffset, Endian.little)
        : 0;

    return GT7Packet(
      speedKmh: speedMs * 3.6,
      engineRPM: data.getFloat32(rpmOffset, Endian.little),
      gear:
          gearByte &
          0x0F, // 下位4ビット=現在ギア、上位4ビット=推奨ギア(15=提示なし) / lower=current, upper=suggested(15=none)
      gas:
          throttleByte /
          255.0, // 0〜255 → 0.0〜1.0 に正規化 / Normalize 0-255 to 0.0-1.0
      brake: brakeByte / 255.0,
      lastLapTime: lastLapTimeMs,
      revWarningRpm: revWarningRpm,
      revLimiterRpm: revLimiterRpm,
      carId: carId,
      fuelLevel: fuelLevel,
      fuelCapacity: fuelCapacity,
      tireTempFL: GT7Decoder.getFloat(bytes, tireTempFLOffset),
      tireTempFR: GT7Decoder.getFloat(bytes, tireTempFROffset),
      tireTempRL: GT7Decoder.getFloat(bytes, tireTempRLOffset),
      tireTempRR: GT7Decoder.getFloat(bytes, tireTempRROffset),
      currentLap: currentLap,
      totalLaps: totalLaps,
      bestLapTime: bestLapTime,
      tcsActive: (flags & (1 << 11)) != 0,
    );
  }
}
