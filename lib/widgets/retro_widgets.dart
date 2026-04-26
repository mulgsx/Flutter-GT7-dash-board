import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Colors ──────────────────────────────────────────────────────────────
const Color rBg       = Color(0xFF050D0D);
const Color rPanel    = Color(0xFF081414);
const Color rBorder   = Color(0xFF0D2020);
const Color rCyan     = Color(0xFF00E4EC);
const Color rCyanDim  = Color(0xFF041A1C);
const Color rGreen    = Color(0xFF00E87A);
const Color rGreenDim = Color(0xFF041A0E);
const Color rAmber    = Color(0xFFFFB300);
const Color rAmberDim = Color(0xFF1E1400);
const Color rRed      = Color(0xFFFF3030);
const Color rRedDim   = Color(0xFF1E0404);
const Color rDim      = Color(0xFF0F2424);
const Color rDimText  = Color(0xFF122020);

BoxDecoration retroPanelDeco() => BoxDecoration(
  color: rPanel,
  border: Border.all(color: rBorder),
  borderRadius: BorderRadius.circular(8),
);

TextStyle retroText({
  double size = 10,
  Color color = rCyan,
  double spacing = 0,
  FontWeight weight = FontWeight.normal,
  bool glow = true,
}) =>
    GoogleFonts.orbitron(
      fontSize: size,
      color: color,
      letterSpacing: spacing,
      fontWeight: weight,
      shadows: glow ? [Shadow(color: color.withValues(alpha: 0.5), blurRadius: 5)] : null,
    );

// ── 7-Segment digit ──────────────────────────────────────────────────────
const Map<String, List<int>> _segMaps = {
  '0': [1,1,1,1,1,1,0], '1': [0,1,1,0,0,0,0], '2': [1,1,0,1,1,0,1],
  '3': [1,1,1,1,0,0,1], '4': [0,1,1,0,0,1,1], '5': [1,0,1,1,0,1,1],
  '6': [1,0,1,1,1,1,1], '7': [1,1,1,0,0,0,0], '8': [1,1,1,1,1,1,1],
  '9': [1,1,1,1,0,1,1], '-': [0,0,0,0,0,0,1], ' ': [0,0,0,0,0,0,0],
};

class SevenSegDigit extends StatelessWidget {
  final String char;
  final Color onColor;
  final Color offColor;
  final double width;
  final double height;

  const SevenSegDigit({
    super.key,
    required this.char,
    this.onColor = rCyan,
    this.offColor = rCyanDim,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(width, height),
    painter: _SevenSegPainter(char: char, on: onColor, off: offColor),
  );
}

class _SevenSegPainter extends CustomPainter {
  final String char;
  final Color on;
  final Color off;

  const _SevenSegPainter({required this.char, required this.on, required this.off});

  Path _hPath(double x, double y, double w, double h) {
    final k = h * 0.42;
    return Path()
      ..moveTo(x + k, y)
      ..lineTo(x + w - k, y)
      ..lineTo(x + w, y + h / 2)
      ..lineTo(x + w - k, y + h)
      ..lineTo(x + k, y + h)
      ..lineTo(x, y + h / 2)
      ..close();
  }

  Path _vPath(double x, double y, double w, double h) {
    final k = w * 0.42;
    return Path()
      ..moveTo(x + w / 2, y)
      ..lineTo(x + w, y + k)
      ..lineTo(x + w, y + h - k)
      ..lineTo(x + w / 2, y + h)
      ..lineTo(x, y + h - k)
      ..lineTo(x, y + k)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final segs = _segMaps[char] ?? [0, 0, 0, 0, 0, 0, 0];
    final w = size.width;
    final h = size.height;
    final t = w * 0.15;
    final g = t * 0.35;
    final mid = h / 2;
    final halfLen = mid - g * 2;

    final paths = [
      _hPath(g, 0,           w - g * 2, t),
      _vPath(w - t, g,       t, halfLen),
      _vPath(w - t, mid + g, t, halfLen - t),
      _hPath(g, h - t,       w - g * 2, t),
      _vPath(0, mid + g,     t, halfLen - t),
      _vPath(0, g,           t, halfLen),
      _hPath(g, mid - t / 2, w - g * 2, t),
    ];

    final offPaint = Paint()..color = off;
    for (int i = 0; i < 7; i++) {
      if (segs[i] == 0) canvas.drawPath(paths[i], offPaint);
    }

    for (int i = 0; i < 7; i++) {
      if (segs[i] == 1) {
        canvas.drawPath(paths[i], Paint()
          ..color = on.withValues(alpha: 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
        canvas.drawPath(paths[i], Paint()..color = on);
      }
    }
  }

  @override
  bool shouldRepaint(_SevenSegPainter old) =>
      old.char != char || old.on != on || old.off != off;
}

class SevenSegDisplay extends StatelessWidget {
  final int value;
  final int digits;
  final Color onColor;
  final Color offColor;
  final double digitWidth;
  final double digitHeight;

  const SevenSegDisplay({
    super.key,
    required this.value,
    this.digits = 3,
    this.onColor = rCyan,
    this.offColor = rCyanDim,
    required this.digitWidth,
    required this.digitHeight,
  });

  @override
  Widget build(BuildContext context) {
    final str = value.abs().toString().padLeft(digits, ' ');
    final chars = str.substring(str.length - digits).split('');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: chars
          .map((c) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: SevenSegDigit(
                  char: c,
                  onColor: onColor,
                  offColor: offColor,
                  width: digitWidth,
                  height: digitHeight,
                ),
              ))
          .toList(),
    );
  }
}

// ── Tach bar ─────────────────────────────────────────────────────────────
class TachBarWidget extends StatelessWidget {
  final double rpm;

  const TachBarWidget({super.key, required this.rpm});

  static const double _rpmMax = 8000;
  static const double _rpmWarning = 6500;
  static const double _rpmLimiter = 7500;
  static const int _numSegs = 56;

  @override
  Widget build(BuildContext context) {
    final pct = (rpm / _rpmMax).clamp(0.0, 1.0);
    final active = (pct * _numSegs).floor();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(9, (n) {
            final col = n >= 8 ? rRed : n >= 7 ? rAmber : rCyan;
            return SizedBox(
              width: 14,
              child: Text(
                '$n',
                textAlign: TextAlign.center,
                style: GoogleFonts.orbitron(
                  fontSize: 9,
                  color: col,
                  shadows: [Shadow(color: col.withValues(alpha: 0.8), blurRadius: 3)],
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 3),
        SizedBox(
          height: 24,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(_numSegs, (i) {
              final isOn = i < active;
              final r = (i / _numSegs) * _rpmMax;
              final onC = r >= _rpmLimiter ? rRed : r >= _rpmWarning ? rAmber : rCyan;
              final offC = r >= _rpmLimiter ? rRedDim : r >= _rpmWarning ? rAmberDim : rCyanDim;
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 0.5),
                  height: 8 + (i / _numSegs) * 14,
                  decoration: BoxDecoration(
                    color: isOn ? onC : offC,
                    borderRadius: BorderRadius.circular(1),
                    boxShadow: isOn
                        ? [BoxShadow(color: onC.withValues(alpha: 0.8), blurRadius: 4)]
                        : null,
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 3),
        Center(
          child: Text(
            'TACH × 1000 r/min',
            style: GoogleFonts.orbitron(
              fontSize: 8,
              color: rCyan.withValues(alpha: 0.6),
              letterSpacing: 3,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Bar gauge ─────────────────────────────────────────────────────────────
class BarGaugeWidget extends StatelessWidget {
  final double value;
  final String label;
  final String leftLabel;
  final String rightLabel;
  final Color color;
  final int segs;

  const BarGaugeWidget({
    super.key,
    required this.value,
    required this.label,
    this.leftLabel = '',
    this.rightLabel = '',
    this.color = rCyan,
    this.segs = 12,
  });

  Color get _dimColor {
    if (color == rGreen) return rGreenDim;
    if (color == rRed) return rRedDim;
    return rCyanDim;
  }

  @override
  Widget build(BuildContext context) {
    final pct = value.clamp(0.0, 1.0);
    final active = (pct * segs).floor();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(leftLabel, style: retroText(size: 8, color: color.withValues(alpha: 0.7), glow: false)),
            Text(rightLabel, style: retroText(size: 8, color: color.withValues(alpha: 0.7), glow: false)),
          ],
        ),
        const SizedBox(height: 3),
        Row(
          children: List.generate(segs, (i) {
            final isOn = i < active;
            final Color segC;
            if (color == rGreen) {
              segC = rGreen;
            } else {
              segC = i >= segs * 0.75 ? rRed : i >= segs * 0.55 ? rAmber : color;
            }
            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1),
                height: 11,
                decoration: BoxDecoration(
                  color: isOn ? segC : _dimColor,
                  borderRadius: BorderRadius.circular(1),
                  boxShadow: isOn
                      ? [BoxShadow(color: segC.withValues(alpha: 0.7), blurRadius: 4)]
                      : null,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 3),
        Center(
          child: Text(label, style: retroText(size: 9, color: color, spacing: 2)),
        ),
      ],
    );
  }
}

// ── Turn signal arrow ─────────────────────────────────────────────────────
class TurnArrowWidget extends StatelessWidget {
  final bool isLeft;
  final bool active;

  const TurnArrowWidget({super.key, required this.isLeft, this.active = false});

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: const Size(30, 28),
        painter: _TurnArrowPainter(isLeft: isLeft, active: active),
      );
}

class _TurnArrowPainter extends CustomPainter {
  final bool isLeft;
  final bool active;

  const _TurnArrowPainter({required this.isLeft, required this.active});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (isLeft) {
      path..moveTo(28, 2)..lineTo(2, 14)..lineTo(28, 26)..close();
    } else {
      path..moveTo(2, 2)..lineTo(28, 14)..lineTo(2, 26)..close();
    }
    if (active) {
      canvas.drawPath(
        path,
        Paint()
          ..color = rGreen.withValues(alpha: 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
    }
    canvas.drawPath(path, Paint()..color = active ? rGreen : rGreen.withValues(alpha: 0.08));
  }

  @override
  bool shouldRepaint(_TurnArrowPainter old) => old.active != active;
}

// ── Warning light ─────────────────────────────────────────────────────────
class WarnLightWidget extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final IconData icon;

  const WarnLightWidget({
    super.key,
    required this.label,
    required this.active,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 30,
          height: 26,
          decoration: BoxDecoration(
            color: active ? color.withValues(alpha: 0.12) : rBg,
            border: Border.all(color: active ? color : const Color(0xFF0A1A1A)),
            borderRadius: BorderRadius.circular(3),
            boxShadow: active
                ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 8)]
                : null,
          ),
          child: Icon(icon, size: 14, color: active ? color : rDimText),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: retroText(size: 6, color: active ? color : rDimText, spacing: 0.3, glow: active),
        ),
      ],
    );
  }
}

// ── Clock ─────────────────────────────────────────────────────────────────
class RetroClock extends StatefulWidget {
  const RetroClock({super.key});

  @override
  State<RetroClock> createState() => _RetroClockState();
}

class _RetroClockState extends State<RetroClock> {
  late Timer _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = _now.hour.toString().padLeft(2, '0');
    final m = _now.minute.toString().padLeft(2, '0');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('CLOCK', style: retroText(size: 7, color: rDim, glow: false)),
        const SizedBox(height: 4),
        Text(
          '$h:$m',
          style: GoogleFonts.shareTechMono(
            fontSize: 22,
            color: rGreen,
            letterSpacing: 3,
            shadows: [Shadow(color: rGreen.withValues(alpha: 0.6), blurRadius: 8)],
          ),
        ),
      ],
    );
  }
}

// ── Scanlines overlay ─────────────────────────────────────────────────────
class ScanlinesOverlay extends StatelessWidget {
  final Widget child;

  const ScanlinesOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          child,
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _ScanlinesPainter()),
            ),
          ),
        ],
      );
}

class _ScanlinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.black.withValues(alpha: 0.06);
    for (double y = 3; y < size.height; y += 4) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), p);
    }
  }

  @override
  bool shouldRepaint(_ScanlinesPainter _) => false;
}
