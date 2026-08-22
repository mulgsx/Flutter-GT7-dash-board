import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:udp/udp.dart';
import '../config/app_config.dart';
import '../models/gt7_models.dart';
import 'trajectory_notifier.dart';

enum StatusType { idle, connecting, receiving, error }

class GT7TelemetryService {
  final ValueNotifier<double> rpmNotifier = ValueNotifier(0.0);
  final ValueNotifier<int> gearNotifier = ValueNotifier(0);
  final ValueNotifier<int> revLimiterRpmNotifier = ValueNotifier(0);
  final ValueNotifier<double> fuelLevelNotifier = ValueNotifier(0.0);
  final ValueNotifier<double> fuelCapacityNotifier = ValueNotifier(0.0);
  // 直近ラップで消費した燃料（L）。ラップが1周完了するまでは 0 / Fuel burned on the last completed lap; 0 until one lap has finished
  final ValueNotifier<double> lapFuelConsumptionNotifier = ValueNotifier(0.0);
  final ValueNotifier<double> tireTempFLNotifier = ValueNotifier(0.0);
  final ValueNotifier<double> tireTempFRNotifier = ValueNotifier(0.0);
  final ValueNotifier<double> tireTempRLNotifier = ValueNotifier(0.0);
  final ValueNotifier<double> tireTempRRNotifier = ValueNotifier(0.0);
  final ValueNotifier<int> currentLapNotifier = ValueNotifier(0);
  final ValueNotifier<int> totalLapsNotifier = ValueNotifier(-1);
  final ValueNotifier<int> lastLapTimeNotifier = ValueNotifier(-1);
  final ValueNotifier<int> bestLapTimeNotifier = ValueNotifier(-1);
  final ValueNotifier<bool> tcsActiveNotifier = ValueNotifier(false);
  final ValueNotifier<int> packetCountNotifier = ValueNotifier(0);
  // 直近1秒間に受信したパケット数 = 受信レート（Hz）/ Packets received in the last 1 second = reception rate in Hz
  final ValueNotifier<double> packetRateNotifier = ValueNotifier(0.0);
  final ValueNotifier<String> statusNotifier = ValueNotifier('IDLE');
  final ValueNotifier<StatusType> statusTypeNotifier = ValueNotifier(
    StatusType.idle,
  );
  final ValueNotifier<String> currentIpNotifier = ValueNotifier(defaultIp);
  final ValueNotifier<bool> isListeningNotifier = ValueNotifier(false);
  final TextEditingController ipController = TextEditingController(
    text: defaultIp,
  );
  final ValueNotifier<int> revWarningRpmNotifier = ValueNotifier(0);
  final TextEditingController revWarningController = TextEditingController();
  final FocusNode revWarningFocusNode = FocusNode();
  // car_id が確定するまで（＝GT7未接続の間）は入力欄を非活性にする
  // Disabled until car_id is known (i.e. before GT7 is connected)
  final ValueNotifier<bool> revWarningEditableNotifier = ValueNotifier(false);
  final TrajectoryNotifier trajectory = TrajectoryNotifier();
  // 直近にデコードした生パケット。ダッシュボード表示に含まれない項目（燃料・
  // タイヤ温度・ラップ番号など）を使いたい他機能向けの購読ポイント
  // The most recently decoded raw packet. A subscription point for other
  // features that need fields the dashboard doesn't surface (fuel, tyre
  // temps, lap number, etc.)
  final ValueNotifier<GT7Packet?> latestPacketNotifier = ValueNotifier(null);

  UDP? _receiver;
  StreamSubscription? _udpSubscription;
  Timer? _heartbeatTimer;
  Timer? _displayUpdateTimer;
  // 現在受信中の車の car_id。未受信時は null / car_id of the currently connected car; null until known
  int? _currentCarId;
  // true の間はライブ値で上書きしない（ユーザーの手動入力を優先） / While true, skip live-telemetry updates
  bool _revWarningIsOverride = false;

  // 消費量計算用：現在のラップが始まった時点の燃料残量と、そのラップ番号
  // For consumption tracking: fuel level when the current lap began, and which lap that was
  double? _fuelAtLapStart;
  int? _lapAtFuelStart;
  // 接続直後の最初の区間はラップ境界の途中から計測が始まっている可能性が高く、
  // 実際の1周分より短い距離しか含まないため、消費量として信用しない
  // The interval right after connecting likely starts mid-lap and covers less
  // than a true full lap, so its consumption sample can't be trusted
  bool _awaitingFirstFullLap = true;

  GT7TelemetryService() {
    // フォーカスが外れた瞬間に入力を確定・保存する / Commit and persist the value the moment focus is lost
    revWarningFocusNode.addListener(_onRevWarningFocusChange);
  }

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
      debugPrint('[LOG] Loaded IP from prefs: $saved');
    } catch (e) {
      debugPrint('[ERROR] Failed to load IP from SharedPreferences: $e');
    }
  }

  /// IP アドレスを SharedPreferences に保存する / Saves the IP address to SharedPreferences
  Future<void> _saveIp(String ip) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefIpKey, ip);
      debugPrint('[LOG] Saved IP to prefs: $ip');
    } catch (e) {
      debugPrint('[ERROR] Failed to save IP to SharedPreferences: $e');
    }
  }

  /// IP アドレスの形式を検証する / Validates the IP address format
  bool isValidIp(String ip) => InternetAddress.tryParse(ip) != null;

  Future<bool> startListening(String targetIp) async {
    // 前後の空白を削除する / Remove leading and trailing whitespace
    final ip = targetIp.trim();
    debugPrint('[DEBUG] Target IP is set to: $ip');

    // IP アドレスの形式を検証する / Validate the IP address format
    if (!isValidIp(ip)) {
      statusNotifier.value = 'ERROR: Invalid IP address format.';
      statusTypeNotifier.value = StatusType.error;
      return false;
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
    statusTypeNotifier.value = StatusType.connecting;

    try {
      // UDP レシーバーを指定されたポートにバインドする / Bind UDP receiver to the specified port
      _receiver = await UDP.bind(Endpoint.any(port: Port(receivePort)));
      debugPrint('[LOG] UDP receiver bound to port $receivePort');
    } catch (e) {
      debugPrint('[ERROR] Failed to bind UDP receiver: $e');
      statusNotifier.value = 'ERROR: Failed to bind to port $receivePort ($e)';
      statusTypeNotifier.value = StatusType.error;
      _receiver = null;
      return false;
    }
    // リスニング状態を更新する / Update listening state
    isListeningNotifier.value = true;
    statusNotifier.value = 'Listening on $_targetIp. Awaiting packets...';
    statusTypeNotifier.value = StatusType.connecting;

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
        debugPrint('[STREAM ERROR] UDP stream failed: $error');
        statusNotifier.value =
            'ERROR: Stream failed ($error). Please try restarting.';
        statusTypeNotifier.value = StatusType.error;
        stopListening();
      },
      onDone: () {
        debugPrint('[STREAM DONE] UDP stream closed.');
        statusNotifier.value = 'Connection Closed.';
        statusTypeNotifier.value = StatusType.idle;
        stopListening();
      },
    );

    return true;
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
    // 未接続状態に戻すため、Rev Warning 欄も非活性にする / Disable the Rev Warning field again, back to "not connected"
    revWarningEditableNotifier.value = false;
    // 次回接続時は改めて1周分のデータが揃うまで消費量を出さない
    // On reconnect, wait for a fresh full lap before reporting consumption again
    _fuelAtLapStart = null;
    _lapAtFuelStart = null;

    // ERROR ステータスは停止時に上書きしない / Preserve ERROR status on stop
    if (!statusNotifier.value.startsWith('ERROR')) {
      statusNotifier.value = 'IDLE: Listening stopped.';
      statusTypeNotifier.value = StatusType.idle;
    }

    debugPrint('[LOG] Listening stopped.');
  }

  // ラップ番号が進んだ瞬間の燃料残量の差分から、直近1周分の消費量を算出する
  // Derives last-lap fuel consumption from the fuel-level delta at each lap-number transition
  void _trackLapFuelConsumption(int currentLap, double fuelLevel) {
    if (_lapAtFuelStart == null || currentLap < _lapAtFuelStart!) {
      // 初回、またはラップ数が巻き戻った＝レースがリセットされた合図。
      // 古い消費量を持ち越さずクリアしてから新しいラップの計測を始める
      // First tick, or the lap count rewound — signals a race reset.
      // Clear the stale consumption value before starting a fresh lap baseline
      _lapAtFuelStart = currentLap;
      _fuelAtLapStart = fuelLevel;
      _awaitingFirstFullLap = true;
      lapFuelConsumptionNotifier.value = 0.0;
      return;
    }
    if (currentLap == _lapAtFuelStart) return;

    if (_awaitingFirstFullLap) {
      // 接続直後の最初の区間は実際の1周分より短い可能性が高いので、
      // 消費量としては採用せず、ここを新たな基準点にするだけにとどめる
      // The first interval after connecting likely covers less than a true
      // full lap — don't record it as a consumption sample, just re-baseline
      _awaitingFirstFullLap = false;
      _lapAtFuelStart = currentLap;
      _fuelAtLapStart = fuelLevel;
      return;
    }

    final consumed = _fuelAtLapStart! - fuelLevel;
    if (consumed > 0) {
      lapFuelConsumptionNotifier.value = consumed;
    }
    _lapAtFuelStart = currentLap;
    _fuelAtLapStart = fuelLevel;
  }

  void _handlePacket(Datagram? datagram) {
    if (datagram == null) {
      debugPrint('[DEBUG] Datagram is null.');
      return;
    }

    final receivedIp = datagram.address.host;
    // 対象外 IP からのパケットは無視する / Ignore packets from other senders
    if (receivedIp != _targetIp) {
      debugPrint(
        '[DEBUG] Received packet from wrong IP: $receivedIp (Expected: $_targetIp)',
      );
      return;
    }

    final rawData = datagram.data;
    debugPrint('[DEBUG] Packet size: ${rawData.length}');

    final decrypted = GT7Decoder.decodeSalsa20(rawData);
    if (decrypted.isEmpty) {
      // debugPrint('[DEBUG] Decrypted data is empty.');
      return;
    }

    _rawPacketCount++;
    // Hz 計算用にパケット受信時刻を記録する / Record packet arrival time for Hz calculation
    _packetTimestamps.add(DateTime.now().microsecondsSinceEpoch);

    if (currentIpNotifier.value != receivedIp) {
      currentIpNotifier.value = receivedIp;
      statusNotifier.value = 'Receiving Data from $receivedIp';
      statusTypeNotifier.value = StatusType.receiving;
    } else if (statusNotifier.value.contains('Awaiting') ||
        statusNotifier.value.startsWith('IDLE')) {
      statusNotifier.value = 'Receiving Data from $receivedIp';
      statusTypeNotifier.value = StatusType.receiving;
    }

    final packet = GT7Packet.fromBytes(decrypted);
    rpmNotifier.value = packet.engineRPM;
    trajectory.addPoint(packet.positionX, packet.positionZ);
    latestPacketNotifier.value = packet;

    gearNotifier.value = packet.gear;
    fuelLevelNotifier.value = packet.currentFuel;
    fuelCapacityNotifier.value = packet.fuelCapacity;
    tireTempFLNotifier.value = packet.tyreTempFL;
    tireTempFRNotifier.value = packet.tyreTempFR;
    tireTempRLNotifier.value = packet.tyreTempRL;
    tireTempRRNotifier.value = packet.tyreTempRR;
    tcsActiveNotifier.value = packet.tcsActive;
    if (packet.revLimiterRpm != -1) {
      revLimiterRpmNotifier.value = packet.revLimiterRpm;
    }
    if (packet.currentLap != -1) {
      _trackLapFuelConsumption(packet.currentLap, packet.currentFuel);
      currentLapNotifier.value = packet.currentLap;
    }
    totalLapsNotifier.value = packet.totalLaps;
    // lastLapTime/bestLapTime は -1 =「未設定」がゲーム側の正規の意味なので、
    // ここでは常にそのまま反映する（-1で握りつぶすとレースリセット後も
    // 前回のベストラップが表示され続けてしまう）
    // -1 is the game's own "not set" signal for lastLapTime/bestLapTime, so
    // always mirror it as-is — filtering it out left the previous session's
    // best lap stuck on screen after a race reset
    lastLapTimeNotifier.value = packet.lapTime;
    if (packet.bestLapMs == -1 && bestLapTimeNotifier.value != -1) {
      // ベストラップが「未設定」に戻った＝レースがリセットされた合図。
      // 直近ラップ燃料消費の追跡も持ち越さないようにクリアする
      // bestLapTime reverting to unset signals a race reset — also clear the
      // per-lap fuel consumption tracking so a stale value doesn't carry over
      _fuelAtLapStart = null;
      _lapAtFuelStart = null;
      lapFuelConsumptionNotifier.value = 0.0;
    }
    bestLapTimeNotifier.value = packet.bestLapMs;

    if (packet.carId != -1) {
      // 受信中は常に活性化する（stopListening() で非活性に戻す）
      // Stays enabled while receiving (stopListening() disables it again)
      revWarningEditableNotifier.value = true;
    }

    if (packet.carId != -1 && packet.carId != _currentCarId) {
      // 車が変わった（または初めて確定した）→ その車の保存値を読み込む
      // Car changed (or became known for the first time) → load that car's saved override
      _currentCarId = packet.carId;
      debugPrint('[DEBUG] Car ID: ${packet.carId}');
      unawaited(_loadRevWarningForCar(packet.carId, packet.revWarningRpm));
    } else if (!_revWarningIsOverride &&
        !revWarningFocusNode.hasFocus &&
        packet.revWarningRpm != -1) {
      // 上書き中でも入力中でもなければライブ値に追従させる
      // Track the live value as long as it isn't overridden and the user isn't mid-edit
      _applyRevWarningValue(packet.revWarningRpm, isOverride: false);
    }
  }

  void _applyRevWarningValue(int value, {required bool isOverride}) {
    revWarningRpmNotifier.value = value;
    _revWarningIsOverride = isOverride;
    // 入力中にコントローラの文字列を書き換えてカーソル位置や入力中の内容を壊さないようにする
    // Don't clobber in-progress typing/cursor position while the field has focus
    if (!revWarningFocusNode.hasFocus) {
      revWarningController.text = value.toString();
    }
  }

  // 車が変わった際に呼ばれる：保存済みの上書き値があればそれを、なければライブ値を採用する
  // Called on car change: prefers the saved override for this car, falls back to the live telemetry value
  Future<void> _loadRevWarningForCar(int carId, int fallbackLiveValue) async {
    _revWarningIsOverride = false;
    if (fallbackLiveValue != -1) {
      _applyRevWarningValue(fallbackLiveValue, isOverride: false);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      // await 中に別の車へ切り替わっていたら、この結果は古いので破棄する
      // Discard this result if the car changed again while awaiting (race guard)
      if (_currentCarId != carId) return;

      final saved = prefs.getInt(revWarningPrefKey(carId));
      if (saved != null) {
        _applyRevWarningValue(saved, isOverride: true);
      }
    } catch (e) {
      debugPrint(
        '[ERROR] Failed to load rev warning from SharedPreferences: $e',
      );
    }
  }

  void _onRevWarningFocusChange() {
    if (!revWarningFocusNode.hasFocus) {
      unawaited(commitRevWarningOverride(revWarningController.text));
    }
  }

  /// フィールドの内容を手動オーバーライドとして確定・永続化する
  /// Commits the field's contents as a manual override and persists it
  /// (呼び出し元: フォーカスロスト時 / TextField.onSubmitted)
  /// (Callers: on focus loss / TextField.onSubmitted)
  Future<void> commitRevWarningOverride(String text) async {
    final parsed = int.tryParse(text.trim());
    if (parsed == null || parsed <= 0) {
      // 不正な入力は破棄し、直前の値に戻す / Reject invalid input, revert to the last known value
      revWarningController.text = revWarningRpmNotifier.value > 0
          ? revWarningRpmNotifier.value.toString()
          : '';
      return;
    }

    _revWarningIsOverride = true;
    revWarningRpmNotifier.value = parsed;

    if (_currentCarId == null) {
      // car_id 未確定の間は保存キーが定まらないためメモリ上のみ有効
      // Can't persist without a known car_id yet; stays in-memory only until a packet establishes one
      debugPrint(
        '[LOG] Rev warning override set before car_id known; not persisted yet.',
      );
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(revWarningPrefKey(_currentCarId!), parsed);
      debugPrint(
        '[LOG] Saved rev warning override for car $_currentCarId: $parsed',
      );
    } catch (e) {
      debugPrint('[ERROR] Failed to save rev warning to SharedPreferences: $e');
    }
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
      debugPrint('[ERROR] Heartbeat failed: $e');
    }
  }

  void dispose() {
    stopListening();
    rpmNotifier.dispose();
    gearNotifier.dispose();
    revLimiterRpmNotifier.dispose();
    fuelLevelNotifier.dispose();
    fuelCapacityNotifier.dispose();
    lapFuelConsumptionNotifier.dispose();
    tireTempFLNotifier.dispose();
    tireTempFRNotifier.dispose();
    tireTempRLNotifier.dispose();
    tireTempRRNotifier.dispose();
    currentLapNotifier.dispose();
    totalLapsNotifier.dispose();
    lastLapTimeNotifier.dispose();
    bestLapTimeNotifier.dispose();
    tcsActiveNotifier.dispose();
    packetCountNotifier.dispose();
    packetRateNotifier.dispose();
    statusNotifier.dispose();
    statusTypeNotifier.dispose();
    currentIpNotifier.dispose();
    isListeningNotifier.dispose();
    ipController.dispose();
    revWarningRpmNotifier.dispose();
    revWarningFocusNode.removeListener(_onRevWarningFocusChange);
    revWarningFocusNode.dispose();
    revWarningController.dispose();
    revWarningEditableNotifier.dispose();
    trajectory.dispose();
    latestPacketNotifier.dispose();
  }
}
