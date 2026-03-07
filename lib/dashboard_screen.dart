import 'dart:math';
import 'package:flutter/material.dart';

/// レーシングダッシュボード全体レイアウト
/// [ギア表示] | [円形タコメーター + 速度] | [スロットル/ブレーキバー]
class RacingDashboard extends StatelessWidget {
  final ValueNotifier<double> rpmNotifier;
  final ValueNotifier<double> speedNotifier;
  final ValueNotifier<int> gearNotifier;
  final ValueNotifier<double> throttleNotifier;
  final ValueNotifier<double> brakeNotifier;
  final ValueNotifier<int> rpmWarningNotifier;
  final ValueNotifier<int> rpmLimiterNotifier;

  const RacingDashboard({
    super.key,
    required this.rpmNotifier,
    required this.speedNotifier,
    required this.gearNotifier,
    required this.throttleNotifier,
    required this.brakeNotifier,
    required this.rpmWarningNotifier,
    required this.rpmLimiterNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF0A0A14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 90, child: _GearPanel(gearNotifier: gearNotifier)),
          Expanded(
            child: _TachometerPanel(
              rpmNotifier: rpmNotifier,
              speedNotifier: speedNotifier,
              rpmWarningNotifier: rpmWarningNotifier,
              rpmLimiterNotifier: rpmLimiterNotifier,
            ),
          ),
          SizedBox(
            width: 72,
            child: _PedalPanel(
              throttleNotifier: throttleNotifier,
              brakeNotifier: brakeNotifier,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── ギアパネル ────────────────────────────────────────────────────────────────

class _GearPanel extends StatelessWidget {
  final ValueNotifier<int> gearNotifier;
  const _GearPanel({required this.gearNotifier});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: gearNotifier,
      builder: (_, gear, __) {
        final label = gear == 0 ? 'N' : '$gear';
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'GEAR',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: const Color(0xFF4FC3F7),
                  fontSize: 68,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: const Color(0xFF4FC3F7).withValues(alpha: 0.7),
                      blurRadius: 24,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── タコメーターパネル ───────────────────────────────────────────────────────

class _TachometerPanel extends StatelessWidget {
  final ValueNotifier<double> rpmNotifier;
  final ValueNotifier<double> speedNotifier;
  final ValueNotifier<int> rpmWarningNotifier;
  final ValueNotifier<int> rpmLimiterNotifier;

  const _TachometerPanel({
    required this.rpmNotifier,
    required this.speedNotifier,
    required this.rpmWarningNotifier,
    required this.rpmLimiterNotifier,
  });

  @override
  Widget build(BuildContext context) {
    final listenable = Listenable.merge([
      rpmNotifier,
      speedNotifier,
      rpmWarningNotifier,
      rpmLimiterNotifier,
    ]);
    return ListenableBuilder(
      listenable: listenable,
      builder: (_, __) {
        final rpm       = rpmNotifier.value;
        final speed     = speedNotifier.value;
        final rpmLimiter = rpmLimiterNotifier.value;
        final rpmWarning = rpmWarningNotifier.value;
        final maxRpm    = rpmLimiter > 0 ? rpmLimiter.toDouble() : 9000.0;
        final warningRpm = rpmWarning > 0 ? rpmWarning.toDouble() : maxRpm * 0.85;
        return CustomPaint(
          painter: TachometerPainter(
            rpm: rpm,
            maxRpm: maxRpm,
            warningRpm: warningRpm,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  speed.toStringAsFixed(0),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 64,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                    height: 1.0,
                  ),
                ),
                const Text(
                  'km/h',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 16,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '${rpm.toStringAsFixed(0)} RPM',
                  style: const TextStyle(
                    color: Colors.white30,
                    fontSize: 13,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── ペダルバーパネル ──────────────────────────────────────────────────────────

class _PedalPanel extends StatelessWidget {
  final ValueNotifier<double> throttleNotifier;
  final ValueNotifier<double> brakeNotifier;

  const _PedalPanel({
    required this.throttleNotifier,
    required this.brakeNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _VerticalBar(
            notifier: throttleNotifier,
            label: 'T',
            color: const Color(0xFF4CAF50),
          ),
          _VerticalBar(
            notifier: brakeNotifier,
            label: 'B',
            color: const Color(0xFFF44336),
          ),
        ],
      ),
    );
  }
}

class _VerticalBar extends StatelessWidget {
  final ValueNotifier<double> notifier;
  final String label;
  final Color color;

  const _VerticalBar({
    required this.notifier,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: notifier,
      builder: (_, value, __) {
        final clamped = value.clamp(0.0, 1.0);
        return SizedBox(
          width: 22,
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color.withValues(alpha: 0.8),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    // 背景
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    // 塗りつぶし（下から上へ）
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        widthFactor: 1.0,
                        heightFactor: clamped,
                        child: Container(
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: clamped > 0.05
                                ? [
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.5),
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${(clamped * 100).round()}',
                style: TextStyle(
                  color: color.withValues(alpha: 0.7),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── タコメーター CustomPainter ───────────────────────────────────────────────

/// アーク設定:
///   0 rpm = 135° (画面左下、7:30の位置)
///   maxRpm = 375°(= 15°, 画面右下、3:15の位置)
///   時計回りに 240° スイープ
class TachometerPainter extends CustomPainter {
  final double rpm;
  final double maxRpm;
  final double warningRpm;

  static const double _startAngle = 3 * pi / 4; // 135°
  static const double _totalSweep = 4 * pi / 3; // 240°

  const TachometerPainter({
    required this.rpm,
    required this.maxRpm,
    required this.warningRpm,
  });

  @override
  bool shouldRepaint(TachometerPainter old) =>
      old.rpm != rpm || old.maxRpm != maxRpm || old.warningRpm != warningRpm;

  /// RPM比率に応じてアークの色を返す (緑→黄→赤)
  Color _arcColor(double rpmRatio, double warningRatio) {
    if (rpmRatio >= warningRatio) return const Color(0xFFFF1744);
    final t = rpmRatio / warningRatio;
    if (t < 0.80) return const Color(0xFF4CAF50);
    return Color.lerp(
      const Color(0xFF4CAF50),
      const Color(0xFFFFD740),
      (t - 0.80) / 0.20,
    )!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 * 0.88;
    final trackW = radius * 0.13;
    final trackR = radius - trackW / 2;
    final rect = Rect.fromCircle(center: center, radius: trackR);

    final rpmRatio = (rpm / maxRpm).clamp(0.0, 1.0);
    final warningRatio = (warningRpm / maxRpm).clamp(0.0, 1.0);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = trackW
      ..strokeCap = StrokeCap.butt;

    // 1. 背景トラック
    paint.color = const Color(0xFF161624);
    canvas.drawArc(rect, _startAngle, _totalSweep, false, paint);

    // 2. ゾーンヒント（薄い色帯）
    paint.color = const Color(0xFF0C2010); // 緑ゾーン
    canvas.drawArc(
      rect, _startAngle, warningRatio * _totalSweep, false, paint,
    );
    paint.color = const Color(0xFF200808); // 赤ゾーン
    canvas.drawArc(
      rect,
      _startAngle + warningRatio * _totalSweep,
      (1.0 - warningRatio) * _totalSweep,
      false,
      paint,
    );

    // 3. 現在RPM アーク（グロー付き）
    if (rpmRatio > 0.001) {
      final arcColor = _arcColor(rpmRatio, warningRatio);
      final sweep = rpmRatio * _totalSweep;

      // 外グロー
      paint
        ..color = arcColor.withValues(alpha: 0.15)
        ..strokeWidth = trackW + 16;
      canvas.drawArc(rect, _startAngle, sweep, false, paint);

      // 内グロー
      paint
        ..color = arcColor.withValues(alpha: 0.30)
        ..strokeWidth = trackW + 6;
      canvas.drawArc(rect, _startAngle, sweep, false, paint);

      // ソリッドアーク
      paint
        ..color = arcColor
        ..strokeWidth = trackW;
      canvas.drawArc(rect, _startAngle, sweep, false, paint);

      // 先端の輝点
      final leadAngle = _startAngle + sweep;
      canvas.drawCircle(
        Offset(
          center.dx + trackR * cos(leadAngle),
          center.dy + trackR * sin(leadAngle),
        ),
        trackW * 0.55,
        Paint()..color = Colors.white.withValues(alpha: 0.9),
      );
    }

    // 4. 警告ライン（オレンジ縦線）
    final warnAngle = _startAngle + warningRatio * _totalSweep;
    canvas.drawLine(
      Offset(
        center.dx + (trackR - trackW) * cos(warnAngle),
        center.dy + (trackR - trackW) * sin(warnAngle),
      ),
      Offset(
        center.dx + (trackR + trackW * 0.5 + 4) * cos(warnAngle),
        center.dy + (trackR + trackW * 0.5 + 4) * sin(warnAngle),
      ),
      Paint()
        ..color = const Color(0xFFFF6D00)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    // 5. 目盛りと数字ラベル
    final int maxK = (maxRpm / 1000).ceil();
    final tickOuterR = trackR - trackW / 2 - 2;
    final labelR = trackR - trackW / 2 - 26;

    for (int mark = 0; mark <= maxK * 1000; mark += 500) {
      final ratio = mark / maxRpm;
      if (ratio > 1.01) break;
      final angle = _startAngle + ratio.clamp(0.0, 1.0) * _totalSweep;
      final isMajor = mark % 1000 == 0;
      final tickLen = isMajor ? 14.0 : 7.0;

      canvas.drawLine(
        Offset(
          center.dx + (tickOuterR - tickLen) * cos(angle),
          center.dy + (tickOuterR - tickLen) * sin(angle),
        ),
        Offset(
          center.dx + tickOuterR * cos(angle),
          center.dy + tickOuterR * sin(angle),
        ),
        Paint()
          ..color = isMajor ? Colors.white60 : Colors.white24
          ..strokeWidth = isMajor ? 2.0 : 1.0
          ..strokeCap = StrokeCap.round,
      );

      if (isMajor && mark > 0) {
        final tp = TextPainter(
          text: TextSpan(
            text: '${mark ~/ 1000}',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
          canvas,
          Offset(
            center.dx + labelR * cos(angle) - tp.width / 2,
            center.dy + labelR * sin(angle) - tp.height / 2,
          ),
        );
      }
    }

    // 6. 内側デコレーションリング
    canvas.drawCircle(
      center,
      radius * 0.36,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = Colors.white.withValues(alpha: 0.06),
    );
  }
}
