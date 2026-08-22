import 'package:flutter/material.dart';
import '../models/telemetry_sample.dart';

/// 計測中のラップの軌跡を自動フィットで描画する(進捗確認用)
/// Draws the in-progress lap's trajectory, auto-fitted to fill the view (for progress feedback)
class CaptureProgressPainter extends CustomPainter {
  // 1点しかない時に使う最小表示範囲(m) / Minimum view span (m) when there's only one point so far
  static const double _minSpanMeters = 20;
  // 外接矩形の周囲に持たせる余白の比率 / Padding ratio added around the bounding box
  static const double _fitPadding = 1.3;

  final List<TelemetrySample> Function() samplesProvider;
  // アーム前(キャプチャ対象と確定していない)のプレビューは控えめな色にする
  // Dimmer color for the pre-arm preview (not yet the lap that will be captured)
  final Color color;

  // 完了後に確定済みサンプルを静的表示する場合は repaint を省略できる
  // repaint can be omitted when statically displaying a completed lap's samples
  CaptureProgressPainter({
    super.repaint,
    required this.samplesProvider,
    this.color = Colors.redAccent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final samples = samplesProvider();
    if (samples.isEmpty) return;

    var minX = samples.first.posX;
    var maxX = samples.first.posX;
    var minZ = samples.first.posZ;
    var maxZ = samples.first.posZ;
    for (final sample in samples) {
      if (sample.posX < minX) minX = sample.posX;
      if (sample.posX > maxX) maxX = sample.posX;
      if (sample.posZ < minZ) minZ = sample.posZ;
      if (sample.posZ > maxZ) maxZ = sample.posZ;
    }

    final spanX = (maxX - minX).clamp(_minSpanMeters, double.infinity);
    final spanZ = (maxZ - minZ).clamp(_minSpanMeters, double.infinity);
    final scaleX = size.width / (spanX * _fitPadding);
    final scaleZ = size.height / (spanZ * _fitPadding);
    final scale = scaleX < scaleZ ? scaleX : scaleZ;
    final centerX = (minX + maxX) / 2;
    final centerZ = (minZ + maxZ) / 2;

    Offset toCanvas(double x, double z) => Offset(
      size.width / 2 + (x - centerX) * scale,
      size.height / 2 + (z - centerZ) * scale,
    );

    final path = Path();
    final first = toCanvas(samples.first.posX, samples.first.posZ);
    path.moveTo(first.dx, first.dy);
    for (final sample in samples.skip(1)) {
      final p = toCanvas(sample.posX, sample.posZ);
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // サンプル点そのものも打つ(疎密でサンプル密度=速度の変化が分かる)
    // Also plot the samples themselves (their spacing hints at speed variation)
    final dotPaint = Paint()..color = color;
    for (final sample in samples) {
      final p = toCanvas(sample.posX, sample.posZ);
      canvas.drawCircle(p, 2.5, dotPaint);
    }

    final current = toCanvas(samples.last.posX, samples.last.posZ);
    canvas.drawCircle(current, 10, Paint()..color = Colors.white24);
    canvas.drawCircle(current, 6, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CaptureProgressPainter oldDelegate) =>
      oldDelegate.color != color;
}
