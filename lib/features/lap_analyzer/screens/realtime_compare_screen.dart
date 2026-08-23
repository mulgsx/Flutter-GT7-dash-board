import 'package:flutter/material.dart';
import 'package:gt7_trj_log/features/lap_analyzer/models/lap_capture.dart';
import 'package:gt7_trj_log/features/lap_analyzer/models/telemetry_sample.dart';
import 'package:gt7_trj_log/features/lap_analyzer/services/lap_capture_service.dart';
import 'package:gt7_trj_log/features/lap_analyzer/services/realtime_diff_service.dart';
import 'package:gt7_trj_log/theme/la_colors.dart';
import 'package:gt7_trj_log/theme/la_strings.dart';
import 'package:gt7_trj_log/theme/la_text_styles.dart';
import 'package:gt7_trj_log/widgets/lap_analyzer/la_panel.dart';
import 'package:gt7_trj_log/widgets/lap_analyzer/la_scaffold.dart';

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
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
    final startSpeedChip = ValueListenableBuilder<TelemetrySample?>(
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
    );
    final deltaPanel = _DeltaPanel(service: service);
    final compareColumn = _CompareColumn(
      service: service,
      lapCaptureService: widget.lapCaptureService,
    );

    return LAScaffold(
      title: LAStrings.realtimeCompareTitle(widget.opponentLabel),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          // 縦向きの場合は横に並べる幅がないので、上から下へ積み上げてスクロールさせる
          // In portrait there isn't enough width to sit side-by-side, so stack
          // top-to-bottom and let the content scroll instead
          child: isPortrait
              ? SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      startSpeedChip,
                      const SizedBox(height: 12),
                      deltaPanel,
                      const SizedBox(height: 12),
                      compareColumn,
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    startSpeedChip,
                    const SizedBox(height: 12),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: deltaPanel),
                          const SizedBox(width: 12),
                          Expanded(flex: 1, child: compareColumn),
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
    return LAPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          const Text(LAStrings.startSpeed, style: LATextStyles.label),
          const SizedBox(width: 10),
          Text(
            LAStrings.ownValue(own == null ? '--' : own.toStringAsFixed(1)),
            style: LATextStyles.valueEmphasis.copyWith(
              fontSize: 13,
              color: LAColors.value,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            LAStrings.targetValueKmh(targetStartSpeedKmh.toStringAsFixed(1)),
            style: LATextStyles.label,
          ),
          if (diff != null) ...[
            const SizedBox(width: 8),
            Text(
              '${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(1)}',
              style: LATextStyles.valueEmphasis.copyWith(
                fontSize: 13,
                color: diff >= 0 ? LAColors.good : LAColors.bad,
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
    return LAPanel(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ValueListenableBuilder<double?>(
            valueListenable: service.deltaSecondsNotifier,
            builder: (context, delta, _) {
              final color = delta == null
                  ? LAColors.label
                  : (delta <= 0 ? LAColors.good : LAColors.bad);
              final text = delta == null
                  ? '--.---'
                  : '${delta <= 0 ? '-' : '+'}${delta.abs().toStringAsFixed(3)}';
              return Text(
                text,
                style: LATextStyles.bigNumber.copyWith(color: color),
              );
            },
          ),
          const SizedBox(height: 4),
          ValueListenableBuilder<bool>(
            valueListenable: service.hasSeenLapStartNotifier,
            builder: (context, hasStarted, _) => Text(
              hasStarted
                  ? LAStrings.deltaVsTargetLabel
                  : LAStrings.waitingForStartLine,
              textAlign: TextAlign.center,
              style: LATextStyles.label,
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
        ..color = last <= 0 ? LAColors.good : LAColors.bad
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
    return LAPanel(
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
                    label: LAStrings.throttle,
                    ownValue: ownSample?.throttle,
                    targetValue: targetSample?.throttle,
                    color: LAColors.throttle,
                  ),
                  const SizedBox(height: 10),
                  _PedalBarBlock(
                    label: LAStrings.brake,
                    ownValue: ownSample?.brake,
                    targetValue: targetSample?.brake,
                    color: LAColors.brake,
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
        const Text(LAStrings.speed, style: LATextStyles.labelMedium),
        Row(
          children: [
            Text(
              LAStrings.ownValue(own == null ? '--' : own.toStringAsFixed(0)),
              style: LATextStyles.value,
            ),
            const SizedBox(width: 6),
            Text(
              LAStrings.targetValueKmh(
                target == null ? '--' : target.toStringAsFixed(0),
              ),
              style: LATextStyles.label,
            ),
            if (diff != null) ...[
              const SizedBox(width: 6),
              Text(
                '${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(0)}',
                style: LATextStyles.valueEmphasis.copyWith(
                  color: diff >= 0 ? LAColors.good : LAColors.bad,
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
        ? LAColors.label
        : (delta >= 0 ? LAColors.good : LAColors.bad);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          LAStrings.brakingPointDelta,
          style: LATextStyles.labelMedium,
        ),
        Text(
          delta == null
              ? '--'
              : '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} m',
          style: LATextStyles.valueEmphasis.copyWith(color: color),
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
            Text(label, style: LATextStyles.label),
            Row(
              children: [
                Text(
                  '自分 ${(own * 100).toStringAsFixed(0)}% / '
                  '対象 ${(target * 100).toStringAsFixed(0)}%',
                  style: LATextStyles.label,
                ),
                if (hasGap) ...[
                  const SizedBox(width: 6),
                  Text(
                    '${diff >= 0 ? '+' : ''}${(diff * 100).toStringAsFixed(0)}%',
                    style: LATextStyles.valueEmphasis.copyWith(
                      fontSize: 12,
                      color: LAColors.gapHighlight,
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
                    Container(color: LAColors.trackBase),
                    FractionallySizedBox(
                      widthFactor: target,
                      child: Container(color: LAColors.targetBar),
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
                          color: LAColors.gapHighlight.withValues(alpha: 0.65),
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
          LAStrings.linePosition,
          style: LATextStyles.label,
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
                      color: LAColors.trackBase,
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
                        color: LAColors.selfDot,
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
