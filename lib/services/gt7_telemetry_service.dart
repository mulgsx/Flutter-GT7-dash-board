import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:udp/udp.dart';
import '../config/app_config.dart';
import '../models/gt7_models.dart';

class GT7TelemetryService {
  final ValueNotifier<double> rpmNotifier = ValueNotifier(0.0);
  final ValueNotifier<int> packetCountNotifier = ValueNotifier(0);
  final ValueNotifier<String> statusNotifier = ValueNotifier('IDLE');
  final ValueNotifier<String> currentIpNotifier = ValueNotifier(defaultIp);
  final ValueNotifier<bool> isListeningNotifier = ValueNotifier(false);
  final TextEditingController ipController = TextEditingController(text: defaultIp);

  UDP? _receiver;
  StreamSubscription? _udpSubscription;
  Timer? _heartbeatTimer;
  Timer? _displayUpdateTimer;

  int _rawPacketCount = 0;
  String _targetIp = defaultIp;

  Future<void> loadSavedIp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(prefIpKey) ?? defaultIp;
      currentIpNotifier.value = saved;
      ipController.text = saved;
      _targetIp = saved;
      print('[LOG] Loaded IP from prefs: $saved');
    } catch (e) {
      print('[ERROR] Failed to load IP from SharedPreferences: $e');
    }
  }

  Future<void> _saveIp(String ip) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefIpKey, ip);
      print('[LOG] Saved IP to prefs: $ip');
    } catch (e) {
      print('[ERROR] Failed to save IP to SharedPreferences: $e');
    }
  }

  bool isValidIp(String ip) => InternetAddress.tryParse(ip) != null;

  Future<void> startListening(String targetIp) async {
    final ip = targetIp.trim();
    print('[DEBUG] Target IP is set to: $ip');

    if (!isValidIp(ip)) {
      statusNotifier.value = 'ERROR: Invalid IP address format.';
      return;
    }

    await _saveIp(ip);
    _targetIp = ip;
    currentIpNotifier.value = ip;

    if (isListeningNotifier.value || _receiver != null) {
      stopListening();
      await Future.delayed(const Duration(milliseconds: 100));
    }

    statusNotifier.value = 'Binding to port $receivePort...';

    try {
      _receiver = await UDP.bind(Endpoint.any(port: Port(receivePort)));
      print('[LOG] UDP receiver bound to port $receivePort');
    } catch (e) {
      print('[ERROR] Failed to bind UDP receiver: $e');
      statusNotifier.value = 'ERROR: Failed to bind to port $receivePort ($e)';
      _receiver = null;
      return;
    }

    isListeningNotifier.value = true;
    statusNotifier.value = 'Listening on $_targetIp. Awaiting packets...';

    _rawPacketCount = 0;
    packetCountNotifier.value = 0;

    _displayUpdateTimer?.cancel();
    _displayUpdateTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (packetCountNotifier.value != _rawPacketCount) {
        packetCountNotifier.value = _rawPacketCount;
      }
    });

    _heartbeatTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _sendHeartbeat();
    });

    _udpSubscription = _receiver!.asStream().listen(
      _handlePacket,
      onError: (error) {
        print('[STREAM ERROR] UDP stream failed: $error');
        statusNotifier.value =
            'ERROR: Stream failed ($error). Please try restarting.';
        stopListening();
      },
      onDone: () {
        print('[STREAM DONE] UDP stream closed.');
        statusNotifier.value = 'Connection Closed.';
        stopListening();
      },
    );
  }

  void stopListening() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    _displayUpdateTimer?.cancel();
    _displayUpdateTimer = null;

    _udpSubscription?.cancel();
    _udpSubscription = null;

    _receiver?.close();
    _receiver = null;

    isListeningNotifier.value = false;

    if (!statusNotifier.value.startsWith('ERROR')) {
      statusNotifier.value = 'IDLE: Listening stopped.';
    }

    print('[LOG] Listening stopped.');
  }

  void _handlePacket(Datagram? datagram) {
    if (datagram == null) {
      print('[DEBUG] Datagram is null.');
      return;
    }

    final receivedIp = datagram.address.host;
    if (receivedIp != _targetIp) {
      print('[DEBUG] Received packet from wrong IP: $receivedIp (Expected: $_targetIp)');
      return;
    }

    final rawData = datagram.data;
    print('[DEBUG] Packet size: ${rawData.length}');

    final decrypted = GT7Decoder.decodeSalsa20(rawData);
    if (decrypted.isEmpty) {
      print('[DEBUG] Decrypted data is empty.');
      return;
    }

    _rawPacketCount++;

    if (currentIpNotifier.value != receivedIp) {
      currentIpNotifier.value = receivedIp;
      statusNotifier.value = 'Receiving Data from $receivedIp';
    } else if (statusNotifier.value.contains('Awaiting') ||
        statusNotifier.value.startsWith('IDLE')) {
      statusNotifier.value = 'Receiving Data from $receivedIp';
    }

    final packet = GT7Packet.fromBytes(decrypted);
    rpmNotifier.value = packet.engineRPM;
  }

  void _sendHeartbeat() async {
    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      try {
        socket.send('A'.codeUnits, InternetAddress(_targetIp), sendPort);
      } finally {
        socket.close();
      }
    } catch (e) {
      print('[ERROR] Heartbeat failed: $e');
    }
  }

  void dispose() {
    stopListening();
    rpmNotifier.dispose();
    packetCountNotifier.dispose();
    statusNotifier.dispose();
    currentIpNotifier.dispose();
    isListeningNotifier.dispose();
    ipController.dispose();
  }
}
