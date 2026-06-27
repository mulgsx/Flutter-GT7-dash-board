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
  // 直近1秒間に受信したパケット数 = 受信レート（Hz）/ Packets received in the last 1 second = reception rate in Hz
  final ValueNotifier<double> packetRateNotifier = ValueNotifier(0.0);
  final ValueNotifier<String> statusNotifier = ValueNotifier('IDLE');
  final ValueNotifier<String> currentIpNotifier = ValueNotifier(defaultIp);
  final ValueNotifier<bool> isListeningNotifier = ValueNotifier(false);
  final TextEditingController ipController = TextEditingController(
    text: defaultIp,
  );

  UDP? _receiver;
  StreamSubscription? _udpSubscription;
  Timer? _heartbeatTimer;
  Timer? _displayUpdateTimer;

  // 60Hz でインクリメント。UIへの反映は _displayUpdateTimer で200ms に間引く
  // Incremented at 60 Hz; throttled to UI via _displayUpdateTimer at 200 ms
  int _rawPacketCount = 0;
  // Hz 計算用：直近パケットの受信時刻（マイクロ秒）をリングバッファ的に保持する
  // Holds recent packet timestamps (microseconds) for rolling 1-second Hz calculation
  final List<int> _packetTimestamps = [];
  String _targetIp = defaultIp;

  // アプリ起動時に SharedPreferences から前回保存した IP を復元する
  // 保存がない場合（初回起動など）は defaultIp を使う
  // Restores the previously saved IP from SharedPreferences on app launch;
  // falls back to defaultIp if nothing has been saved yet
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

  // IP アドレスの形式を検証する / Validates the IP address format
  bool isValidIp(String ip) => InternetAddress.tryParse(ip) != null;

  Future<void> startListening(String targetIp) async {
    // 前後の空白を削除する / Remove leading and trailing whitespace
    final ip = targetIp.trim();
    print('[DEBUG] Target IP is set to: $ip');

    // IP アドレスの形式を検証する / Validate the IP address format
    if (!isValidIp(ip)) {
      statusNotifier.value = 'ERROR: Invalid IP address format.';
      return;
    }

    // IP アドレスを保存する / Save the IP address
    await _saveIp(ip);
    _targetIp = ip;
    currentIpNotifier.value = ip;

    // 既にリスニングしている場合は停止する / Stop if already listening
    if (isListeningNotifier.value || _receiver != null) {
      stopListening();
      // ソケットが完全に閉じるまで待つ / Wait for the socket to fully close
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

    // 60fps の UI 再ビルドを抑制するため200ms で間引く / Throttle to suppress 60 fps UI rebuilds
    _displayUpdateTimer?.cancel();
    _displayUpdateTimer = Timer.periodic(const Duration(milliseconds: 200), (
      _,
    ) {
      if (packetCountNotifier.value != _rawPacketCount) {
        packetCountNotifier.value = _rawPacketCount;
      }
      // 1秒より古いタイムスタンプを除去し、残った数を Hz として通知する
      // Remove timestamps older than 1 second and report the remaining count as Hz
      final cutoff = DateTime.now().microsecondsSinceEpoch - 1000000;
      _packetTimestamps.removeWhere((t) => t < cutoff);
      packetRateNotifier.value = _packetTimestamps.length.toDouble();
    });

    // PS5 はこれが途絶えると約5秒でテレメトリ送信を停止する / PS5 stops sending within ~5s without this
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
    // 停止時にタイムスタンプとレートをリセットする / Reset timestamps and rate on stop
    _packetTimestamps.clear();
    packetRateNotifier.value = 0.0;

    // ERROR ステータスは停止時に上書きしない / Preserve ERROR status on stop
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
    // 対象外 IP からのパケットは無視する / Ignore packets from other senders
    if (receivedIp != _targetIp) {
      print(
        '[DEBUG] Received packet from wrong IP: $receivedIp (Expected: $_targetIp)',
      );
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
    // Hz 計算用にパケット受信時刻を記録する / Record packet arrival time for Hz calculation
    _packetTimestamps.add(DateTime.now().microsecondsSinceEpoch);

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
    packetRateNotifier.dispose();
    statusNotifier.dispose();
    currentIpNotifier.dispose();
    isListeningNotifier.dispose();
    ipController.dispose();
  }
}
