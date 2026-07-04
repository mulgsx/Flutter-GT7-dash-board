import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

// ────────────────────────────────────────────────────────────────────────────
// AnalogDashboard – root widget
// ────────────────────────────────────────────────────────────────────────────
class AnalogDashboard extends StatelessWidget {
  final ValueNotifier<double> rpmNotifier;
  final ValueNotifier<double> speedNotifier;
  final ValueNotifier<int>    gearNotifier;
  final ValueNotifier<double> throttleNotifier;
  final ValueNotifier<double> brakeNotifier;
  final ValueNotifier<int>    rpmWarningNotifier;
  final ValueNotifier<int>    rpmLimiterNotifier;
  final ValueNotifier<double> fuelLevelNotifier;
  final ValueNotifier<double> fuelCapacityNotifier;

  const AnalogDashboard({
    super.key,
    required this.rpmNotifier,
    required this.speedNotifier,
    required this.gearNotifier,
    required this.throttleNotifier,
    required this.brakeNotifier,
    required this.rpmWarningNotifier,
    required this.rpmLimiterNotifier,
    required this.fuelLevelNotifier,
    required this.fuelCapacityNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0A0A14),
      child: Column(
        children: [
          // ── Shift light bar (8%) ─────────────────────────────────────────
          Expanded(
            flex: 8,
            child: _ShiftLightBar(
              rpmNotifier:        rpmNotifier,
              rpmWarningNotifier: rpmWarningNotifier,
              rpmLimiterNotifier: rpmLimiterNotifier,
            ),
          ),

          // ── Main gauge row (78%) ──────────────────────────────────────────
          Expanded(
            flex: 78,
            child: ClipRect(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Tachometer (flex 4)
                  Expanded(
                    flex: 4,
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1.0,
                        child: _TachometerGauge(
                          rpmNotifier:        rpmNotifier,
                          rpmWarningNotifier: rpmWarningNotifier,
                          rpmLimiterNotifier: rpmLimiterNotifier,
                        ),
                      ),
                    ),
                  ),

                  // Center panel (flex 2)
                  Expanded(
                    flex: 2,
                    child: _CenterPanel(
                      gearNotifier:         gearNotifier,
                      speedNotifier:        speedNotifier,
                      fuelLevelNotifier:    fuelLevelNotifier,
                      fuelCapacityNotifier: fuelCapacityNotifier,
                    ),
                  ),

                  // Speedometer (flex 4)
                  Expanded(
                    flex: 4,
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1.0,
                        child: _SpeedometerGauge(speedNotifier: speedNotifier),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Pedal strip (14%) ─────────────────────────────────────────────
          Expanded(
            flex: 14,
            child: _PedalStrip(
              throttleNotifier: throttleNotifier,
              brakeNotifier:    brakeNotifier,
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Shift light bar
// ────────────────────────────────────────────────────────────────────────────
class _ShiftLightBar extends StatefulWidget {
  final ValueNotifier<double> rpmNotifier;
  final ValueNotifier<int>    rpmWarningNotifier;
  final ValueNotifier<int>    rpmLimiterNotifier;

  const _ShiftLightBar({
    required this.rpmNotifier,
    required this.rpmWarningNotifier,
    required this.rpmLimiterNotifier,
  });

  @override
  State<_ShiftLightBar> createState() => _ShiftLightBarState();
}

class _ShiftLightBarState extends State<_ShiftLightBar> {
  Timer? _flashTimer;
  bool   _flash = true;

  @override
  void initState() {
    super.initState();
    _flashTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (mounted) setState(() => _flash = !_flash);
    });
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: widget.rpmNotifier,
      builder: (_, rpm, __) => ValueListenableBuilder<int>(
        valueListenable: widget.rpmWarningNotifier,
        builder: (_, warnRpm, __) => ValueListenableBuilder<int>(
          valueListenable: widget.rpmLimiterNotifier,
          builder: (_, limRpm, __) {
            final effectiveWarn = warnRpm > 0 ? warnRpm.toDouble() : 7000.0;
            final effectiveLim  = limRpm  > 0 ? limRpm.toDouble()  : 8000.0;
            final startRpm  = effectiveWarn * 0.80;
            final atLimit   = rpm >= effectiveLim;
            final progress  = rpm <= startRpm
                ? 0.0
                : ((rpm - startRpm) / (effectiveLim - startRpm)).clamp(0.0, 1.0);
            const total = 12;
            final lit = (progress * total).round();

            return LayoutBuilder(builder: (context, cs) {
              final dotSize = (cs.maxHeight * 0.55).clamp(8.0, 22.0);
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(total, (i) {
                  final Color off, on;
                  if (i < 4) {
                    off = const Color(0xFF0A2A0A);
                    on  = Colors.greenAccent;
                  } else if (i < 8) {
                    off = const Color(0xFF2A2A00);
                    on  = Colors.yellowAccent;
                  } else {
                    off = const Color(0xFF2A0000);
                    on  = Colors.redAccent;
                  }
                  final isLit = i < lit;
                  final show  = isLit && (!atLimit || _flash);
                  return Container(
                    width:  dotSize,
                    height: dotSize,
                    margin: EdgeInsets.symmetric(
                        horizontal: (cs.maxWidth * 0.005).clamp(1.5, 6.0)),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: show ? on : off,
                      boxShadow: show
                          ? [BoxShadow(color: on.withValues(alpha: 0.8),
                              blurRadius: 6, spreadRadius: 1)]
                          : null,
                    ),
                  );
                }),
              );
            });
          },
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// _GaugePainter
// ────────────────────────────────────────────────────────────────────────────
class _GaugePainter extends CustomPainter {
  final double       value;
  final double       minValue;
  final double       maxValue;
  final double       warnValue;
  final double       dangerValue;
  final String       unit;
  final List<String> labels;
  final double       labelStep;

  static const double _startAngle = 135 * pi / 180;
  static const double _sweepAngle = 270 * pi / 180;

  const _GaugePainter({
    required this.value,
    required this.minValue,
    required this.maxValue,
    required this.warnValue,
    required this.dangerValue,
    required this.unit,
    required this.labels,
    required this.labelStep,
  });

  double _valueToAngle(double v) {
    final t = ((v - minValue) / (maxValue - minValue)).clamp(0.0, 1.0);
    return _startAngle + t * _sweepAngle;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 * 0.88;

    // Background
    canvas.drawCircle(center, radius,
        Paint()..color = const Color(0xFF0E0E1A));
    canvas.drawCircle(center, radius,
        Paint()
          ..color = const Color(0xFF1E2240)
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.shortestSide * 0.025);

    // Zone arcs
    final arcRect = Rect.fromCircle(center: center, radius: radius * 0.82);
    final arcW    = size.shortestSide * 0.05;
    final greenEnd  = _valueToAngle(warnValue);
    final yellowEnd = _valueToAngle(dangerValue);
    final fullEnd   = _startAngle + _sweepAngle;

    canvas.drawArc(arcRect, _startAngle, greenEnd - _startAngle, false,
        Paint()..color = Colors.green.withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke ..strokeWidth = arcW
          ..strokeCap = StrokeCap.butt);
    canvas.drawArc(arcRect, greenEnd, yellowEnd - greenEnd, false,
        Paint()..color = Colors.yellow.withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke ..strokeWidth = arcW
          ..strokeCap = StrokeCap.butt);
    canvas.drawArc(arcRect, yellowEnd, fullEnd - yellowEnd, false,
        Paint()..color = Colors.redAccent.withValues(alpha: 0.75)
          ..style = PaintingStyle.stroke ..strokeWidth = arcW
          ..strokeCap = StrokeCap.butt);

    // Active arc glow
    final needleAngle = _valueToAngle(value);
    final activeColor = value >= dangerValue
        ? Colors.redAccent
        : value >= warnValue
            ? Colors.yellowAccent
            : Colors.greenAccent;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.68),
      _startAngle, needleAngle - _startAngle, false,
      Paint()..color = activeColor.withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.shortestSide * 0.03
        ..strokeCap = StrokeCap.round,
    );

    // Tick marks
    final majorCount = ((maxValue - minValue) / labelStep).round();
    for (int i = 0; i <= majorCount * 5; i++) {
      final frac    = i / (majorCount * 5);
      final angle   = _startAngle + frac * _sweepAngle;
      final isMajor = i % 5 == 0;
      final innerR  = isMajor ? radius * 0.72 : radius * 0.78;
      canvas.drawLine(
        Offset(center.dx + radius * 0.85 * cos(angle),
               center.dy + radius * 0.85 * sin(angle)),
        Offset(center.dx + innerR * cos(angle),
               center.dy + innerR * sin(angle)),
        Paint()
          ..color       = isMajor ? Colors.white70 : Colors.white30
          ..strokeWidth = isMajor ? size.shortestSide * 0.008
                                  : size.shortestSide * 0.004,
      );
    }

    // Labels
    final labelSize = (size.shortestSide * 0.062).clamp(9.0, 24.0);
    for (int i = 0; i <= majorCount; i++) {
      final v     = minValue + i * labelStep;
      final frac  = (v - minValue) / (maxValue - minValue);
      final angle = _startAngle + frac * _sweepAngle;
      final pos   = Offset(
        center.dx + radius * 0.60 * cos(angle),
        center.dy + radius * 0.60 * sin(angle),
      );
      if (i >= labels.length) continue;
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(color: Colors.white,
              fontSize: labelSize, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2));
    }

    // Unit label
    final unitSize = (size.shortestSide * 0.052).clamp(8.0, 18.0);
    final unitTp = TextPainter(
      text: TextSpan(text: unit,
          style: TextStyle(color: Colors.white38, fontSize: unitSize,
              letterSpacing: 1.5)),
      textDirection: TextDirection.ltr,
    )..layout();
    unitTp.paint(canvas, Offset(center.dx - unitTp.width / 2,
        center.dy + radius * 0.42));

    // Needle
    final needleLen  = radius * 0.72;
    final backLen    = radius * 0.15;
    final nx = cos(needleAngle), ny = sin(needleAngle);
    final tipPt  = Offset(center.dx + needleLen * nx,
                          center.dy + needleLen * ny);
    final basePt = Offset(center.dx - backLen * nx,
                          center.dy - backLen * ny);

    canvas.drawLine(basePt, tipPt,
        Paint()..color = Colors.red.withValues(alpha: 0.4)
          ..strokeWidth = size.shortestSide * 0.025 ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    canvas.drawLine(basePt, tipPt,
        Paint()..color = Colors.red
          ..strokeWidth = size.shortestSide * 0.012 ..strokeCap = StrokeCap.round);
    canvas.drawLine(
      Offset(center.dx + needleLen * 0.7 * nx,
             center.dy + needleLen * 0.7 * ny), tipPt,
      Paint()..color = Colors.white
        ..strokeWidth = size.shortestSide * 0.005 ..strokeCap = StrokeCap.round,
    );

    // Hub
    final hubR = size.shortestSide * 0.06;
    canvas.drawCircle(center, hubR, Paint()..color = const Color(0xFF1A1A2E));
    canvas.drawCircle(center, hubR,
        Paint()..color = Colors.white24 ..style = PaintingStyle.stroke
          ..strokeWidth = size.shortestSide * 0.008);
    canvas.drawCircle(
      Offset(center.dx - hubR * 0.3, center.dy - hubR * 0.3),
      hubR * 0.2, Paint()..color = Colors.white30,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.value != value || old.maxValue != maxValue ||
      old.warnValue != warnValue || old.dangerValue != dangerValue;
}

// ────────────────────────────────────────────────────────────────────────────
// Tachometer
// ────────────────────────────────────────────────────────────────────────────
class _TachometerGauge extends StatelessWidget {
  final ValueNotifier<double> rpmNotifier;
  final ValueNotifier<int>    rpmWarningNotifier;
  final ValueNotifier<int>    rpmLimiterNotifier;

  const _TachometerGauge({
    required this.rpmNotifier,
    required this.rpmWarningNotifier,
    required this.rpmLimiterNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: rpmNotifier,
      builder: (_, rpm, __) => ValueListenableBuilder<int>(
        valueListenable: rpmWarningNotifier,
        builder: (_, warn, __) => ValueListenableBuilder<int>(
          valueListenable: rpmLimiterNotifier,
          builder: (_, lim, __) {
            final maxRpm   = lim  > 0 ? lim.toDouble()  : 9000.0;
            final warnRpm  = warn > 0 ? warn.toDouble() : maxRpm * 0.80;
            final step     = (maxRpm / 8).roundToDouble();
            final labelCnt = (maxRpm / step).round();
            final labels   = List.generate(
              labelCnt + 1, (i) => ((i * step) ~/ 1000).toString());

            return CustomPaint(
              painter: _GaugePainter(
                value:       rpm.clamp(0, maxRpm),
                minValue:    0,
                maxValue:    maxRpm,
                warnValue:   warnRpm * 0.78,
                dangerValue: warnRpm,
                unit:        'rpm ×1000',
                labels:      labels,
                labelStep:   step,
              ),
              child: const SizedBox.expand(),
            );
          },
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Speedometer
// ────────────────────────────────────────────────────────────────────────────
class _SpeedometerGauge extends StatelessWidget {
  final ValueNotifier<double> speedNotifier;
  const _SpeedometerGauge({required this.speedNotifier});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: speedNotifier,
      builder: (_, speed, __) => CustomPaint(
        painter: _GaugePainter(
          value:       speed.clamp(0, 320),
          minValue:    0,
          maxValue:    320,
          warnValue:   160,
          dangerValue: 240,
          unit:        'km/h',
          labels:      ['0','40','80','120','160','200','240','280','320'],
          labelStep:   40,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Center panel – gear / digital speed / fuel bar
// LayoutBuilder で利用可能サイズを取得し、overflow を防ぐ
// ────────────────────────────────────────────────────────────────────────────
class _CenterPanel extends StatelessWidget {
  final ValueNotifier<int>    gearNotifier;
  final ValueNotifier<double> speedNotifier;
  final ValueNotifier<double> fuelLevelNotifier;
  final ValueNotifier<double> fuelCapacityNotifier;

  const _CenterPanel({
    required this.gearNotifier,
    required this.speedNotifier,
    required this.fuelLevelNotifier,
    required this.fuelCapacityNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, cs) {
      final availH = cs.maxHeight;
      final availW = cs.maxWidth;

      // フォントサイズをセンターパネルの実際サイズから計算
      final gearFontSize  = (availH * 0.35).clamp(32.0, 160.0);
      final speedFontSize = (availH * 0.09).clamp(12.0, 44.0);
      final labelFontSize = (availH * 0.042).clamp(8.0, 18.0);

      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ── Gear ──────────────────────────────────────────────────────
          Expanded(
            flex: 5,
            child: Center(
              child: ValueListenableBuilder<int>(
                valueListenable: gearNotifier,
                builder: (_, gear, __) {
                  final label = gear == 0 ? 'N' : gear == 15 ? 'R' : '$gear';
                  return FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      style: TextStyle(
                        color: gear == 0
                            ? Colors.grey
                            : gear == 15
                                ? Colors.redAccent
                                : Colors.white,
                        fontSize: gearFontSize,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                        shadows: [
                          Shadow(
                            color: Colors.cyanAccent.withValues(alpha: 0.4),
                            blurRadius: 24,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // ── Speed (digital) ───────────────────────────────────────────
          Expanded(
            flex: 3,
            child: Center(
              child: ValueListenableBuilder<double>(
                valueListenable: speedNotifier,
                builder: (_, speed, __) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        speed.toStringAsFixed(0),
                        style: TextStyle(
                          color: Colors.cyanAccent,
                          fontSize: speedFontSize,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    Text(
                      'km/h',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: labelFontSize,
                        letterSpacing: 3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Fuel bar ──────────────────────────────────────────────────
          Expanded(
            flex: 2,
            child: Center(
              child: _FuelMiniBar(
                fuelLevelNotifier:    fuelLevelNotifier,
                fuelCapacityNotifier: fuelCapacityNotifier,
                availW:               availW,
                labelFontSize:        labelFontSize,
              ),
            ),
          ),
        ],
      );
    });
  }
}

class _FuelMiniBar extends StatelessWidget {
  final ValueNotifier<double> fuelLevelNotifier;
  final ValueNotifier<double> fuelCapacityNotifier;
  final double availW;
  final double labelFontSize;

  const _FuelMiniBar({
    required this.fuelLevelNotifier,
    required this.fuelCapacityNotifier,
    required this.availW,
    required this.labelFontSize,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: fuelLevelNotifier,
      builder: (_, level, __) => ValueListenableBuilder<double>(
        valueListenable: fuelCapacityNotifier,
        builder: (_, cap, __) {
          final ratio = cap > 0 ? (level / cap).clamp(0.0, 1.0) : 0.0;
          final isLow = ratio < 0.25;
          // バーの幅はセンターパネルの幅に合わせる（80%）
          final barW = (availW * 0.80).clamp(40.0, 160.0);
          final barH = (labelFontSize * 0.75).clamp(5.0, 12.0);

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'FUEL',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: labelFontSize * 0.8,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 3),
              SizedBox(
                width: barW,
                height: barH,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(barH / 2),
                  child: Stack(
                    children: [
                      Container(color: Colors.white12),
                      FractionallySizedBox(
                        widthFactor: ratio,
                        child: Container(
                          decoration: BoxDecoration(
                            color: isLow ? Colors.redAccent : Colors.greenAccent,
                            boxShadow: [
                              BoxShadow(
                                color: (isLow ? Colors.red : Colors.green)
                                    .withValues(alpha: 0.5),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                cap > 0
                    ? '${level.toStringAsFixed(1)} / ${cap.toStringAsFixed(0)} L'
                    : '-- L',
                style: TextStyle(
                  color: isLow ? Colors.redAccent : Colors.white54,
                  fontSize: labelFontSize * 0.82,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Pedal strip
// ────────────────────────────────────────────────────────────────────────────
class _PedalStrip extends StatelessWidget {
  final ValueNotifier<double> throttleNotifier;
  final ValueNotifier<double> brakeNotifier;

  const _PedalStrip({
    required this.throttleNotifier,
    required this.brakeNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, cs) {
      final h         = cs.maxHeight;
      final w         = cs.maxWidth;
      // barH と labelSize を h から計算し、合計が h を超えないよう制限
      final labelSize = (h * 0.26).clamp(7.0, 15.0);
      final barH      = (h * 0.18).clamp(4.0, 11.0);
      final gap       = (h * 0.06).clamp(2.0, 6.0);

      return Padding(
        padding: EdgeInsets.symmetric(horizontal: w * 0.05, vertical: gap),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            _PedalRow(label: 'THROTTLE', notifier: throttleNotifier,
                color: Colors.greenAccent, barH: barH, labelSize: labelSize),
            SizedBox(height: gap),
            _PedalRow(label: 'BRAKE',    notifier: brakeNotifier,
                color: Colors.redAccent,   barH: barH, labelSize: labelSize),
          ],
        ),
      );
    });
  }
}

class _PedalRow extends StatelessWidget {
  final String                label;
  final ValueNotifier<double> notifier;
  final Color                 color;
  final double                barH;
  final double                labelSize;

  const _PedalRow({
    required this.label,
    required this.notifier,
    required this.color,
    required this.barH,
    required this.labelSize,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: notifier,
      builder: (_, value, __) {
        return Row(
          children: [
            SizedBox(
              width: labelSize * 5.5,
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: labelSize,
                  letterSpacing: 1.2,
                ),
                textAlign: TextAlign.right,
                overflow: TextOverflow.clip,
              ),
            ),
            SizedBox(width: labelSize * 0.5),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(barH / 2),
                child: SizedBox(
                  height: barH,
                  child: Stack(
                    children: [
                      Container(color: Colors.white10),
                      FractionallySizedBox(
                        widthFactor: value.clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: color,
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(alpha: 0.6),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(width: labelSize * 0.5),
            SizedBox(
              width: labelSize * 2.8,
              child: Text(
                '${(value * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  color: color,
                  fontSize: labelSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
