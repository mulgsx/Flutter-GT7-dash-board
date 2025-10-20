import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:udp/udp.dart';
import 'dart:typed_data';
import 'dart:async';
import 'dart:io';

import 'package:pointycastle/api.dart' hide Padding;
import 'package:pointycastle/stream/salsa20.dart';

// GT7 Encryption Constants
final Uint8List GT7_KEY_BYTES = Uint8List.fromList(
  "Simulator Interface Packet GT7 ver 0.0".codeUnits,
).sublist(0, 32);

// GT7S MAGIC NUMBER
const int GT7_MAGIC_NUMBER = 0x47375330;

const int RPM_OFFSET = 0x3C;

void main() => runApp(
  const MaterialApp(home: GT7RpmApp(), debugShowCheckedModeBanner: false),
);

class GT7RpmApp extends StatefulWidget {
  const GT7RpmApp({super.key});

  @override
  GT7RpmAppState createState() => GT7RpmAppState();
}

class GT7RpmAppState extends State<GT7RpmApp> {
  final String defaultIp = "192.168.0.0";
  final ValueNotifier<double> rpmNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<int> packetCountNotifier = ValueNotifier<int>(0);
  StreamSubscription? udpSubscription;

  // heartbeat Timer
  Timer? _heartbeatTimer;

  // 定数ポート
  static const int gt7SendPort = 33739; // Heartbeat Send Port
  static const int gt7ReceivePort = 33740; // Receive Port

  late final TextEditingController ipController = TextEditingController(
    text: defaultIp,
  );
  late String targetIp = defaultIp;
  bool isListening = false;
  UDP? receiver;

  @override
  void dispose() {
    udpSubscription?.cancel();
    receiver?.close();
    _heartbeatTimer?.cancel();
    ipController.dispose();
    rpmNotifier.dispose();
    packetCountNotifier.dispose();
    super.dispose();
  }

  // IPv4 Address Validation
  bool isValidIp(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    for (final part in parts) {
      final num = int.tryParse(part);
      if (num == null || num < 0 || num > 255) return false;
    }
    return true;
  }

  void showInvalidIpDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Invalid IP address format"),
        content: const Text("Enter it in the format 192.168.0.50."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void startListening() async {
    targetIp = ipController.text.trim();
    print("[DEBUG] Target IP is set to: $targetIp");
    if (!isValidIp(targetIp)) {
      showInvalidIpDialog();
      return;
    }

    if (isListening) {
      stopListening();
    }
    sendHeartbeat();

    await bindUdpReceiver();
    setState(() => isListening = true);

    udpSubscription = receiver!.asStream().listen((datagram) {
      if (datagram == null) {
        print("DEBUG: Datagram is null.");
        return;
      }

      if (datagram.address.address != targetIp) {
        print(
          "DEBUG: Received packet from wrong IP: ${datagram.address.address}",
        );
        return;
      }

      final rawData = datagram.data;
      final decrypted = decodeSalsa20(rawData);

      // decodeSalsa20
      if (decrypted.isEmpty) {
        print(
          "DEBUG: Decrypted data is empty (Magic number failed or decryption error).",
        );
        return;
      }

      packetCountNotifier.value++;

      // RPM data
      final newRpm = getFloat(decrypted, RPM_OFFSET);
      rpmNotifier.value = newRpm;
      print("[DEBUG] Extracted RPM (Offset 0x3C): $newRpm");

      if (packetCountNotifier.value % 100 == 0) sendHeartbeat();
    });
  }

  void stopListening() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    udpSubscription?.cancel();
    receiver?.close();
    receiver = null;
    udpSubscription = null;
    setState(() => isListening = false);
    print("[LOG] Listening stopped.");
  }

  void sendHeartbeat() async {
    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);

      try {
        final data = "A".codeUnits;
        final address = InternetAddress(targetIp);
        socket.send(data, address, gt7SendPort);
      } finally {
        socket.close();
      }
    } catch (e) {
      print("[ERROR] Heartbeat failed: $e");
    }
  }

  Future<void> bindUdpReceiver() async {
    try {
      receiver = await UDP.bind(Endpoint.any(port: Port(gt7ReceivePort)));
      print("[LOG] UDP receiver bound to port $gt7ReceivePort");
    } catch (e) {
      print("[ERROR] Failed to bind UDP receiver: $e");
    }
  }

  Uint8List decodeSalsa20(Uint8List encryptedData) {
    if (encryptedData.length < 68) {
      print("[ERROR] Packet length too short: ${encryptedData.length}");
      return Uint8List(0);
    }

    try {
      final ivBytesSource = encryptedData.sublist(64, 68);
      final data = ByteData.sublistView(ivBytesSource);

      final iv1 = data.getUint32(0, Endian.little);

      const int deadbeaf = 0xDEADBEAF;
      final iv2 = iv1 ^ deadbeaf;

      final iv = Uint8List(8);
      final ivBuffer = ByteData.view(iv.buffer);
      ivBuffer.setUint32(0, iv2, Endian.little);
      ivBuffer.setUint32(4, iv1, Endian.little);

      final cipher = Salsa20Engine();
      final keyParam = KeyParameter(GT7_KEY_BYTES);
      final params = ParametersWithIV(keyParam, iv);

      final decrypted = Uint8List(encryptedData.length);
      cipher.init(false, params);
      cipher.processBytes(encryptedData, 0, encryptedData.length, decrypted, 0);

      final magic = ByteData.view(decrypted.buffer).getUint32(0, Endian.little);

      final isMagicValid = (magic == GT7_MAGIC_NUMBER);

      if (!isMagicValid) {
        print(
          "[ERROR] Magic number check failed. Found: ${magic.toRadixString(16).padLeft(8, '0')}, Expected: ${GT7_MAGIC_NUMBER.toRadixString(16)}",
        );
      }

      return isMagicValid ? decrypted : Uint8List(0);
    } catch (e) {
      print("[ERROR] Decryption error: $e");
      return Uint8List(0);
    }
  }

  /// float (Little-Endian)
  double getFloat(Uint8List decoded, int offset) {
    return (decoded.length >= offset + 4)
        ? ByteData.sublistView(
            decoded,
          ).getFloat32(offset, Endian.little).toDouble()
        : 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("GT7 RPM Tracker")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Connection Settings",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 8),

              IpInputField(
                controller: ipController,
                onSubmitted: startListening,
              ),

              const SizedBox(height: 12),

              ReceiveToggleButton(
                isListening: isListening,
                onStart: startListening,
                onStop: stopListening,
              ),

              const Divider(height: 32),

              const Text(
                "Live Data",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 12),

              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: RpmDisplay(rpmNotifier: rpmNotifier),
                ),
              ),

              const SizedBox(height: 10),

              PacketInfoDisplay(
                ip: targetIp,
                countNotifier: packetCountNotifier,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// IP text box
class IpInputField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSubmitted;

  const IpInputField({
    super.key,
    required this.controller,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: const InputDecoration(
        labelText: "PS5 IP",
        hintText: "ex: 192.168.0.50",
        border: OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      onSubmitted: (_) => onSubmitted(),
    );
  }
}

// RPM display
class RpmDisplay extends StatelessWidget {
  final ValueNotifier<double> rpmNotifier;

  const RpmDisplay({super.key, required this.rpmNotifier});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: rpmNotifier,
      builder: (_, rpm, __) => Text(
        "${rpm.toStringAsFixed(0)} RPM",
        style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
      ),
    );
  }
}

// Packet info
class PacketInfoDisplay extends StatelessWidget {
  final String ip;
  final ValueNotifier<int> countNotifier;

  const PacketInfoDisplay({
    super.key,
    required this.ip,
    required this.countNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: countNotifier,
      builder: (_, count, __) => Text(
        "Packets from $ip: $count",
        style: const TextStyle(fontSize: 18, color: Colors.blueGrey),
      ),
    );
  }
}

class ReceiveToggleButton extends StatelessWidget {
  final bool isListening;
  final VoidCallback onStart;
  final VoidCallback onStop;

  const ReceiveToggleButton({
    super.key,
    required this.isListening,
    required this.onStart,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isListening ? onStop : onStart,
      child: Text(isListening ? "Stop Receiving" : "Start Receiving"),
    );
  }
}
