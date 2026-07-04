import 'dart:typed_data';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/stream/salsa20.dart';

// GT7 Encryption Key Bytes (32 bytes)
final Uint8List gt7KeyBytes = Uint8List.fromList(
  "Simulator Interface Packet GT7 ver 0.0".codeUnits,
).sublist(0, 32);

// GT7S MAGIC NUMBER for packet validation
const int gt7MagicNumber = 0x47375330;

// Offset for RPM value in the decoded packet (0x3C = 60)
const int rpmOffset = 0x3C;

// Additional offsets
const int speedOffset        = 0x4C; // float, m/s → × 3.6 = km/h
const int fuelLevelOffset    = 0x44; // float, litres
const int fuelCapacityOffset = 0x48; // float, litres
const int tyreTempFLOffset   = 0x60; // float, celsius
const int tyreTempFROffset   = 0x64; // float, celsius
const int tyreTempRLOffset   = 0x68; // float, celsius
const int tyreTempRROffset   = 0x6C; // float, celsius
const int lapCountOffset     = 0x74; // uint16
const int lapsInRaceOffset   = 0x76; // uint16
const int bestLapOffset      = 0x78; // int32, ms (-1 = none)
const int lastLapOffset      = 0x7C; // int32, ms (-1 = none)
const int rpmWarningOffset   = 0x88; // uint16, rev warning RPM
const int rpmLimiterOffset   = 0x8A; // uint16, rev limiter RPM
const int gearsOffset        = 0x90; // uint8, lower4=current gear, upper4=suggested
const int throttleOffset     = 0x91; // uint8, 0–255
const int brakeOffset        = 0x92; // uint8, 0–255
const int tyreWearFLOffset   = 0xF4; // float, 0.0(worn)–1.0(new)
const int tyreWearFROffset   = 0xF8; // float
const int tyreWearRLOffset   = 0xFC; // float
const int tyreWearRROffset   = 0x100; // float

// Deadbeaf constant used in IV calculation
const int _deadbeaf = 0xDEADBEAF;

/// Decodes the Gran Turismo 7 UDP packet using Salsa20 encryption.
///
/// The IV (Initialization Vector) is constructed from the last 4 bytes of
/// the encrypted data.
/// Returns the decrypted packet data if the magic number is valid, otherwise
/// returns an empty list.
Uint8List decodeSalsa20(Uint8List encryptedData) {
  // A minimum size check to ensure the IV is present (64 bytes header + 4 bytes IV source)
  if (encryptedData.length < 68) {
    print("[ERROR] Packet length too short: ${encryptedData.length}");
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

    // Check for the Magic Number at the start of the decrypted data
    final magic = ByteData.view(decrypted.buffer).getUint32(0, Endian.little);
    final isMagicValid = (magic == gt7MagicNumber);

    if (!isMagicValid) {
      print(
        "[ERROR] Magic number check failed. Found: ${magic.toRadixString(16).padLeft(8, '0')}, Expected: ${gt7MagicNumber.toRadixString(16)}",
      );
    }

    return isMagicValid ? decrypted : Uint8List(0);
  } catch (e) {
    print("[ERROR] Decryption error: $e");
    return Uint8List(0);
  }
}

/// Read a uint8 from the decoded packet at a specific offset.
int getUint8(Uint8List decoded, int offset) {
  if (decoded.length <= offset) return 0;
  return decoded[offset];
}

/// Read a uint16 (Little-Endian) from the decoded packet at a specific offset.
int getUint16(Uint8List decoded, int offset) {
  if (decoded.length < offset + 2) return 0;
  return ByteData.sublistView(decoded).getUint16(offset, Endian.little);
}

/// Read an int32 (Little-Endian) from the decoded packet at a specific offset.
int getInt32(Uint8List decoded, int offset) {
  if (decoded.length < offset + 4) return -1;
  return ByteData.sublistView(decoded).getInt32(offset, Endian.little);
}

/// Read a float (Little-Endian) from the decoded packet data at a specific offset.
double getFloat(Uint8List decoded, int offset) {
  return (decoded.length >= offset + 4)
      ? ByteData.sublistView(
          decoded,
        ).getFloat32(offset, Endian.little).toDouble()
      : 0.0;
}

// int getUint16(Uint8List decoded, int offset) {
//   // Check if the packet is long enough for a 2-byte integer.
//   if (decoded.length < offset + 2) {
//     return 0;
//   }
//   return ByteData.sublistView(decoded).getUint16(offset, Endian.little);
// }

// bool getLSB(Uint8List decoded, int offset) {
//   if (decoded.length <= offset) {
//     return false;
//   }
//   final int statusByte = decoded[offset];
//   return (statusByte & 0x01) == 1;
// }

// int getUint8(Uint8List decoded, int offset) {
//   if (decoded.length <= offset) {
//     return 0;
//   }
//   return decoded[offset];
// }
