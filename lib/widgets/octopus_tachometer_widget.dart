import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Widget ───────────────────────────────────────────────────────────────────

class OctopusTachometer extends StatefulWidget {
  final ValueNotifier<double> rpmNotifier;
  const OctopusTachometer({super.key, required this.rpmNotifier});

  @override
  State<OctopusTachometer> createState() => _OctopusTachometerState();
}

class _OctopusTachometerState extends State<OctopusTachometer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;

  @override
  void initState() {
    super.initState();
    // 100s cycle — more than enough for all animation periods
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 100),
    )..repeat();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  String _fmt(double rpm) {
    final n = rpm.round();
    if (n >= 1000) {
      return '${n ~/ 1000},${(n % 1000).toString().padLeft(3, '0')}';
    }
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF05080F),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 500 / 520,
                child: ValueListenableBuilder<double>(
                  valueListenable: widget.rpmNotifier,
                  builder: (_, rpm, __) {
                    return AnimatedBuilder(
                      animation: _ticker,
                      builder: (_, __) => CustomPaint(
                        painter: _TachometerPainter(
                          rpm: rpm,
                          animTime: _ticker.value * 100.0,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          ValueListenableBuilder<double>(
            valueListenable: widget.rpmNotifier,
            builder: (_, rpm, __) {
              final isRed = rpm >= 7200;
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  children: [
                    Text(
                      _fmt(rpm),
                      style: GoogleFonts.orbitron(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: isRed
                            ? const Color(0xFFEF4444)
                            : const Color(0xFFDDEEFF),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isRed ? '⚠ REDLINE' : 'ENGINE RPM',
                      style: GoogleFonts.orbitron(
                        fontSize: 9,
                        letterSpacing: 3.5,
                        color: isRed
                            ? const Color(0xFFEF4444).withAlpha(135)
                            : const Color(0xFF2D4D70),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── CustomPainter ────────────────────────────────────────────────────────────

class _TachometerPainter extends CustomPainter {
  final double rpm;
  final double animTime;

  _TachometerPainter({required this.rpm, required this.animTime});

  // SVG 500×520 coordinate space
  static const double cx = 250, cy = 218;
  static const double gaugeR = 196;
  static const double trackR = 186; // gaugeR - 10
  static const double headR = 70;
  static const double needleR = 170;
  static const double maxRpm = 9000;
  static const double redline = 7200;
  static const double revLimit = 8800;

  // [angle°, length, curl(−1/+1), animDelay]
  static const List<List<double>> _tentacleCfg = [
    [32.0, 86.0, -1.0, 0.00],
    [48.0, 94.0, 1.0, 0.15],
    [65.0, 100.0, -1.0, 0.28],
    [82.0, 104.0, 1.0, 0.40],
    [99.0, 104.0, -1.0, 0.50],
    [116.0, 100.0, 1.0, 0.58],
    [133.0, 94.0, -1.0, 0.65],
    [149.0, 86.0, 1.0, 0.70],
  ];

  // ── Helpers ──────────────────────────────────────────────────────────────

  double _rpmToAngle(double r) => 135 + (r.clamp(0, maxRpm) / maxRpm) * 270;

  Offset _polar(double deg, double r) {
    final rad = deg * pi / 180;
    return Offset(cx + r * cos(rad), cy + r * sin(rad));
  }

  Offset _cubicBez(double t, Offset p0, Offset p1, Offset p2, Offset p3) {
    final mt = 1 - t;
    return Offset(
      mt * mt * mt * p0.dx +
          3 * mt * mt * t * p1.dx +
          3 * mt * t * t * p2.dx +
          t * t * t * p3.dx,
      mt * mt * mt * p0.dy +
          3 * mt * mt * t * p1.dy +
          3 * mt * t * t * p2.dy +
          t * t * t * p3.dy,
    );
  }

  // 0.2 s period: opacity 1.0 → 0.55 → 1.0
  double _redPulse() => 0.775 + 0.225 * cos(animTime * 2 * pi / 0.2);

  // 4 s period blink: scaleY 1.0 → 0.05 → 1.0 (quick dip at 91 % of cycle)
  double _eyeScale(double delay) {
    final t = ((animTime - delay) % 4.0) / 4.0;
    if (t > 0.85) {
      final bt = (t - 0.85) / 0.15;
      return bt < 0.4
          ? 1.0 - 0.95 * (bt / 0.4)
          : 0.05 + 0.95 * ((bt - 0.4) / 0.6);
    }
    return 1.0;
  }

  // Clockwise SVG-style arc: sweep is always the positive clockwise distance.
  void _svgArc(Canvas canvas, double a0, double a1, double r, Paint paint) {
    double sweep = a1 - a0;
    if (sweep <= 0) sweep += 360;
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(cx, cy), radius: r),
      a0 * pi / 180,
      sweep * pi / 180,
      false,
      paint,
    );
  }

  // ── paint ─────────────────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    final scale = min(size.width / 500, size.height / 520);
    canvas.save();
    canvas.translate(
        (size.width - 500 * scale) / 2, (size.height - 520 * scale) / 2);
    canvas.scale(scale, scale);

    final isRed = rpm >= redline;
    final curAngle = _rpmToAngle(rpm);
    final redAngle = _rpmToAngle(redline); // ≈351°
    final limAngle = _rpmToAngle(revLimit); // ≈399°

    _drawBackground(canvas);
    _drawGaugeArcs(canvas, curAngle, redAngle, limAngle, isRed);
    _drawTicks(canvas);
    _drawLabel(canvas);
    _drawTentacles(canvas);
    _drawHeadBack(canvas, isRed);
    _drawBeak(canvas, curAngle, isRed);
    _drawFaceFront(canvas, curAngle);

    canvas.restore();
  }

  // ── Draw layers ───────────────────────────────────────────────────────────

  void _drawBackground(Canvas canvas) {
    const center = Offset(cx, cy);
    const r = gaugeR + 12.0;
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF0D1728), Color(0xFF050810)],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0xFF0F1E30)
        ..strokeWidth = 2.5,
    );
  }

  void _drawGaugeArcs(
      Canvas canvas, double cur, double red, double lim, bool isRed) {
    // Red zone background (constant, behind fill)
    _svgArc(
        canvas,
        red,
        405, // 135+270 = end of gauge in raw-degree space
        trackR,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = const Color(0xFF4A0808)
          ..strokeWidth = 16
          ..strokeCap = StrokeCap.butt);

    // Normal zone background
    _svgArc(
        canvas,
        135,
        red,
        trackR,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = const Color(0xFF0E1E32)
          ..strokeWidth = 16
          ..strokeCap = StrokeCap.butt);

    // Cyan RPM fill
    if (rpm > 20) {
      final to = min(cur, red);
      // Glow pass
      _svgArc(
          canvas,
          135,
          to,
          trackR,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = const Color(0xFF22D3EE).withAlpha(115)
            ..strokeWidth = 13
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      // Sharp pass
      _svgArc(
          canvas,
          135,
          to,
          trackR,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = const Color(0xFF22D3EE)
            ..strokeWidth = 13
            ..strokeCap = StrokeCap.round);
    }

    // Red zone fill with pulse animation
    if (rpm >= redline) {
      final pulse = _redPulse();
      final to = min(cur, lim);
      _svgArc(
          canvas,
          red,
          to,
          trackR,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = const Color(0xFFEF4444).withAlpha((pulse * 128).round())
            ..strokeWidth = 15
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      _svgArc(
          canvas,
          red,
          to,
          trackR,
          Paint()
            ..style = PaintingStyle.stroke
            ..color =
                const Color(0xFFEF4444).withAlpha((pulse * 255).round())
            ..strokeWidth = 15
            ..strokeCap = StrokeCap.round);
    }

    // Outer gauge rim
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(cx, cy), radius: gaugeR),
      135 * pi / 180,
      270 * pi / 180,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0xFF162540)
        ..strokeWidth = 2,
    );

    // Inner trim arc
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(cx, cy), radius: trackR - 10),
      135 * pi / 180,
      270 * pi / 180,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0xFF0A1525)
        ..strokeWidth = 1.5,
    );
  }

  void _drawTicks(Canvas canvas) {
    for (int r = 0; r <= 9000; r += 500) {
      final a = _rpmToAngle(r.toDouble());
      final inRed = r >= 7200;
      final major = r % 1000 == 0;
      final color =
          inRed ? const Color(0xFFF87171) : const Color(0xFF233550);
      final outer = _polar(a, gaugeR - 2);
      final inner = _polar(a, gaugeR - (major ? 24.0 : 12.0));
      canvas.drawLine(
          inner, outer, Paint()..color = color..strokeWidth = major ? 2.5 : 1.2);
      if (major) {
        final lbl = _polar(a, gaugeR - 40);
        final tp = TextPainter(
          text: TextSpan(
            text: '${r ~/ 1000}',
            style: TextStyle(
                color: color,
                fontSize: 13.5,
                fontWeight: FontWeight.w700),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, lbl - Offset(tp.width / 2, tp.height / 2));
      }
    }
  }

  void _drawLabel(Canvas canvas) {
    final tp = TextPainter(
      text: const TextSpan(
        text: '×1000 RPM',
        style: TextStyle(
            color: Color(0xFF1E3450), fontSize: 11, letterSpacing: 3),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy + 150 - tp.height / 2));
  }

  void _drawTentacles(Canvas canvas) {
    const bodyColor = Color(0xFFCC1A1A);
    const spotColor = Color(0xFFE87030);

    for (int i = 0; i < _tentacleCfg.length; i++) {
      final a = _tentacleCfg[i][0];
      final len = _tentacleCfg[i][1];
      final curl = _tentacleCfg[i][2];
      final delay = _tentacleCfg[i][3];
      final period = 1.4 + i * 0.18;

      final wave = sin((animTime - delay) * 2 * pi / period);
      final aRad = a * pi / 180;
      final pARad = (a + 90) * pi / 180;

      final s = _polar(a, headR * 0.9);
      final p1 = Offset(
        s.dx + len * 0.40 * cos(aRad) + curl * 20 * cos(pARad),
        s.dy + len * 0.40 * sin(aRad) + curl * 20 * sin(pARad),
      );
      final p2 = Offset(
        s.dx + len * 0.75 * cos(aRad) - curl * 12 * cos(pARad),
        s.dy + len * 0.75 * sin(aRad) - curl * 12 * sin(pARad),
      );
      final e = Offset(s.dx + len * cos(aRad), s.dy + len * sin(aRad));

      canvas.save();
      // Rotate tentacle around its root for the wave animation
      canvas.translate(s.dx, s.dy);
      canvas.rotate(wave * 2 * pi / 180);
      canvas.translate(-s.dx, -s.dy);

      // Chunky body
      canvas.drawPath(
        Path()
          ..moveTo(s.dx, s.dy)
          ..cubicTo(p1.dx, p1.dy, p2.dx, p2.dy, e.dx, e.dy),
        Paint()
          ..color = bodyColor
          ..strokeWidth = 22
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );

      // Curled tip
      final curlRad = (a + curl * 70) * pi / 180;
      final tipCurl =
          Offset(e.dx + 22 * cos(curlRad), e.dy + 22 * sin(curlRad));
      canvas.drawPath(
        Path()
          ..moveTo(e.dx, e.dy)
          ..quadraticBezierTo(
              tipCurl.dx, tipCurl.dy,
              (e.dx + tipCurl.dx) / 2, (e.dy + tipCurl.dy) / 2),
        Paint()
          ..color = bodyColor
          ..strokeWidth = 14
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );

      // Orange sucker spots at t = 0.28, 0.54, 0.78
      for (final t in [0.28, 0.54, 0.78]) {
        canvas.drawCircle(
            _cubicBez(t, s, p1, p2, e), 9, Paint()..color = spotColor);
      }

      canvas.restore();
    }
  }

  void _drawHeadBack(Canvas canvas, bool isRed) {
    const center = Offset(cx, cy);
    final pulse = isRed ? _redPulse() : 1.0;

    // Soft aura behind head
    final auraAlpha = (255 * (isRed ? 0.35 * pulse : 0.18)).round();
    canvas.drawCircle(
      center,
      headR + 20,
      Paint()
        ..color = Color.fromARGB(auraAlpha, isRed ? 220 : 200, 30, 30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Head fill with radial gradient
    final colors = isRed
        ? [
            const Color(0xFFFF6060),
            const Color(0xFFEE2020),
            const Color(0xFFAA0A0A)
          ]
        : [
            const Color(0xFFEE4444),
            const Color(0xFFCC1A1A),
            const Color(0xFF8A0A0A)
          ];
    canvas.drawCircle(
      center,
      headR,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.16, -0.30),
          colors: colors,
          stops: const [0.0, 0.6, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: headR)),
    );

    // Specular sheen
    canvas.drawPath(
      Path()
        ..moveTo(cx - 55, cy - 28)
        ..quadraticBezierTo(cx - 42, cy - 72, cx + 10, cy - 68),
      Paint()
        ..color = const Color(0x1FFFFFFF)
        ..strokeWidth = 10
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawBeak(Canvas canvas, double angleDeg, bool isRed) {
    final aRad = angleDeg * pi / 180;
    final perpRad = (angleDeg + 90) * pi / 180;

    final tip = Offset(cx + needleR * cos(aRad), cy + needleR * sin(aRad));
    const bw = 17.0;
    final bL = Offset(cx + bw * cos(perpRad), cy + bw * sin(perpRad));
    final bR = Offset(cx - bw * cos(perpRad), cy - bw * sin(perpRad));
    const ctrlFwd = needleR * 0.55;
    const ctrlPuff = 12.0;
    final cL = Offset(
      bL.dx + ctrlFwd * cos(aRad) + ctrlPuff * cos(perpRad),
      bL.dy + ctrlFwd * sin(aRad) + ctrlPuff * sin(perpRad),
    );
    final cR = Offset(
      bR.dx + ctrlFwd * cos(aRad) - ctrlPuff * cos(perpRad),
      bR.dy + ctrlFwd * sin(aRad) - ctrlPuff * sin(perpRad),
    );
    final back = Offset(cx - 30 * cos(aRad), cy - 30 * sin(aRad));
    final color =
        isRed ? const Color(0xFFFCA5A5) : const Color(0xFFF0921A);

    final beakPath = Path()
      ..moveTo(bL.dx, bL.dy)
      ..quadraticBezierTo(cL.dx, cL.dy, tip.dx, tip.dy)
      ..quadraticBezierTo(cR.dx, cR.dy, bR.dx, bR.dy)
      ..close();

    // Glow pass
    canvas.drawPath(
        beakPath,
        Paint()
          ..color = color.withAlpha(102)
          ..maskFilter =
              MaskFilter.blur(BlurStyle.normal, isRed ? 6.0 : 5.0));
    // Sharp pass
    canvas.drawPath(beakPath, Paint()..color = color);

    // Tip glow dot
    canvas.drawCircle(tip, 6,
        Paint()
          ..color = color.withAlpha(115)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    canvas.drawCircle(tip, 6, Paint()..color = color);

    // Crease
    canvas.drawPath(
      Path()
        ..moveTo(bL.dx, bL.dy)
        ..quadraticBezierTo(
            cx + needleR * 0.25 * cos(aRad),
            cy + needleR * 0.25 * sin(aRad),
            bR.dx,
            bR.dy),
      Paint()
        ..color = (isRed
                ? const Color(0xFFDC4444)
                : const Color(0xFFB85A0A))
            .withAlpha(128)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );

    // Counterweight nub
    canvas.drawCircle(back, 13, Paint()..color = const Color(0xFF1A0A30));
    canvas.drawCircle(
        back,
        13,
        Paint()
          ..color = isRed
              ? const Color(0xFFCC1A1A)
              : const Color(0xFF5B21B6)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke);
  }

  void _drawFaceFront(Canvas canvas, double angleDeg) {
    final aRad = angleDeg * pi / 180;
    final rpmPct = rpm / maxRpm;
    final pupilDx = cos(aRad) * 5;
    final pupilDy = sin(aRad) * 5;
    // Eyebrows raise above 70 % RPM
    final browRaise = rpmPct > 0.7 ? (rpmPct - 0.7) * 16.0 : 0.0;
    final blush = ((rpm - 4000) / 5000).clamp(0.0, 0.55);

    // ── Eyebrows ──────────────────────────────────────────────────────────
    final browPaint = Paint()
      ..color = const Color(0xFF6A0808)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
        Path()
          ..moveTo(cx - 40, cy - 40 - browRaise)
          ..quadraticBezierTo(
              cx - 26, cy - 50 - browRaise, cx - 14, cy - 42 - browRaise),
        browPaint);
    canvas.drawPath(
        Path()
          ..moveTo(cx + 14, cy - 42 - browRaise)
          ..quadraticBezierTo(
              cx + 26, cy - 50 - browRaise, cx + 40, cy - 40 - browRaise),
        browPaint);

    // ── Eyes (blink via scaleY) ────────────────────────────────────────────
    _drawEyeCircle(canvas, const Offset(cx - 24, cy - 26), 16, _eyeScale(0.0));
    _drawEyeCircle(
        canvas, const Offset(cx + 24, cy - 26), 16, _eyeScale(0.07));

    // Pupils — follow the needle angle
    canvas.drawCircle(
        Offset(cx - 24 + pupilDx * 0.5, cy - 26 + pupilDy * 0.5),
        9,
        Paint()..color = const Color(0xFF0A0202));
    canvas.drawCircle(
        Offset(cx + 24 + pupilDx * 0.5, cy - 26 + pupilDy * 0.5),
        9,
        Paint()..color = const Color(0xFF0A0202));

    // Eye highlights
    canvas.drawCircle(
        Offset(cx - 30 + pupilDx * 0.25, cy - 33 + pupilDy * 0.25),
        4.5,
        Paint()..color = Colors.white.withAlpha(230));
    canvas.drawCircle(
        Offset(cx + 18 + pupilDx * 0.25, cy - 33 + pupilDy * 0.25),
        4.5,
        Paint()..color = Colors.white.withAlpha(230));
    canvas.drawCircle(
        Offset(cx - 20 + pupilDx * 0.25, cy - 18 + pupilDy * 0.25),
        2,
        Paint()..color = Colors.white.withAlpha(115));
    canvas.drawCircle(
        Offset(cx + 28 + pupilDx * 0.25, cy - 18 + pupilDy * 0.25),
        2,
        Paint()..color = Colors.white.withAlpha(115));

    // ── Blush (4000+ RPM) ─────────────────────────────────────────────────
    if (blush > 0) {
      final blushPaint = Paint()
        ..color =
            const Color(0xFFF87171).withAlpha((blush * 0.5 * 255).round())
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(const Offset(cx - 42, cy - 8), 14, blushPaint);
      canvas.drawCircle(const Offset(cx + 42, cy - 8), 14, blushPaint);
    }

    // ── Mouth ring (beak emerges from here) ───────────────────────────────
    canvas.drawCircle(
        const Offset(cx, cy), 20, Paint()..color = const Color(0xFFC04820));
    canvas.drawCircle(
        const Offset(cx, cy),
        20,
        Paint()
          ..color = const Color(0xFF7A1C06)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke);
    // Dark interior — beak passes through
    canvas.drawCircle(
        const Offset(cx, cy), 12, Paint()..color = const Color(0xFF3A0804));
    // Rim shine
    canvas.drawPath(
      Path()
        ..moveTo(cx - 11, cy - 10)
        ..quadraticBezierTo(cx, cy - 13, cx + 11, cy - 10),
      Paint()
        ..color = const Color(0x72FF8C3C)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawEyeCircle(
      Canvas canvas, Offset center, double radius, double scaleY) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(1.0, scaleY);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF140404));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TachometerPainter old) =>
      old.rpm != rpm || old.animTime != animTime;
}
