import 'dart:typed_data';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/stream/salsa20.dart';

const int gt7MagicNumber = 0x47375330;
const int _deadbeaf = 0xDEADBEAF;

const int rpmOffset = 0x3C;
const int speedOffset = 0x4C;
const int gearOffset = 0x90;
const int throttleOffset = 0x91;
const int brakeOffset = 0x92;
const int lastLapOffset = 0x7C;

final Uint8List gt7KeyBytes = Uint8List.fromList(
  'Simulator Interface Packet GT7 ver 0.0'.codeUnits,
).sublist(0, 32);

class GT7Decoder {
  static Uint8List decodeSalsa20(Uint8List encryptedData) {
    if (encryptedData.length < 68) {
      print('[ERROR] Packet length too short: ${encryptedData.length}');
      return Uint8List(0);
    }

    try {
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

      final magic =
          ByteData.view(decrypted.buffer).getUint32(0, Endian.little);
      if (magic != gt7MagicNumber) {
        print(
          '[ERROR] Magic number check failed. Found: ${magic.toRadixString(16).padLeft(8, '0')}, Expected: ${gt7MagicNumber.toRadixString(16)}',
        );
        return Uint8List(0);
      }

      return decrypted;
    } catch (e) {
      print('[ERROR] Decryption error: $e');
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

  const GT7Packet({
    required this.speedKmh,
    required this.engineRPM,
    required this.gear,
    required this.gas,
    required this.brake,
    required this.lapTime,
  });

  factory GT7Packet.fromBytes(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    final speedMs = data.getFloat32(speedOffset, Endian.little);
    final gearByte = bytes.length > gearOffset ? bytes[gearOffset] : 0;
    final throttleByte =
        bytes.length > throttleOffset ? bytes[throttleOffset] : 0;
    final brakeByte = bytes.length > brakeOffset ? bytes[brakeOffset] : 0;
    final lapTimeMs =
        bytes.length >= lastLapOffset + 4
            ? data.getInt32(lastLapOffset, Endian.little)
            : -1;

    return GT7Packet(
      speedKmh: speedMs * 3.6,
      engineRPM: data.getFloat32(rpmOffset, Endian.little),
      gear: gearByte & 0x0F,
      gas: throttleByte / 255.0,
      brake: brakeByte / 255.0,
      lapTime: lapTimeMs,
    );
  }
}
