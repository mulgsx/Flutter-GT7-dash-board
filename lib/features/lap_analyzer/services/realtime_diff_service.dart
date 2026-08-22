import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/lap_capture.dart';
import '../models/telemetry_sample.dart';

/// 実座標(posX/posZ)を基準にターゲットラップと現在のテレメトリを突き合わせ、
/// 各種の差分をリアルタイムに算出する
/// Matches the target lap against live telemetry using real-world position
/// (posX/posZ) as the common axis, computing various real-time deltas
class RealtimeDiffService {
  static const double _brakeThreshold = 0.1;
  static const double _throttleThreshold = 0.1;
  // 前回マッチした位置から前方に何サンプル分探索するか。後方は探索しない
  // (=マッチは前進のみ、絶対に後戻りしない)。ヘアピンやシケインのように
  // コース上で物理的に近い2点が時間的には全く離れている区間があり、前後
  // どちらも探索対象にしていると、そういう地点でどちらの点にマッチするかが
  // 毎サンプルふらついて、デルタタイムのグラフに同じ「山」が繰り返し現れる
  // 原因になっていた。前方のみに限定することでこの揺れを防ぐ
  // How many samples forward of the previous match to search. Never searches
  // backward — the match only ever advances, never reverses. Hairpins and
  // chicanes have points that are physically close on the track but far
  // apart in time; searching both directions let the match flicker between
  // such points from sample to sample, producing the same "peak" recurring
  // repeatedly in the delta-time graph. Restricting the search to forward
  // only wasn't enough on its own — a wrong-but-closer point further ahead
  // within a wide window could still be selected — so the window itself is
  // kept small: on a 60Hz recording, a real hairpin's "near in space, far in
  // time" point is normally hundreds of samples away, well outside this.
  static const int _forwardSearchWindowSamples = 30;
  // デルタタイム履歴に残す期間(ミリ秒)。これより古いサンプルは順次捨てて、
  // 直近のトレンドだけが残る「流れるグラフ」にする(ラップ全体を溜め込み続けない)
  // How long delta-time history is kept (ms). Older samples are dropped as new
  // ones arrive, so the sparkline scrolls and shows only the recent trend
  // instead of accumulating the whole lap forever.
  static const int deltaHistoryWindowMs = 6000;

  List<TelemetrySample> _targetSamples = [];
  double _targetBrakingPointDistance = double.nan;
  double _targetThrottlePointDistance = double.nan;
  double _targetCornerEntrySpeedKmh = double.nan;
  double _targetTopSpeedKmh = double.nan;

  // 【必須】累積タイム差分(秒)。正=ターゲットより遅い、負=速い
  // 【Required】Cumulative time delta (s). Positive = slower than target, negative = faster
  final ValueNotifier<double?> deltaSecondsNotifier = ValueNotifier(null);
  // 【必須】ブレーキング開始地点の差(m)。正=ターゲットより奥でブレーキ
  // 【Required】Braking point delta (m). Positive = braked later (further) than target
  final ValueNotifier<double?> brakingPointDeltaMetersNotifier = ValueNotifier(
    null,
  );
  // アクセル踏み込み開始地点の差(m) / Throttle-on point delta (m)
  final ValueNotifier<double?> throttlePointDeltaMetersNotifier =
      ValueNotifier(null);
  // コーナー進入速度の差(km/h) / Corner entry speed delta (km/h)
  final ValueNotifier<double?> cornerEntrySpeedDeltaKmhNotifier =
      ValueNotifier(null);
  // 区間最高速度の差(km/h) / Top speed delta (km/h)
  final ValueNotifier<double?> topSpeedDeltaKmhNotifier = ValueNotifier(null);
  // 走行ラインの横方向オフセット(m、符号付き。正=ターゲットの進行方向に対して右、
  // 負=左)。ターゲット軌跡上の最近傍点との距離に、進行方向との外積で左右の符号を付ける
  // Lateral line offset (m, signed: positive = right of the target's heading,
  // negative = left). Distance to the nearest point on the target's
  // trajectory, signed via the cross product with the target's heading.
  final ValueNotifier<double?> lineOffsetMetersNotifier = ValueNotifier(null);
  // 現在の走行距離に最も近いターゲット側のサンプル(速度・ペダル等をライブ比較する用)
  // The target sample nearest the current distance (for live speed/pedal comparison)
  final ValueNotifier<TelemetrySample?> nearestTargetSampleNotifier =
      ValueNotifier(null);
  // デルタタイム履歴(スパークライン表示用)。直近 _deltaHistoryWindowMs 分だけを
  // 保持し、それより古いものは捨てる(蓄積させ続けない)。経過時間を一緒に持たせて
  // いるのは、UI側が「サンプル数」ではなく「実時間」でx軸を配置し、窓が埋まりきる
  // 前でも間延びせず一定速度で流れて見えるようにするため
  // Delta-time history (for the sparkline display). Only the last
  // _deltaHistoryWindowMs is kept; anything older is dropped (not
  // accumulated indefinitely). Elapsed time is kept alongside each value so
  // the UI can position points by real time rather than sample count — that
  // way it scrolls at a constant rate instead of stretching to fill the width
  // before the window is even full.
  final ValueNotifier<List<({int elapsedMs, double delta})>>
  deltaHistoryNotifier = ValueNotifier(const []);
  // 本物のラップ境界を一度でも観測したかどうか(UI側が「スタートライン通過待ち」
  // メッセージを出し分けるために公開している)
  // Whether a genuine lap boundary has been observed at least once (exposed
  // so the UI can show a "waiting to cross the start line" message).
  final ValueNotifier<bool> hasSeenLapStartNotifier = ValueNotifier(false);

  bool get hasTarget => _targetSamples.isNotEmpty;

  double? _ownBrakingPointDistance;
  double? _ownThrottlePointDistance;
  double? _ownCornerEntrySpeedKmh;
  double? _ownTopSpeedKmh;
  bool _ownWasBraking = false;
  int? _lastMatchedTargetIndex;
  // 本物のラップ境界(LapCaptureService.lapStartEventNotifier)を一度でも
  // 観測したかどうか。画面を開いた直後はラップ途中から観測が始まっている
  // 可能性があり、経過時間の基準がターゲットと揃っていない(=デルタタイムが
  // 意味を持たない)ため、これがtrueになるまでデルタタイム関連の表示は
  // 更新しない。以前は「距離の巻き戻り」を自前で検知していたが、位置の
  // 瞬間移動(リプレイのループ地点)でも距離が0付近に戻るため誤検知していた。
  // 本物の境界かどうかは LapCaptureService だけが知っているので、そちらから
  // 明示的に onLapStarted() を呼んでもらう形にした
  // Whether a genuine lap boundary (LapCaptureService.lapStartEventNotifier)
  // has been observed at least once. Right after the screen opens,
  // observation may have started mid-lap, so elapsed time isn't aligned with
  // the target's (the delta time is meaningless) — delta-time display is
  // withheld until this becomes true. This used to be self-detected via a
  // backward jump in distance, but a mid-segment position teleport (a replay
  // loop-restart point) also resets distance near zero, causing false
  // positives. Only LapCaptureService actually knows whether a boundary is
  // genuine, so it now calls onLapStarted() explicitly instead.

  void setTarget(LapCapture target) {
    _targetSamples = target.samples;
    _computeTargetLandmarks();
    hasSeenLapStartNotifier.value = false;
    deltaSecondsNotifier.value = null;
    _resetOwnLapState();
  }

  void clearTarget() {
    _targetSamples = [];
    hasSeenLapStartNotifier.value = false;
    deltaSecondsNotifier.value = null;
    _resetOwnLapState();
  }

  /// 本物のラップ境界を観測した際に呼ぶ。以後のサンプルからデルタタイム表示を
  /// 解禁し、ブレーキ地点などの自分側トラッキング状態もリセットする
  /// Call this when a genuine lap boundary is observed. Unlocks the delta-time
  /// display from the next sample onward, and resets own-lap tracking state
  /// (braking point, etc.) too.
  void onLapStarted() {
    hasSeenLapStartNotifier.value = true;
    _resetOwnLapState();
  }

  /// 自分側の最新サンプルを1件渡す(呼び出し側がラップ内の全サンプルを順に流す)
  /// Feed one live sample from the driver's own lap (call in order, sample by sample)
  void onOwnSample(TelemetrySample sample) {
    if (_targetSamples.isEmpty) return;

    final nearestIndex = _nearestIndexByPosition(sample.posX, sample.posZ);
    _lastMatchedTargetIndex = nearestIndex;
    final targetSample = _targetSamples[nearestIndex];
    nearestTargetSampleNotifier.value = targetSample;

    if (hasSeenLapStartNotifier.value) {
      final delta = (sample.elapsedMs - targetSample.elapsedMs) / 1000.0;
      deltaSecondsNotifier.value = delta;
      final cutoffMs = sample.elapsedMs - deltaHistoryWindowMs;
      deltaHistoryNotifier.value = [
        ...deltaHistoryNotifier.value.where((r) => r.elapsedMs >= cutoffMs),
        (elapsedMs: sample.elapsedMs, delta: delta),
      ];
    }

    if (_ownBrakingPointDistance == null && sample.brake > _brakeThreshold) {
      _ownBrakingPointDistance = sample.distanceM;
      if (_targetBrakingPointDistance.isFinite) {
        brakingPointDeltaMetersNotifier.value =
            sample.distanceM - _targetBrakingPointDistance;
      }
    }

    if (_ownThrottlePointDistance == null &&
        sample.throttle > _throttleThreshold) {
      _ownThrottlePointDistance = sample.distanceM;
      if (_targetThrottlePointDistance.isFinite) {
        throttlePointDeltaMetersNotifier.value =
            sample.distanceM - _targetThrottlePointDistance;
      }
    }

    if (sample.brake > _brakeThreshold) {
      _ownWasBraking = true;
    } else if (_ownWasBraking && _ownCornerEntrySpeedKmh == null) {
      _ownWasBraking = false;
      _ownCornerEntrySpeedKmh = sample.speedKmh;
      if (_targetCornerEntrySpeedKmh.isFinite) {
        cornerEntrySpeedDeltaKmhNotifier.value =
            sample.speedKmh - _targetCornerEntrySpeedKmh;
      }
    }

    if (_ownBrakingPointDistance == null) {
      if (_ownTopSpeedKmh == null || sample.speedKmh > _ownTopSpeedKmh!) {
        _ownTopSpeedKmh = sample.speedKmh;
        if (_targetTopSpeedKmh.isFinite) {
          topSpeedDeltaKmhNotifier.value =
              sample.speedKmh - _targetTopSpeedKmh;
        }
      }
    }

    lineOffsetMetersNotifier.value = _signedLineOffset(sample, nearestIndex);
  }

  // ターゲット軌跡の最近傍点との横方向オフセットを、符号付き(正=進行方向に対して
  // 右、負=左)で求める。進行方向は前後のサンプルから推定し、外積の符号で左右を判定する
  // Signed lateral offset from the nearest point on the target's trajectory
  // (positive = right of the heading, negative = left). Heading is estimated
  // from the neighboring samples; the cross product's sign gives left/right.
  double _signedLineOffset(TelemetrySample sample, int nearestIndex) {
    final nearest = _targetSamples[nearestIndex];
    final dx = sample.posX - nearest.posX;
    final dz = sample.posZ - nearest.posZ;
    final magnitude = sqrt(dx * dx + dz * dz);
    if (magnitude == 0) return 0;

    final prev = _targetSamples[nearestIndex == 0 ? 0 : nearestIndex - 1];
    final next =
        _targetSamples[nearestIndex == _targetSamples.length - 1
            ? nearestIndex
            : nearestIndex + 1];
    final headingX = next.posX - prev.posX;
    final headingZ = next.posZ - prev.posZ;
    final headingLength = sqrt(headingX * headingX + headingZ * headingZ);
    if (headingLength == 0) return magnitude;

    final cross = headingX * dz - headingZ * dx;
    return cross >= 0 ? magnitude : -magnitude;
  }

  // 実座標(posX/posZ)が最も近いターゲットサンプルのインデックスを探す。
  // 前回マッチした位置から前方 _forwardSearchWindowSamples 件だけを見る
  // (後方には戻らない)。初回(前回位置が無い場合)だけ全件探索する
  // Finds the index of the target sample nearest in real-world position
  // (posX/posZ). Searches only the _forwardSearchWindowSamples samples ahead
  // of the previous match (never backward). Falls back to a full scan only
  // for the very first match (no previous position yet).
  int _nearestIndexByPosition(double posX, double posZ) {
    final anchor = _lastMatchedTargetIndex;
    final start = anchor ?? 0;
    final end = anchor == null
        ? _targetSamples.length - 1
        : (anchor + _forwardSearchWindowSamples).clamp(
            0,
            _targetSamples.length - 1,
          );

    var bestIndex = start;
    var bestDistanceSq = double.infinity;
    for (var i = start; i <= end; i++) {
      final dx = _targetSamples[i].posX - posX;
      final dz = _targetSamples[i].posZ - posZ;
      final distanceSq = dx * dx + dz * dz;
      if (distanceSq < bestDistanceSq) {
        bestDistanceSq = distanceSq;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  void _computeTargetLandmarks() {
    _targetBrakingPointDistance = double.nan;
    _targetThrottlePointDistance = double.nan;
    _targetCornerEntrySpeedKmh = double.nan;
    var runningTop = 0.0;
    var wasBraking = false;

    for (final sample in _targetSamples) {
      if (_targetBrakingPointDistance.isNaN &&
          sample.brake > _brakeThreshold) {
        _targetBrakingPointDistance = sample.distanceM;
      }
      if (_targetThrottlePointDistance.isNaN &&
          sample.throttle > _throttleThreshold) {
        _targetThrottlePointDistance = sample.distanceM;
      }
      if (sample.brake > _brakeThreshold) {
        wasBraking = true;
      } else if (wasBraking && _targetCornerEntrySpeedKmh.isNaN) {
        wasBraking = false;
        _targetCornerEntrySpeedKmh = sample.speedKmh;
      }
      if (_targetBrakingPointDistance.isNaN && sample.speedKmh > runningTop) {
        runningTop = sample.speedKmh;
      }
    }
    _targetTopSpeedKmh = runningTop;
  }

  void _resetOwnLapState() {
    _ownBrakingPointDistance = null;
    _ownThrottlePointDistance = null;
    _ownCornerEntrySpeedKmh = null;
    _ownTopSpeedKmh = null;
    _ownWasBraking = false;
    brakingPointDeltaMetersNotifier.value = null;
    throttlePointDeltaMetersNotifier.value = null;
    cornerEntrySpeedDeltaKmhNotifier.value = null;
    topSpeedDeltaKmhNotifier.value = null;
    nearestTargetSampleNotifier.value = null;
    deltaHistoryNotifier.value = const [];
    _lastMatchedTargetIndex = null;
  }

  void dispose() {
    deltaSecondsNotifier.dispose();
    brakingPointDeltaMetersNotifier.dispose();
    throttlePointDeltaMetersNotifier.dispose();
    cornerEntrySpeedDeltaKmhNotifier.dispose();
    topSpeedDeltaKmhNotifier.dispose();
    lineOffsetMetersNotifier.dispose();
    nearestTargetSampleNotifier.dispose();
    deltaHistoryNotifier.dispose();
    hasSeenLapStartNotifier.dispose();
  }
}
