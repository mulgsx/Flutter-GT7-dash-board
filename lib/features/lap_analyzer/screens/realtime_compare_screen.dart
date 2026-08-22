import 'package:flutter/material.dart';
import '../models/lap_capture.dart';
import '../models/telemetry_sample.dart';
import '../services/lap_capture_service.dart';
import '../services/realtime_diff_service.dart';

/// 現在の走行とターゲットラップを距離ベースで突き合わせ、常時差分を表示する画面
/// Screen that continuously compares the current drive against the target lap by distance
class RealtimeCompareScreen extends StatefulWidget {
  final LapCaptureService lapCaptureService;
  final RealtimeDiffService realtimeDiffService;
  final LapCapture target;
  // 比較相手の表示名(「ターゲット」または「ベストラップ」) / Display name for the
  // opponent being compared against ("ターゲット" or "ベストラップ")
  final String opponentLabel;

  const RealtimeCompareScreen({
    super.key,
    required this.lapCaptureService,
    required this.realtimeDiffService,
    required this.target,
    required this.opponentLabel,
  });

  @override
  State<RealtimeCompareScreen> createState() => _RealtimeCompareScreenState();
}

class _RealtimeCompareScreenState extends State<RealtimeCompareScreen> {
  @override
  void initState() {
    super.initState();
    widget.realtimeDiffService.setTarget(widget.target);
    widget.lapCaptureService.currentSampleNotifier.addListener(_onSample);
    widget.lapCaptureService.lapStartEventNotifier.addListener(_onLapStarted);
  }

  void _onSample() {
    final sample = widget.lapCaptureService.currentSampleNotifier.value;
    if (sample != null) {
      widget.realtimeDiffService.onOwnSample(sample);
    }
  }

  // 本物のラップ境界を通知する。画面を開いた時点でラップの途中だった場合、
  // 次にこれが呼ばれるまでデルタタイムは表示されない
  // Notifies a genuine lap boundary. If the screen was opened mid-lap, delta
  // time stays hidden until this fires next.
  void _onLapStarted() {
    widget.realtimeDiffService.onLapStarted();
  }

  @override
  void dispose() {
    widget.lapCaptureService.currentSampleNotifier.removeListener(_onSample);
    widget.lapCaptureService.lapStartEventNotifier.removeListener(
      _onLapStarted,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.realtimeDiffService;
    return Scaffold(
      backgroundColor: _kBackground,
      appBar: AppBar(
        title: Text('リアルタイム差分比較(${widget.opponentLabel})'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ValueListenableBuilder<TelemetrySample?>(
                valueListenable: widget.lapCaptureService.currentSampleNotifier,
                builder: (context, _, _) {
                  final ownSamples = widget.lapCaptureService.currentLapSamples;
                  final ownStartSpeed = ownSamples.isEmpty
                      ? null
                      : ownSamples.first.speedKmh;
                  return _StartSpeedChip(
                    ownStartSpeedKmh: ownStartSpeed,
                    targetStartSpeedKmh: widget.target.startSpeedKmh,
                  );
                },
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _DeltaPanel(service: service)),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: _CompareColumn(
                        service: service,
                        lapCaptureService: widget.lapCaptureService,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 明るく視認性の高いメーター向けの配色
// A bright, high-visibility color palette suited for a meter-style display
const _kBackground = Color(0xFFEFF1F4);
const _kPanelBackground = Colors.white;
const _kLabelColor = Color(0xFF6B7280);
const _kValueColor = Color(0xFF1F2430);
const _kGood = Color(0xFF1E8E3E); // 自分が速い/良い方向 / self is faster/better
const _kBad = Color(0xFFD93025); // 自分が遅い/悪い方向 / self is slower/worse
const _kTargetBarColor = Color(0xFFC7CBD1);
const _kThrottleColor = Color(0xFF1E8E3E);
const _kBrakeColor = Color(0xFFD93025);
const _kSelfDotColor = Color(0xFF1A73E8);
const _kGapHighlight = Color(0xFFF9A825); // 自分と対象の差を強調する色 / Highlights the gap between self and target

BoxDecoration _panelDecoration() => BoxDecoration(
  color: _kPanelBackground,
  borderRadius: BorderRadius.circular(14),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ],
);

class _StartSpeedChip extends StatelessWidget {
  final double? ownStartSpeedKmh;
  final double targetStartSpeedKmh;

  const _StartSpeedChip({
    required this.ownStartSpeedKmh,
    required this.targetStartSpeedKmh,
  });

  @override
  Widget build(BuildContext context) {
    final own = ownStartSpeedKmh;
    final diff = own == null ? null : own - targetStartSpeedKmh;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: _panelDecoration(),
      child: Row(
        children: [
          const Text(
            'スタート速度',
            style: TextStyle(fontSize: 12, color: _kLabelColor),
          ),
          const SizedBox(width: 10),
          Text(
            '自分 ${own == null ? '--' : own.toStringAsFixed(1)}',
            style: const TextStyle(
              fontSize: 13,
              color: _kValueColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '/ 対象 ${targetStartSpeedKmh.toStringAsFixed(1)} km/h',
            style: const TextStyle(fontSize: 12, color: _kLabelColor),
          ),
          if (diff != null) ...[
            const SizedBox(width: 8),
            Text(
              '${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(1)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: diff >= 0 ? _kGood : _kBad,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DeltaPanel extends StatelessWidget {
  final RealtimeDiffService service;

  const _DeltaPanel({required this.service});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _panelDecoration(),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ValueListenableBuilder<double?>(
            valueListenable: service.deltaSecondsNotifier,
            builder: (context, delta, _) {
              final color = delta == null
                  ? _kLabelColor
                  : (delta <= 0 ? _kGood : _kBad);
              final text = delta == null
                  ? '--.---'
                  : '${delta <= 0 ? '-' : '+'}${delta.abs().toStringAsFixed(3)}';
              return Text(
                text,
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          ValueListenableBuilder<bool>(
            valueListenable: service.hasSeenLapStartNotifier,
            builder: (context, hasStarted, _) => Text(
              hasStarted ? 'ターゲット比(秒)' : 'スタートラインを通過すると表示されます',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: _kLabelColor),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            width: double.infinity,
            child: ValueListenableBuilder<List<({int elapsedMs, double delta})>>(
              valueListenable: service.deltaHistoryNotifier,
              builder: (context, history, _) {
                return CustomPaint(painter: _SparklinePainter(history));
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<({int elapsedMs, double delta})> history;

  _SparklinePainter(this.history);

  @override
  void paint(Canvas canvas, Size size) {
    if (history.length < 2) return;

    var minV = history.first.delta;
    var maxV = history.first.delta;
    for (final r in history) {
      if (r.delta < minV) minV = r.delta;
      if (r.delta > maxV) maxV = r.delta;
    }
    final span = (maxV - minV).clamp(0.2, double.infinity);
    final last = history.last.delta;

    // サンプル数ではなく実時間でx軸を配置する。ウィンドウが埋まりきる前
    // (ラップ開始直後)でも間延びさせず、常に一定速度で右から左へ流れて見える
    // ようにする(右端=最新、左端=deltaHistoryWindowMs秒前)
    // Position x by real elapsed time, not sample count, so it doesn't stretch
    // to fill the width before the window is even full (right after a lap
    // starts) — it always scrolls right-to-left at a constant rate (right
    // edge = now, left edge = deltaHistoryWindowMs ago).
    final nowMs = history.last.elapsedMs;
    final windowMs = RealtimeDiffService.deltaHistoryWindowMs;

    final path = Path();
    for (var i = 0; i < history.length; i++) {
      final age = nowMs - history[i].elapsedMs;
      final x = size.width * (1 - age / windowMs);
      final normalized = (history[i].delta - minV) / span;
      // delta は正=遅い(下)なので、上下は速い方が上に来るよう反転させる
      // delta is positive = slower, so invert vertically so "faster" points up
      final y = size.height * normalized;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = last <= 0 ? _kGood : _kBad
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.history != history;
}

class _CompareColumn extends StatelessWidget {
  final RealtimeDiffService service;
  final LapCaptureService lapCaptureService;

  const _CompareColumn({
    required this.service,
    required this.lapCaptureService,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _panelDecoration(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: ValueListenableBuilder<TelemetrySample?>(
        valueListenable: lapCaptureService.currentSampleNotifier,
        builder: (context, ownSample, _) {
          return ValueListenableBuilder<TelemetrySample?>(
            valueListenable: service.nearestTargetSampleNotifier,
            builder: (context, targetSample, _) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SpeedCompareRow(
                    ownSpeedKmh: ownSample?.speedKmh,
                    targetSpeedKmh: targetSample?.speedKmh,
                  ),
                  const SizedBox(height: 10),
                  ValueListenableBuilder<double?>(
                    valueListenable: service.brakingPointDeltaMetersNotifier,
                    builder: (context, delta, _) =>
                        _BrakingPointCompareRow(deltaMeters: delta),
                  ),
                  const SizedBox(height: 14),
                  _PedalBarBlock(
                    label: 'アクセル',
                    ownValue: ownSample?.throttle,
                    targetValue: targetSample?.throttle,
                    color: _kThrottleColor,
                  ),
                  const SizedBox(height: 10),
                  _PedalBarBlock(
                    label: 'ブレーキ',
                    ownValue: ownSample?.brake,
                    targetValue: targetSample?.brake,
                    color: _kBrakeColor,
                  ),
                  const SizedBox(height: 14),
                  ValueListenableBuilder<double?>(
                    valueListenable: service.lineOffsetMetersNotifier,
                    builder: (context, offset, _) =>
                        _LinePositionIndicator(offsetMeters: offset),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _SpeedCompareRow extends StatelessWidget {
  final double? ownSpeedKmh;
  final double? targetSpeedKmh;

  const _SpeedCompareRow({required this.ownSpeedKmh, required this.targetSpeedKmh});

  @override
  Widget build(BuildContext context) {
    final own = ownSpeedKmh;
    final target = targetSpeedKmh;
    final diff = (own != null && target != null) ? own - target : null;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        const Text('速度', style: TextStyle(fontSize: 13, color: _kLabelColor)),
        Row(
          children: [
            Text(
              '自分 ${own == null ? '--' : own.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 14, color: _kValueColor),
            ),
            const SizedBox(width: 6),
            Text(
              '/ 対象 ${target == null ? '--' : target.toStringAsFixed(0)} km/h',
              style: const TextStyle(fontSize: 12, color: _kLabelColor),
            ),
            if (diff != null) ...[
              const SizedBox(width: 6),
              Text(
                '${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: diff >= 0 ? _kGood : _kBad,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _BrakingPointCompareRow extends StatelessWidget {
  final double? deltaMeters;

  const _BrakingPointCompareRow({required this.deltaMeters});

  @override
  Widget build(BuildContext context) {
    final delta = deltaMeters;
    // 正=ターゲットより奥まで我慢してブレーキ=良い方向 / positive = braked later than target = good
    final color = delta == null
        ? _kLabelColor
        : (delta >= 0 ? _kGood : _kBad);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'ブレーキング地点差',
          style: TextStyle(fontSize: 13, color: _kLabelColor),
        ),
        Text(
          delta == null
              ? '--'
              : '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} m',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _PedalBarBlock extends StatelessWidget {
  final String label;
  final double? ownValue; // 0.0-1.0
  final double? targetValue; // 0.0-1.0
  final Color color;
  // これ未満の差は誤差として無視し、強調表示しない
  // Differences smaller than this are treated as noise and not highlighted
  static const double _highlightThresholdFraction = 0.05;

  const _PedalBarBlock({
    required this.label,
    required this.ownValue,
    required this.targetValue,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final own = (ownValue ?? 0).clamp(0.0, 1.0);
    final target = (targetValue ?? 0).clamp(0.0, 1.0);
    final diff = own - target;
    final hasGap = diff.abs() >= _highlightThresholdFraction;
    final gapStart = own < target ? own : target;
    final gapEnd = own < target ? target : own;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: _kLabelColor)),
            Row(
              children: [
                Text(
                  '自分 ${(own * 100).toStringAsFixed(0)}% / '
                  '対象 ${(target * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 12, color: _kLabelColor),
                ),
                if (hasGap) ...[
                  const SizedBox(width: 6),
                  Text(
                    '${diff >= 0 ? '+' : ''}${(diff * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _kGapHighlight,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 14,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                return Stack(
                  children: [
                    Container(color: const Color(0xFFE4E6EA)),
                    FractionallySizedBox(
                      widthFactor: target,
                      child: Container(color: _kTargetBarColor),
                    ),
                    FractionallySizedBox(
                      widthFactor: own,
                      child: Container(color: color),
                    ),
                    // 差がある区間を上から重ねて強調表示する
                    // Overlay the gap region to make the difference stand out
                    if (hasGap)
                      Positioned(
                        left: gapStart * width,
                        width: (gapEnd - gapStart) * width,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          color: _kGapHighlight.withValues(alpha: 0.65),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _LinePositionIndicator extends StatelessWidget {
  final double? offsetMeters;
  // この値を超えたオフセットはトラック端に張り付かせる(表示上のクランプ範囲)
  // Offsets beyond this are clamped to the track's edge (display range)
  static const double _maxDisplayOffsetMeters = 3.0;

  const _LinePositionIndicator({required this.offsetMeters});

  @override
  Widget build(BuildContext context) {
    final offset = offsetMeters;
    final normalized = offset == null
        ? 0.0
        : (offset / _maxDisplayOffsetMeters).clamp(-1.0, 1.0);
    final positionFraction = 0.5 + normalized / 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'ライン位置(対ターゲット)',
          style: TextStyle(fontSize: 12, color: _kLabelColor),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 20,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFE4E6EA),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: Container(width: 2, color: const Color(0xFF9AA0A6)),
                  ),
                  Positioned(
                    left:
                        positionFraction * constraints.maxWidth - 7,
                    top: 4,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: _kSelfDotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
