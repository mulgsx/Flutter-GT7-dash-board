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
  // Raw packet count, incremented on every successful reception
  int _rawPacketCount = 0;
  // Timer for smoothing the UI update frequency
  Timer? _displayUpdateTimer;

  final ValueNotifier<String> statusNotifier = ValueNotifier<String>(
    "IDLE: Press 'Start Receiving' to connect.",
  );

  // Notifier for the IP address currently displayed in the UI
  final ValueNotifier<String> currentDisplayedIpNotifier =
      ValueNotifier<String>("192.168.0.0");

  StreamSubscription? udpSubscription;

  // Heartbeat Timer
  Timer? _heartbeatTimer;

  // Constant ports
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
    _displayUpdateTimer?.cancel(); // Cancel the display timer
    ipController.dispose();
    rpmNotifier.dispose();
    packetCountNotifier.dispose();
    statusNotifier.dispose();
    currentDisplayedIpNotifier.dispose(); // Dispose IP Notifier
    super.dispose();
  }

  // IPv4 Address Validation
  bool isValidIp(String ip) {
    return InternetAddress.tryParse(ip) != null;
  }

  void showInvalidIpDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Invalid IP address format"),
        content: const Text(
          "Enter it in the format 192.168.0.50 or IPv6 format.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  // UDP bind function, returns bool for success/failure
  Future<bool> bindUdpReceiver() async {
    try {
      receiver = await UDP.bind(Endpoint.any(port: Port(gt7ReceivePort)));
      print("[LOG] UDP receiver bound to port $gt7ReceivePort");
      return true;
    } catch (e) {
      print("[ERROR] Failed to bind UDP receiver: $e");
      // Update status on error
      statusNotifier.value =
          "ERROR: Failed to bind to port $gt7ReceivePort ($e)";
      receiver = null;
      return false;
    }
  }

  void startListening() async {
    // 1. Update the IP address
    targetIp = ipController.text.trim();
    print("[DEBUG] Target IP is set to: $targetIp");

    if (!isValidIp(targetIp)) {
      showInvalidIpDialog();
      return;
    }

    // Stop existing connection and free resources
    if (isListening || receiver != null) {
      stopListening();
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // Set the displayed IP to the user's input value
    currentDisplayedIpNotifier.value = targetIp;

    // Update status
    statusNotifier.value = "Binding to port $gt7ReceivePort...";

    // Bind UDP receiver
    if (!(await bindUdpReceiver())) {
      return;
    }

    setState(() => isListening = true);
    statusNotifier.value = "Listening on $targetIp. Awaiting packets...";

    // Reset raw counter and initialize UI
    _rawPacketCount = 0;
    packetCountNotifier.value = 0;

    // Setup timer to smooth the display (updates 5 times per second)
    _displayUpdateTimer?.cancel();
    _displayUpdateTimer = Timer.periodic(const Duration(milliseconds: 200), (
      timer,
    ) {
      // Update only if the raw value and the displayed value differ
      if (packetCountNotifier.value != _rawPacketCount) {
        packetCountNotifier.value = _rawPacketCount;
      }
    });

    // Setup Heartbeat timer (improved responsiveness by setting frequency to 100ms)
    _heartbeatTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) {
      sendHeartbeat();
    });

    // Start stream subscription
    udpSubscription = receiver!.asStream().listen(
      (datagram) {
        if (datagram == null) {
          print("DEBUG: Datagram is null.");
          return;
        }

        final receivedIp = datagram.address.host;
        // Check sender IP and ignore packets that do not match the targetIp
        if (receivedIp != targetIp) {
          print(
            "DEBUG: Received packet from wrong IP: $receivedIp (Expected: $targetIp)",
          );
          return;
        }

        final rawData = datagram.data;
        final decrypted = decodeSalsa20(rawData);

        if (decrypted.isEmpty) {
          print(
            "DEBUG: Decrypted data is empty (Magic number failed or decryption error).",
          );
          return;
        }

        // Increment raw packet count first
        _rawPacketCount++;

        // If packet reception is successful, display the actual sender IP
        if (currentDisplayedIpNotifier.value != receivedIp) {
          currentDisplayedIpNotifier.value = receivedIp;
          statusNotifier.value = "Receiving Data from $receivedIp";
        } else if (statusNotifier.value.contains("Awaiting") ||
            statusNotifier.value.startsWith("IDLE")) {
          statusNotifier.value = "Receiving Data from $receivedIp";
        }

        // RPM data
        final newRpm = getFloat(decrypted, RPM_OFFSET);
        rpmNotifier.value = newRpm;
        print("[DEBUG] Extracted RPM (Offset 0x3C): $newRpm");
      },
      // Stream error handler
      onError: (error) {
        print("[STREAM ERROR] UDP stream failed: $error");
        statusNotifier.value =
            "ERROR: Stream failed ($error). Please try restarting.";
        stopListening();
      },
      // Stream completion handler
      onDone: () {
        print("[STREAM DONE] UDP stream closed.");
        statusNotifier.value = "Connection Closed.";
        stopListening();
      },
    );
  }

  void stopListening() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    _displayUpdateTimer?.cancel(); // Cancel the display timer
    _displayUpdateTimer = null;

    udpSubscription?.cancel();
    udpSubscription = null;

    receiver?.close();
    receiver = null;

    setState(() => isListening = false);

    // Set to idle unless already in an error state
    if (!statusNotifier.value.startsWith("ERROR")) {
      statusNotifier.value = "IDLE: Listening stopped.";
    }

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
              ConnectionStatusDisplay(
                statusNotifier: statusNotifier,
              ), // Connection status display
              const Divider(height: 16),
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
              // Pass the Notifier
              PacketInfoDisplay(
                ipNotifier: currentDisplayedIpNotifier,
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
  // Receive Notifiers
  final ValueNotifier<String> ipNotifier;
  final ValueNotifier<int> countNotifier;

  const PacketInfoDisplay({
    super.key,
    required this.ipNotifier,
    required this.countNotifier,
  });

  @override
  Widget build(BuildContext context) {
    // Nest ValueListenableBuilder to react to IP address changes
    return ValueListenableBuilder<String>(
      valueListenable: ipNotifier,
      builder: (_, ip, __) => ValueListenableBuilder<int>(
        valueListenable: countNotifier,
        builder: (_, count, __) => Text(
          "Packets from $ip: $count",
          style: const TextStyle(fontSize: 16, color: Colors.blueGrey),
        ),
      ),
    );
  }
}

// Connection Status Display Widget
class ConnectionStatusDisplay extends StatelessWidget {
  final ValueNotifier<String> statusNotifier;

  const ConnectionStatusDisplay({super.key, required this.statusNotifier});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: statusNotifier,
      builder: (_, status, __) => Text(
        "Status: $status",
        style: TextStyle(
          fontSize: 16,
          // Change color based on error or connection status
          color:
              status.startsWith("ERROR") ||
                  status.contains("Closed") ||
                  status.startsWith("IDLE")
              ? Colors.red.shade700
              : status.startsWith("Receiving")
              ? Colors.green.shade700
              : Colors.orange.shade700,
          fontWeight: FontWeight.w500,
        ),
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
      style: ElevatedButton.styleFrom(
        backgroundColor: isListening ? Colors.red : Colors.green,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: isListening ? onStop : onStart,
      child: Text(
        isListening ? "Stop Receiving" : "Start Receiving",
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}
