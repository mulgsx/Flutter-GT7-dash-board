import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:udp/udp.dart';
import 'dart:async';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'gt7_decoder.dart';
import 'gt7_drawer.dart';
import 'dashboard_screen.dart';
import 'race_dashboard_screen.dart';
import 'analog_dashboard_screen.dart';

// SharedPreferences Key for IP address
const String prefIpKey = 'gt7_ps5_ip';

void main() {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  // Hide status bar and navigation bar (Immersive Mode)
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Fix orientation to landscape (left and right)
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]).then((_) {
    runApp(
      const MaterialApp(home: GT7RpmApp(), debugShowCheckedModeBanner: false),
    );
  });
}

class GT7RpmApp extends StatefulWidget {
  const GT7RpmApp({super.key});

  @override
  GT7RpmAppState createState() => GT7RpmAppState();
}

class GT7RpmAppState extends State<GT7RpmApp> {
  final String defaultIp = "192.168.0.0";
  final ValueNotifier<double> rpmNotifier     = ValueNotifier<double>(0.0);
  final ValueNotifier<double> speedNotifier   = ValueNotifier<double>(0.0);
  final ValueNotifier<int>    gearNotifier    = ValueNotifier<int>(0);
  final ValueNotifier<double> throttleNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<double> brakeNotifier   = ValueNotifier<double>(0.0);
  final ValueNotifier<int>    rpmWarningNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int>    rpmLimiterNotifier = ValueNotifier<int>(0);

  // レースダッシュボード用
  final ValueNotifier<int>    lapCountNotifier       = ValueNotifier<int>(0);
  final ValueNotifier<int>    lapsInRaceNotifier     = ValueNotifier<int>(0);
  final ValueNotifier<int>    bestLapNotifier        = ValueNotifier<int>(-1);
  final ValueNotifier<int>    lastLapNotifier        = ValueNotifier<int>(-1);
  final ValueNotifier<int>    currentLapMsNotifier   = ValueNotifier<int>(0);
  final ValueNotifier<double> fuelLevelNotifier      = ValueNotifier<double>(0.0);
  final ValueNotifier<double> fuelCapacityNotifier   = ValueNotifier<double>(0.0);
  final ValueNotifier<double> lapsRemainingNotifier  = ValueNotifier<double>(0.0);
  final ValueNotifier<double> fuelPerLapNotifier     = ValueNotifier<double>(0.0);
  final ValueNotifier<double> tyreTempFLNotifier     = ValueNotifier<double>(0.0);
  final ValueNotifier<double> tyreTempFRNotifier     = ValueNotifier<double>(0.0);
  final ValueNotifier<double> tyreTempRLNotifier     = ValueNotifier<double>(0.0);
  final ValueNotifier<double> tyreTempRRNotifier     = ValueNotifier<double>(0.0);
  final ValueNotifier<double> tyreWearFLNotifier     = ValueNotifier<double>(0.0);
  final ValueNotifier<double> tyreWearFRNotifier     = ValueNotifier<double>(0.0);
  final ValueNotifier<double> tyreWearRLNotifier     = ValueNotifier<double>(0.0);
  final ValueNotifier<double> tyreWearRRNotifier     = ValueNotifier<double>(0.0);

  // ラップタイム計測用
  DateTime? _lapStartTime;
  int _prevLapCount = -1;
  double? _prevFuelLevel;
  double _fuelPerLap = 0.0;

  // 画面切り替え (0=Dashboard, 1=Race, 2=Analog)
  int _currentScreen = 0;

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
  void initState() {
    super.initState();
    _loadSavedIp(); // Load the saved IP address on startup
  }

  // Method to load the saved IP address from SharedPreferences
  void _loadSavedIp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Retrieve the saved IP string using the key. Use defaultIp if none is found.
      final savedIp = prefs.getString(prefIpKey) ?? defaultIp;

      ipController.text = savedIp;
      targetIp = savedIp;
      currentDisplayedIpNotifier.value = savedIp;

      print("[LOG] Loaded IP from prefs: $savedIp");
    } catch (e) {
      print("[ERROR] Failed to load IP from SharedPreferences: $e");
    }
  }

  // Method to save the valid IP address to SharedPreferences
  void _saveIp(String ip) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefIpKey, ip);
      print("[LOG] Saved IP to prefs: $ip");
    } catch (e) {
      print("[ERROR] Failed to save IP to SharedPreferences: $e");
    }
  }

  @override
  void dispose() {
    udpSubscription?.cancel();
    receiver?.close();
    _heartbeatTimer?.cancel();
    _displayUpdateTimer?.cancel(); // Cancel the display timer
    ipController.dispose();
    rpmNotifier.dispose();
    speedNotifier.dispose();
    gearNotifier.dispose();
    throttleNotifier.dispose();
    brakeNotifier.dispose();
    rpmWarningNotifier.dispose();
    rpmLimiterNotifier.dispose();
    lapCountNotifier.dispose();
    lapsInRaceNotifier.dispose();
    bestLapNotifier.dispose();
    lastLapNotifier.dispose();
    currentLapMsNotifier.dispose();
    fuelLevelNotifier.dispose();
    fuelCapacityNotifier.dispose();
    lapsRemainingNotifier.dispose();
    fuelPerLapNotifier.dispose();
    tyreTempFLNotifier.dispose();
    tyreTempFRNotifier.dispose();
    tyreTempRLNotifier.dispose();
    tyreTempRRNotifier.dispose();
    tyreWearFLNotifier.dispose();
    tyreWearFRNotifier.dispose();
    tyreWearRLNotifier.dispose();
    tyreWearRRNotifier.dispose();
    packetCountNotifier.dispose();
    statusNotifier.dispose();
    currentDisplayedIpNotifier.dispose();
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

    _saveIp(targetIp); // Save the valid IP address

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
        final decrypted = decodeSalsa20(rawData); // Use imported function

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

        // RPM
        rpmNotifier.value = getFloat(decrypted, rpmOffset);

        // 速度 (m/s → km/h)
        speedNotifier.value = getFloat(decrypted, speedOffset) * 3.6;

        // ギア (下位4ビット)
        gearNotifier.value = getUint8(decrypted, gearsOffset) & 0x0F;

        // スロットル / ブレーキ (0–255 → 0.0–1.0)
        throttleNotifier.value = getUint8(decrypted, throttleOffset) / 255.0;
        brakeNotifier.value    = getUint8(decrypted, brakeOffset)    / 255.0;

        // レブ警告 / リミッター（値が来た時だけ更新）
        final newWarn = getUint16(decrypted, rpmWarningOffset);
        if (newWarn > 0) rpmWarningNotifier.value = newWarn;
        final newLim = getUint16(decrypted, rpmLimiterOffset);
        if (newLim > 0) rpmLimiterNotifier.value = newLim;

        // ─── レースダッシュボード用データ ───────────────────────────────────

        // ラップカウント & 現在ラップタイム計測
        final lapCount = getUint16(decrypted, lapCountOffset);
        if (_prevLapCount >= 0 && lapCount != _prevLapCount) {
          // 新しいラップ開始
          final fuelNow = getFloat(decrypted, fuelLevelOffset);
          if (_prevFuelLevel != null) {
            final consumed = _prevFuelLevel! - fuelNow;
            if (consumed > 0) _fuelPerLap = consumed;
          }
          _prevFuelLevel = fuelNow;
          _lapStartTime  = DateTime.now();
        }
        if (_prevLapCount == -1) {
          _lapStartTime = DateTime.now();
          _prevFuelLevel = getFloat(decrypted, fuelLevelOffset);
        }
        _prevLapCount = lapCount;
        lapCountNotifier.value   = lapCount;
        lapsInRaceNotifier.value = getUint16(decrypted, lapsInRaceOffset);
        bestLapNotifier.value    = getInt32(decrypted, bestLapOffset);
        lastLapNotifier.value    = getInt32(decrypted, lastLapOffset);

        if (_lapStartTime != null) {
          currentLapMsNotifier.value =
              DateTime.now().difference(_lapStartTime!).inMilliseconds;
        }

        // 燃料
        final fuelLevel    = getFloat(decrypted, fuelLevelOffset);
        final fuelCapacity = getFloat(decrypted, fuelCapacityOffset);
        fuelLevelNotifier.value    = fuelLevel;
        fuelCapacityNotifier.value = fuelCapacity;
        if (_fuelPerLap > 0) {
          lapsRemainingNotifier.value = fuelLevel / _fuelPerLap;
          fuelPerLapNotifier.value    = _fuelPerLap;
        }

        // タイヤ温度
        tyreTempFLNotifier.value = getFloat(decrypted, tyreTempFLOffset);
        tyreTempFRNotifier.value = getFloat(decrypted, tyreTempFROffset);
        tyreTempRLNotifier.value = getFloat(decrypted, tyreTempRLOffset);
        tyreTempRRNotifier.value = getFloat(decrypted, tyreTempRROffset);

        // タイヤ摩耗（GT7は最大2.5程度のfloat → 0〜1 に正規化）
        tyreWearFLNotifier.value = (getFloat(decrypted, tyreWearFLOffset) / 2.5).clamp(0.0, 1.0);
        tyreWearFRNotifier.value = (getFloat(decrypted, tyreWearFROffset) / 2.5).clamp(0.0, 1.0);
        tyreWearRLNotifier.value = (getFloat(decrypted, tyreWearRLOffset) / 2.5).clamp(0.0, 1.0);
        tyreWearRRNotifier.value = (getFloat(decrypted, tyreWearRROffset) / 2.5).clamp(0.0, 1.0);
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

    // ラップ計測リセット
    _lapStartTime  = null;
    _prevLapCount  = -1;
    _prevFuelLevel = null;
    _fuelPerLap    = 0.0;
    currentLapMsNotifier.value  = 0;
    lapsRemainingNotifier.value = 0.0;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: ValueListenableBuilder<int>(
        valueListenable: packetCountNotifier,
        builder: (context, count, _) {
          return ValueListenableBuilder<String>(
            valueListenable: statusNotifier,
            builder: (context, status, _) {
              return GT7Drawer(
                ipController: ipController,
                isListening: isListening,
                onStart: startListening,
                onStop: stopListening,
                packetCount: count,
                status: status,
                currentScreen: _currentScreen,
                onScreenChange: (i) => setState(() => _currentScreen = i),
              );
            },
          );
        },
      ),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A14),
        elevation: 0,
        title: Text(
          _currentScreen == 1 ? 'GT7 RACE' : _currentScreen == 2 ? 'GT7 ANALOG' : 'GT7 DASHBOARD',
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 13,
            letterSpacing: 3,
          ),
        ),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white54),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      body: _currentScreen == 1
          ? RaceDashboard(
              rpmNotifier:           rpmNotifier,
              rpmWarningNotifier:    rpmWarningNotifier,
              rpmLimiterNotifier:    rpmLimiterNotifier,
              speedNotifier:         speedNotifier,
              lapCountNotifier:      lapCountNotifier,
              lapsInRaceNotifier:    lapsInRaceNotifier,
              bestLapNotifier:       bestLapNotifier,
              lastLapNotifier:       lastLapNotifier,
              currentLapMsNotifier:  currentLapMsNotifier,
              fuelLevelNotifier:     fuelLevelNotifier,
              fuelCapacityNotifier:  fuelCapacityNotifier,
              lapsRemainingNotifier: lapsRemainingNotifier,
              fuelPerLapNotifier:    fuelPerLapNotifier,
              tyreTempFLNotifier:    tyreTempFLNotifier,
              tyreTempFRNotifier:    tyreTempFRNotifier,
              tyreTempRLNotifier:    tyreTempRLNotifier,
              tyreTempRRNotifier:    tyreTempRRNotifier,
              tyreWearFLNotifier:    tyreWearFLNotifier,
              tyreWearFRNotifier:    tyreWearFRNotifier,
              tyreWearRLNotifier:    tyreWearRLNotifier,
              tyreWearRRNotifier:    tyreWearRRNotifier,
            )
          : _currentScreen == 2
          ? AnalogDashboard(
              rpmNotifier:          rpmNotifier,
              speedNotifier:        speedNotifier,
              gearNotifier:         gearNotifier,
              throttleNotifier:     throttleNotifier,
              brakeNotifier:        brakeNotifier,
              rpmWarningNotifier:   rpmWarningNotifier,
              rpmLimiterNotifier:   rpmLimiterNotifier,
              fuelLevelNotifier:    fuelLevelNotifier,
              fuelCapacityNotifier: fuelCapacityNotifier,
            )
          : RacingDashboard(
              rpmNotifier:        rpmNotifier,
              speedNotifier:      speedNotifier,
              gearNotifier:       gearNotifier,
              throttleNotifier:   throttleNotifier,
              brakeNotifier:      brakeNotifier,
              rpmWarningNotifier: rpmWarningNotifier,
              rpmLimiterNotifier: rpmLimiterNotifier,
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
