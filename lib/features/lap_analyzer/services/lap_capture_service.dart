import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../../models/gt7_models.dart';
import '../../../services/gt7_telemetry_service.dart';
import '../models/lap_capture.dart';
import '../models/telemetry_sample.dart';

/// last_lap(直前ラップタイム)の値の変化をラップ境界として検知し、その周回中の
/// テレメトリを TelemetrySample としてバッファ・確定する。ターゲット/ベストの
/// 1周キャプチャと、全ラップの自動ログ書き出しの両方の基盤となる。
///
/// Detects lap boundaries via changes in last_lap (the previous-lap-time field),
/// buffering and finalizing the telemetry recorded during each lap as
/// TelemetrySamples. This is the shared foundation for both target/best one-lap
/// capture and the always-on per-lap log.
class LapCaptureService {
  // 確定時に、この速度未満の先頭/末尾サンプルを切り落とす。ゴール後の減速〜停止〜
  // 待機〜次のスタート前の加速、といった「実質的に走っていない」区間を1周分の
  // データから除外するための閾値
  // At finalization, leading/trailing samples below this speed are trimmed off.
  // Excludes the "not really driving" stretch — decelerating after the finish,
  // sitting stopped, then accelerating again before the next start — from the
  // recorded lap.
  static const double _drivingSpeedThresholdKmh = 5.0;
  // トリム後の区間のどこか(先頭・末尾に限らず)にこの速度未満のサンプルがあれば、
  // 「ゴール後に停止 → リプレイがループして再走行」を1区間の中で拾ってしまった
  // 誤検知とみなし、区間ごと破棄する。末尾だけを見ていた頃は、停止~ループが
  // 区間の途中で起きて末尾は再加速後の高速サンプルになるケースを見逃していた
  // If any sample anywhere in the (edge-trimmed) segment is below this speed,
  // it's treated as having captured a "coasted to a stop, then the replay
  // looped back and re-accelerated" event somewhere inside the segment, and
  // the whole segment is discarded. Checking only the last sample used to miss
  // this whenever the stop+loop landed mid-segment and the segment happened to
  // end back at high speed after re-accelerating.
  static const double _minValidEndSpeedKmh = 10.0;
  // 1サンプル間でこれを超える距離が動いていたら「瞬間移動」とみなす。実機ログを
  // 確認したところ、ゴール後に停止して終わるとは限らず、速度が高いまま位置だけ
  // 一瞬でワープする(=リプレイのループ再生地点)パターンがあった。これは速度の
  // 閾値では検知できないため、位置のジャンプそのものを見る
  // Any single-sample position delta beyond this is treated as a "teleport".
  // Real device logs showed the replay loop-restart doesn't always coast to a
  // stop first — sometimes the position jumps instantly while speed stays
  // high, which a speed-based threshold can never catch. So the position jump
  // itself is checked directly.
  static const double _maxPlausiblePositionJumpMeters = 40.0;
  // どの境界で開始された区間であっても、実測時間(最後のサンプルの elapsedMs)
  // が申告された last_lap 値のこの割合未満なら「本来の1周よりずっと短い断片を
  // 拾っただけ」とみなして破棄する。実機ログでは、リプレイを見ている間は
  // current_lap だけでなく last_lap の境界そのものも、実際の1周にかかる時間
  // より大幅に短い間隔で切り替わることがあると確認できたため(スクラブ操作や
  // 早送りなど)、区間の開始方法を問わずこの安全策を常に適用する
  // Regardless of how a segment began, if its measured duration (the last
  // sample's elapsedMs) falls below this fraction of the claimed last_lap
  // value, it's treated as just a fragment far shorter than a real lap and
  // discarded. Real device logs showed that while watching a replay, not
  // just current_lap but even last_lap boundaries themselves can flip on an
  // interval far shorter than a real lap takes (e.g. scrubbing/fast-forward),
  // so this safety net applies unconditionally, no matter how the segment started.
  static const double _minPlausibleDurationFraction = 0.7;
  // 破棄された直後に白で表示する期間。次のサンプルが来た瞬間に切り替えると
  // 1フレームも描画されずに終わってしまうため、目に見える程度の時間だけ保持する
  // How long the "just discarded" white indicator stays up. Switching back the
  // instant the next sample arrives would end before a single frame ever
  // rendered it, so this holds it for a duration a human can actually notice.
  static const Duration _discardFlashDuration = Duration(seconds: 1);

  final GT7TelemetryService telemetryService;
  // 種別を問わず、ラップが1周完了するたびに呼ばれる / Called for every completed lap, regardless of type
  final void Function(LapCapture lap) onLapCompleted;
  // target/best のキャプチャが完了したときだけ呼ばれる / Called only when a target/best capture completes
  final void Function(LapCapture lap) onReferenceLapCaptured;

  // 経過時間の計算に使う時計。テストから偽の時計を注入できるようにするための
  // 差し替え口(本番は常にDateTime.now)
  // The clock used for elapsed-time calculations. A seam for tests to inject
  // a fake clock (defaults to DateTime.now in production).
  final DateTime Function() _now;

  LapCaptureService({
    required this.telemetryService,
    required this.onLapCompleted,
    required this.onReferenceLapCaptured,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    telemetryService.latestPacketNotifier.addListener(_onPacket);
  }

  // 直近確定したサンプル(現在の走行距離・経過時間などをリアルタイム比較に提供する)
  // The most recently finalized sample, feeding real-time comparison with current distance/elapsed time
  final ValueNotifier<TelemetrySample?> currentSampleNotifier = ValueNotifier(
    null,
  );
  // target/best のキャプチャ待機中かどうか(UI表示用) / Whether a target/best capture is pending (for UI display)
  final ValueNotifier<LapType?> pendingCaptureNotifier = ValueNotifier(null);
  // 次のラップ境界(=公式なスタート/ゴール通過)でアームされ、実際にキャプチャ対象の
  // ラップを計測し始めたかどうか。false の間は currentLapSamples に「たまたま
  // 今走っている途中のラップ」の古いデータが残っている場合があるため、UI側は
  // これがtrueになるまで軌跡を表示すべきではない
  // Whether we've armed at the next lap boundary (the official start/finish
  // crossing) and are now actually recording the lap to be captured. While
  // false, currentLapSamples may still hold leftover data from whatever lap
  // happened to be in progress already — the UI should not display it until
  // this becomes true.
  final ValueNotifier<bool> isArmedRecordingNotifier = ValueNotifier(false);
  // 直前に確定した区間が破棄された(=無効化された)かどうか。true の間、UI側は
  // 現在計測中の軌跡を「アーム済みなら赤」ではなく白で表示すべき
  // Whether the most recently finalized segment was discarded (invalidated).
  // While true, the UI should render the in-progress trajectory in white
  // rather than red, even if armed.
  final ValueNotifier<bool> wasLastSegmentDiscardedNotifier = ValueNotifier(
    false,
  );
  Timer? _discardFlashTimer;
  // 本物のラップ境界(last_lapの変化)が起きるたびにインクリメントされる。
  // 位置の瞬間移動によるバッファリセットではインクリメントしない。
  // リアルタイム比較側が「本当に新しいラップが始まった」ことを知るための信号
  // Increments every time a genuine lap boundary (a last_lap change) occurs.
  // Does NOT increment for a mid-segment position-teleport buffer reset. This
  // is how the real-time comparison side knows a lap has genuinely started.
  final ValueNotifier<int> lapStartEventNotifier = ValueNotifier(0);

  // 現在計測中のラップのサンプル列(進捗表示用)。currentSampleNotifier が
  // 変化するたびに末尾へ1件追加される。ラップ境界で新しいリストに差し替わる
  // The current in-progress lap's samples (for progress display). One entry is
  // appended each time currentSampleNotifier changes; replaced with a fresh
  // list at each lap boundary.
  List<TelemetrySample> get currentLapSamples => _buffer;

  List<TelemetrySample> _buffer = [];
  int? _lastSeenLapTimeMs;
  double _cumulativeDistance = 0;
  ({double x, double y, double z})? _lastPosition;
  DateTime? _lapStartWallClock;
  LapType? _requestedCaptureType;
  bool _captureArmedForCurrentLap = false;

  /// ターゲット/ベストのキャプチャを要求する。次のラップ境界から始まる
  /// 1周をまるごと記録し、完了時に onReferenceLapCaptured を呼ぶ
  /// Requests a target/best capture. The full lap starting at the next lap
  /// boundary is recorded, and onReferenceLapCaptured fires once it completes.
  void requestCapture(LapType type) {
    assert(type != LapType.practice);
    _requestedCaptureType = type;
    _captureArmedForCurrentLap = false;
    isArmedRecordingNotifier.value = false;
    _discardFlashTimer?.cancel();
    wasLastSegmentDiscardedNotifier.value = false;
    pendingCaptureNotifier.value = type;
  }

  void cancelCapture() {
    _requestedCaptureType = null;
    _captureArmedForCurrentLap = false;
    isArmedRecordingNotifier.value = false;
    pendingCaptureNotifier.value = null;
  }

  void dispose() {
    telemetryService.latestPacketNotifier.removeListener(_onPacket);
    _discardFlashTimer?.cancel();
    currentSampleNotifier.dispose();
    pendingCaptureNotifier.dispose();
    isArmedRecordingNotifier.dispose();
    wasLastSegmentDiscardedNotifier.dispose();
    lapStartEventNotifier.dispose();
  }

  // 一時的な診断用: current_lap/last_lap の生の変化を記録する(原因調査後に削除)
  // Temporary diagnostics: logs raw current_lap/last_lap changes (remove once root-caused)
  int? _debugLastCurrentLap;
  int? _debugLastLapTime;

  void _onPacket() {
    final packet = telemetryService.latestPacketNotifier.value;
    if (packet == null) return;
    if (packet.currentLap == -1) return; // セッション未確定 / No session yet

    if (packet.currentLap != _debugLastCurrentLap ||
        packet.lapTime != _debugLastLapTime) {
      debugPrint(
        '[LAP_DEBUG] t=${DateTime.now().toIso8601String()} '
        'currentLap=${packet.currentLap} lapTime=${packet.lapTime} '
        'speed=${packet.speedKmh.toStringAsFixed(1)} '
        'pos=(${packet.positionX.toStringAsFixed(1)},'
        '${packet.positionZ.toStringAsFixed(1)})',
      );
      _debugLastCurrentLap = packet.currentLap;
      _debugLastLapTime = packet.lapTime;
    }

    _lastSeenLapTimeMs ??= packet.lapTime;

    // ラップ完了は last_lap(直前ラップタイム)の値が変わったことで検知する。
    // 当初は current_lap の増加を境界にしていたが、実機ログを確認したところ
    // current_lap は(特にリプレイ再生中)必ずしも1周ごとに正しく増加せず、
    // 数周分がまとめてバッファされたり、逆に1周の途中で区切られたりしていた。
    // last_lap の値そのものは毎ラップ正しく更新されていたため、こちらを
    // 信頼できる境界信号として採用する
    // A completed lap is detected via last_lap (the previous-lap-time field)
    // changing value, rather than current_lap increasing. Real device logs
    // showed current_lap doesn't reliably increment once per lap (especially
    // while watching a replay) — sometimes several laps got buffered together,
    // sometimes a lap was cut off partway through. last_lap itself updated
    // correctly every lap, so it's used as the trustworthy boundary signal instead.
    if (packet.lapTime >= 0 && packet.lapTime != _lastSeenLapTimeMs) {
      _completeLap(packet);
    }

    _accumulateSample(packet);
  }

  void _completeLap(GT7Packet packet) {
    final rawFinishedSamples = _buffer;
    final finishedStartTime = _lapStartWallClock;
    final finishedLapTimeMs = packet.lapTime; // last_lap: 直前ラップのタイム
    final wasArmedCapture =
        _requestedCaptureType != null && _captureArmedForCurrentLap;

    // 新しいラップの計測を開始する / Start tracking the new lap
    _resetSegmentTracking();
    _lapStartWallClock = _now();
    _lastSeenLapTimeMs = packet.lapTime;
    lapStartEventNotifier.value++;
    _armIfRequested();

    if (rawFinishedSamples.isEmpty || finishedStartTime == null) {
      return; // アプリ起動直後などまだ何もバッファされていない / Nothing buffered yet (e.g. just launched)
    }

    _finalizeOrDiscardSegment(
      rawSamples: rawFinishedSamples,
      startTime: finishedStartTime,
      lapTimeMs: finishedLapTimeMs,
      wasArmedCapture: wasArmedCapture,
    );
  }

  void _resetSegmentTracking() {
    _buffer = [];
    _cumulativeDistance = 0;
    _lastPosition = null;
  }

  void _armIfRequested() {
    // 要求済みでまだアームされていなければ、今始まったこのラップをキャプチャ対象にする
    // If a capture was requested but not yet armed, this newly-started lap becomes the target
    if (_requestedCaptureType != null && !_captureArmedForCurrentLap) {
      _captureArmedForCurrentLap = true;
      isArmedRecordingNotifier.value = true;
      debugPrint(
        '[LAP_DEBUG] armed for ${_requestedCaptureType!.label} capture',
      );
    }
  }

  // 区間(境界の直前まで貯まっていたサンプル列)を評価し、有効なら確定、
  // そうでなければ破棄する。呼び出し時点で次の区間のアーム判定は済んでいる
  // 前提で、ここでは「今終わった区間」の運命だけを決める
  // Evaluates a segment (the samples buffered right up to a boundary) and
  // either finalizes or discards it. Assumes arming for the *next* segment
  // has already been decided — this only determines the fate of the segment
  // that just *ended*.
  void _finalizeOrDiscardSegment({
    required List<TelemetrySample> rawSamples,
    required DateTime startTime,
    required int lapTimeMs,
    required bool wasArmedCapture,
  }) {
    // 区間がどの境界(瞬間移動/current_lapの変化/last_lapの変化)で開始された
    // かに関わらず、実測時間が申告タイムと大きく食い違っていないかを確認する。
    // 一致しなければ、リプレイのスクラブ操作などで拾ってしまった本来の1周より
    // ずっと短い断片とみなし破棄する。当初は瞬間移動で始まった区間だけに
    // 適用していたが、last_lap の境界そのものが短い間隔で切り替わるケースも
    // 実機ログで確認されたため、常に適用するようにした
    // Check that the measured duration isn't wildly inconsistent with the
    // claimed lap time, regardless of which boundary (teleport, current_lap
    // change, or last_lap change) started this segment. If it doesn't match,
    // it's treated as a fragment far shorter than a real lap — picked up via
    // something like replay scrubbing — and discarded. This used to apply
    // only to segments that began via a teleport, but real device logs
    // showed even genuine last_lap boundaries themselves can flip on an
    // interval far shorter than a real lap, so it's now applied unconditionally.
    if (rawSamples.last.elapsedMs < lapTimeMs * _minPlausibleDurationFraction) {
      _discardSegment(
        '[LAP_DEBUG] discarded a segment whose measured duration did not '
        'plausibly match the claimed lap time (looked like a fragment far '
        'shorter than a real lap)',
      );
      return;
    }

    final trimmed = _trimIdleEdges(rawSamples);
    // trimmed(トリム後)は前後の「実質走っていない」端を切り落とし済みなので、
    // その内側に閾値未満のサンプルが残っていれば区間途中での停止。
    // 生データの末尾自体が閾値未満の場合(トリムで切り落とされる典型的な
    // 「ゴール後に停止して終わる」パターン)も合わせて見る
    // trimmed has already cut off the leading/trailing "not really driving"
    // edges, so a below-threshold sample surviving inside it means a stop
    // happened mid-segment. Also check the raw (untrimmed) last sample, which
    // catches the classic "coasted to a stop right at the finish" pattern that
    // trimming itself would otherwise crop away before we can see it.
    final hasStopWithinLap =
        trimmed.samples.isEmpty ||
        trimmed.samples.any((s) => s.speedKmh < _minValidEndSpeedKmh) ||
        rawSamples.last.speedKmh < _minValidEndSpeedKmh;
    if (hasStopWithinLap) {
      _discardSegment(
        '[LAP_DEBUG] discarded a segment ending/containing a stop below '
        '$_minValidEndSpeedKmh km/h — looked like a coast-to-stop / replay '
        'restart, not a clean flying lap',
      );
      return;
    }

    _discardFlashTimer?.cancel();
    wasLastSegmentDiscardedNotifier.value = false;

    final type = wasArmedCapture ? _requestedCaptureType! : LapType.practice;
    final lap = LapCapture(
      type: type,
      startTime: startTime.add(Duration(milliseconds: trimmed.baseElapsedMs)),
      startSpeedKmh: trimmed.samples.first.speedKmh,
      lapTimeMs: lapTimeMs,
      samples: trimmed.samples,
    );

    debugPrint(
      '[LAP_DEBUG] accepted a segment: type=${type.label} lapTimeMs=$lapTimeMs '
      'samples=${trimmed.samples.length} wasArmedCapture=$wasArmedCapture',
    );
    onLapCompleted(lap);

    if (wasArmedCapture) {
      onReferenceLapCaptured(lap);
      _requestedCaptureType = null;
      _captureArmedForCurrentLap = false;
      isArmedRecordingNotifier.value = false;
      pendingCaptureNotifier.value = null;
    }
  }

  void _discardSegment(String debugMessage) {
    debugPrint(debugMessage);
    wasLastSegmentDiscardedNotifier.value = true;
    _discardFlashTimer?.cancel();
    _discardFlashTimer = Timer(_discardFlashDuration, () {
      wasLastSegmentDiscardedNotifier.value = false;
    });
  }

  // 先頭・末尾の「実質的に走っていない」(閾値未満の速度の)サンプルを切り落とし、
  // 残ったサンプルの経過時間・走行距離を先頭基準(0)に振り直す
  // Trims leading/trailing samples below the driving-speed threshold, then
  // re-bases the remaining samples' elapsed time and distance to start at 0
  ({List<TelemetrySample> samples, int baseElapsedMs}) _trimIdleEdges(
    List<TelemetrySample> samples,
  ) {
    final start = samples.indexWhere(
      (s) => s.speedKmh >= _drivingSpeedThresholdKmh,
    );
    if (start == -1) {
      return (samples: const <TelemetrySample>[], baseElapsedMs: 0);
    }
    final end = samples.lastIndexWhere(
      (s) => s.speedKmh >= _drivingSpeedThresholdKmh,
    );

    final baseElapsedMs = samples[start].elapsedMs;
    final baseDistanceM = samples[start].distanceM;

    final trimmed = samples
        .sublist(start, end + 1)
        .map(
          (s) => TelemetrySample(
            elapsedMs: s.elapsedMs - baseElapsedMs,
            distanceM: s.distanceM - baseDistanceM,
            speedKmh: s.speedKmh,
            throttle: s.throttle,
            brake: s.brake,
            steering: s.steering,
            posX: s.posX,
            posY: s.posY,
            posZ: s.posZ,
            gear: s.gear,
          ),
        )
        .toList();

    return (samples: trimmed, baseElapsedMs: baseElapsedMs);
  }

  // 区間の途中で位置が瞬間移動した(=リプレイのループ再生地点)瞬間に呼ばれる。
  // 前後の位置は無関係な2点なので、線で結ばれてしまわないようその場でバッファを
  // 破棄し、この新しい位置から改めて計測を始める。
  //
  // モニタリング中(まだ計測モードに入っていない)にこれが起きた場合、これは
  // まさに「リプレイがループしてスタート地点に戻った」瞬間そのものなので、
  // キャプチャ要求があればここでアームする(この新しい位置から新しい区間の
  // 計測を始める)。current_lap の増加をアーム合図に使っていた頃は、
  // current_lap がラップの途中でも増えることがあり(実機ログで確認済み)、
  // 本来のラップ全体より大幅に短い区間を「1周分」として誤って確定して
  // しまう不具合があったため、より確実な位置リセットそのものをアーム合図に
  // 切り替えた。既に計測モード中にこれが起きた場合は、途中で何かおかしな
  // ことが起きた(リプレイが想定外のタイミングでループした等)とみなし、
  // 従来通り破棄してモニタリングに戻す
  // Called the instant the position teleports mid-segment (a replay
  // loop-restart point). The points before and after are unrelated, so the
  // buffer is discarded on the spot rather than letting the painter draw a
  // line between them, and tracking restarts fresh from this new position.
  //
  // If this happens while monitoring (not yet measuring), it *is* the
  // moment the replay looped back to the start, so a pending capture
  // request arms right here (tracking a fresh segment from this new
  // position). Arming used to happen on a current_lap increase instead, but
  // real device logs showed current_lap can increase mid-lap too, which
  // sometimes finalized a segment far shorter than a real lap as if it were
  // a complete one — this switched to the more reliable position-reset
  // signal itself. If this happens while already measuring, something went
  // wrong mid-lap (e.g. the replay looped at an unexpected time), so it's
  // discarded and monitoring resumes as before.
  //
  // last_lap の値もここでリセットする(null にする)。自分の固定ベストラップを
  // ループ再生している場合、last_lap は毎回同じ値に戻るだけで、直前に記録して
  // いた値と比較すると「変化していない」と誤判定され、次の境界を永遠に検知
  // できなくなる。ここで基準をリセットしておくことで、後から同じ値が来ても
  // 「(リセット後の)-1 から変化した」として正しく境界検知できるようになる。
  // 実機ログでは瞬間移動の直後は必ず(この-1を経由する形で)last_lapが-1に
  // なることを確認済みなので null にしている(即座に-1に決め打ちすると、
  // 稀にlast_lapが瞬間移動をまたいで変化しなかった場合に、次のパケットで
  // すぐ誤って境界とみなしてしまい、瞬間移動直後の安全チェックが効かなく
  // なる不具合があった)
  // Also resets the last_lap baseline (to null) here. When watching a fixed,
  // looped replay of your own best lap, last_lap just returns to the exact
  // same value every loop — compared against the previously recorded value,
  // that looks like "no change," so the next boundary would never be
  // detected again. Resetting the baseline here means that when the same
  // value comes around again, it's correctly seen as "changed" from the
  // (post-reset) -1 baseline. This is null rather than an immediate -1
  // because real device logs confirmed last_lap always does pass through -1
  // right after a teleport — forcing -1 immediately caused a false boundary
  // trigger on the very next packet whenever last_lap happened not to change
  // across the teleport, which then bypassed the post-teleport safety check
  // for the segment that followed.
  void _onMidSegmentTeleport(double jumpMeters) {
    debugPrint(
      '[LAP_DEBUG] mid-segment position teleport detected '
      '(${jumpMeters.toStringAsFixed(1)} m in one sample)',
    );

    final wasAlreadyMeasuring = _captureArmedForCurrentLap;
    _resetSegmentTracking();
    _lapStartWallClock = _now();
    _lastSeenLapTimeMs = null;

    if (!wasAlreadyMeasuring && _requestedCaptureType != null) {
      _captureArmedForCurrentLap = true;
      isArmedRecordingNotifier.value = true;
      debugPrint(
        '[LAP_DEBUG] armed for ${_requestedCaptureType!.label} capture via '
        'post-teleport position reset',
      );
    } else {
      _captureArmedForCurrentLap = false;
      isArmedRecordingNotifier.value = false;
    }
  }

  void _accumulateSample(GT7Packet packet) {
    final position = (x: packet.positionX, y: packet.positionY, z: packet.positionZ);
    if (_lastPosition != null) {
      final dx = position.x - _lastPosition!.x;
      final dy = position.y - _lastPosition!.y;
      final dz = position.z - _lastPosition!.z;
      final jump = sqrt(dx * dx + dy * dy + dz * dz);
      if (jump > _maxPlausiblePositionJumpMeters) {
        _onMidSegmentTeleport(jump);
      } else {
        _cumulativeDistance += jump;
      }
    }
    _lastPosition = position;

    final elapsedMs = _lapStartWallClock == null
        ? 0
        : _now().difference(_lapStartWallClock!).inMilliseconds;

    final sample = TelemetrySample(
      elapsedMs: elapsedMs,
      distanceM: _cumulativeDistance,
      speedKmh: packet.speedKmh,
      throttle: packet.gas,
      brake: packet.brake,
      steering: null,
      posX: packet.positionX,
      posY: packet.positionY,
      posZ: packet.positionZ,
      gear: packet.gear,
    );
    _buffer.add(sample);
    currentSampleNotifier.value = sample;
  }
}
