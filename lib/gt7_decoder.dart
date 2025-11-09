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

/// Read a float (Little-Endian) from the decoded packet data at a specific offset.
double getFloat(Uint8List decoded, int offset) {
  return (decoded.length >= offset + 4)
      ? ByteData.sublistView(
          decoded,
        ).getFloat32(offset, Endian.little).toDouble()
      : 0.0;
}
