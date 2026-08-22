import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// 実機LCDパネルを思わせる、ごく薄いピクセルグリッドの質感レイヤー。
/// パネル背景に重ねて使う（情報を持たない純粋な装飾レイヤー）
/// A faint pixel-grid texture evoking a real LCD instrument panel.
/// Purely decorative — layered behind panel content, carries no information.
class LcdGridTexture extends StatelessWidget {
  const LcdGridTexture({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: _LcdGridPainter(), size: Size.infinite),
    );
  }
}

class _LcdGridPainter extends CustomPainter {
  static const double _step = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.hudTextPrimary.withValues(alpha: 0.025)
      ..strokeWidth = 1;

    for (double x = 0; x <= size.width; x += _step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += _step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LcdGridPainter oldDelegate) => false;
}
