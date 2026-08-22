import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/stream/salsa20.dart';

import 'package:gt7_trj_log/models/gt7_models.dart';

const int _packetASize = 296;

// GT7 の実プロトコルでは、送信側が Salsa20 で暗号化したあと、
// IV 導出に使った iv1（4バイト、リトルエンディアン）を平文に戻して
// 暗号文の [64:68] にそのまま埋め込む。decodeSalsa20 はこの生の iv1 を
// 復号鍵の導出に使うため、テスト用の暗号文もこの手順で組み立てる。
//
// The real protocol embeds the raw (unencrypted) iv1 seed used to derive
// the Salsa20 IV directly into ciphertext[64:68] after encryption.
// decodeSalsa20 reads that raw iv1 to derive the decryption key, so the
// test ciphertext is built the same way.
Uint8List _encryptAsGT7Packet(Uint8List plaintext, int iv1) {
  final iv2 = iv1 ^ 0xDEADBEAF;
  final iv = Uint8List(8);
  final ivBuffer = ByteData.view(iv.buffer);
  ivBuffer.setUint32(0, iv2, Endian.little);
  ivBuffer.setUint32(4, iv1, Endian.little);

  final cipher = Salsa20Engine();
  final params = ParametersWithIV(KeyParameter(gt7KeyBytes), iv);
  cipher.init(true, params);

  final ciphertext = Uint8List(plaintext.length);
  cipher.processBytes(plaintext, 0, plaintext.length, ciphertext, 0);

  final iv1Bytes = ByteData(4)..setUint32(0, iv1, Endian.little);
  ciphertext.setRange(64, 68, iv1Bytes.buffer.asUint8List());

  return ciphertext;
}

Uint8List _buildPlainPacketA({
  double rpm = 6500.0,
  double speedMs = 50.0,
  int gear = 4,
  int suggestedGear = 5,
  int throttle = 255,
  int brake = 128,
  int lastLapMs = 92345,
  int revWarningRpm = 6800,
  int carId = 1234,
}) {
  final bytes = Uint8List(_packetASize);
  final data = ByteData.sublistView(bytes);

  data.setUint32(0, gt7MagicNumber, Endian.little);
  data.setFloat32(rpmOffset, rpm, Endian.little);
  data.setFloat32(speedOffset, speedMs, Endian.little);
  bytes[gearOffset] = (gear & 0x0F) | ((suggestedGear & 0x0F) << 4);
  bytes[throttleOffset] = throttle;
  bytes[brakeOffset] = brake;
  data.setInt32(lastLapOffset, lastLapMs, Endian.little);
  data.setUint16(revWarningOffset, revWarningRpm, Endian.little);
  data.setInt32(carIdOffset, carId, Endian.little);

  return bytes;
}

void main() {
  group('GT7Decoder.decodeSalsa20', () {
    test('returns empty bytes when the packet is shorter than 68 bytes', () {
      final tooShort = Uint8List(67);
      expect(GT7Decoder.decodeSalsa20(tooShort), isEmpty);
    });

    test('decrypts a valid packet and preserves the payload', () {
      final plaintext = _buildPlainPacketA();
      final encrypted = _encryptAsGT7Packet(plaintext, 0x12345678);

      final decrypted = GT7Decoder.decodeSalsa20(encrypted);

      expect(decrypted, isNotEmpty);
      expect(decrypted.length, plaintext.length);
      // iv1 の埋め込みに使われた [64:68] 以外は平文と一致するはず
      // Everything outside the embedded iv1 field [64:68] must round-trip exactly.
      expect(decrypted.sublist(0, 64), plaintext.sublist(0, 64));
      expect(decrypted.sublist(68), plaintext.sublist(68));
    });

    test('returns empty bytes when the magic number does not match', () {
      final plaintext = _buildPlainPacketA();
      // マジックナンバーを壊す / Corrupt the magic number
      ByteData.sublistView(plaintext).setUint32(0, 0, Endian.little);
      final encrypted = _encryptAsGT7Packet(plaintext, 0xAABBCCDD);

      expect(GT7Decoder.decodeSalsa20(encrypted), isEmpty);
    });
  });

  group('GT7Packet.fromBytes', () {
    test('parses fields at their documented offsets', () {
      final plaintext = _buildPlainPacketA(
        rpm: 7200.5,
        speedMs: 40.0,
        gear: 3,
        suggestedGear: 4,
        throttle: 255,
        brake: 0,
        lastLapMs: 88123,
        revWarningRpm: 7300,
        carId: 4242,
      );

      final packet = GT7Packet.fromBytes(plaintext);

      expect(packet.engineRPM, closeTo(7200.5, 0.001));
      expect(packet.speedKmh, closeTo(40.0 * 3.6, 0.001));
      expect(packet.gear, 3); // 下位4ビットのみ / lower nibble only
      expect(packet.gas, closeTo(1.0, 0.001));
      expect(packet.brake, closeTo(0.0, 0.001));
      expect(packet.lapTime, 88123);
      expect(packet.revWarningRpm, 7300);
      expect(packet.carId, 4242);
    });

    test('normalizes throttle and brake bytes to the 0.0-1.0 range', () {
      final plaintext = _buildPlainPacketA(throttle: 128, brake: 64);

      final packet = GT7Packet.fromBytes(plaintext);

      expect(packet.gas, closeTo(128 / 255.0, 0.0001));
      expect(packet.brake, closeTo(64 / 255.0, 0.0001));
    });
  });

  group('GT7Packet.fromBytes short-packet handling', () {
    test('returns -1 for revWarningRpm and carId when the packet is too short', () {
      // revWarningOffset(0x88)+2 = 138 未満 → 両方とも -1 になる
      // Shorter than revWarningOffset+2 (138) → both fields default to -1
      final tooShort = Uint8List(100);
      ByteData.sublistView(tooShort).setUint32(0, gt7MagicNumber, Endian.little);

      final packet = GT7Packet.fromBytes(tooShort);

      expect(packet.revWarningRpm, -1);
      expect(packet.carId, -1);
    });

    test(
      'decodes revWarningRpm but returns -1 for carId when only carId is out of range',
      () {
        // carIdOffset(0x124)+4 = 296 未満 → revWarningRpm は取得できるが carId は -1
        // Shorter than carIdOffset+4 (296) but long enough for revWarningOffset+2 (138)
        final partial = Uint8List(200);
        final data = ByteData.sublistView(partial);
        data.setUint32(0, gt7MagicNumber, Endian.little);
        data.setUint16(revWarningOffset, 7000, Endian.little);

        final packet = GT7Packet.fromBytes(partial);

        expect(packet.revWarningRpm, 7000);
        expect(packet.carId, -1);
      },
    );
  });
}
