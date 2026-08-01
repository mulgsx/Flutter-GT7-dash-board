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
const int carIdOffset = 0x124; // int32 — 保存キーとしてのみ使用する車両ID

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
  final int lapTime;
  final int revWarningRpm; // -1 = パケット不足で未取得 / -1 when the packet was too short
  final int
  carId; // -1 = 同上（未確定の車） / -1 when unknown (no reliable car identity yet)

  const GT7Packet({
    required this.speedKmh,
    required this.engineRPM,
    required this.gear,
    required this.gas,
    required this.brake,
    required this.lapTime,
    required this.revWarningRpm,
    required this.carId,
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
    final carId = bytes.length >= carIdOffset + 4
        ? data.getInt32(carIdOffset, Endian.little)
        : -1;

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
      lapTime: lapTimeMs,
      revWarningRpm: revWarningRpm,
      carId: carId,
    );
  }
}
