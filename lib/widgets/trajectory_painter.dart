import 'package:flutter/material.dart';
import '../services/trajectory_notifier.dart';

/// 走行軌跡を赤色の線で描画し、現在地を白いマーカーで示す。
/// Draws the driving trajectory as a red line and marks the current position in white.
class TrajectoryPainter extends CustomPainter {
  final TrajectoryNotifier trajectory;
  final Offset Function(Offset worldPoint) worldToCanvas;

  TrajectoryPainter({required this.trajectory, required this.worldToCanvas})
    : super(repaint: trajectory);

  @override
  void paint(Canvas canvas, Size size) {
    final points = trajectory.points;
    if (points.isEmpty) return;

    final linePaint = Paint()
      ..color = Colors.redAccent
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    final first = worldToCanvas(points.first);
    path.moveTo(first.dx, first.dy);
    for (var i = 1; i < points.length; i++) {
      final p = worldToCanvas(points[i]);
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, linePaint);

    final current = worldToCanvas(points.last);
    // 現在地を淡いグロー付きの白いドットで強調表示する
    // Highlight the current position with a soft glow behind a white dot
    canvas.drawCircle(current, 16, Paint()..color = Colors.white24);
    canvas.drawCircle(current, 9, Paint()..color = Colors.white);
    canvas.drawCircle(
      current,
      9,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant TrajectoryPainter oldDelegate) => false;
}
