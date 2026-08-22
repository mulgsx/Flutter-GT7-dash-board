import 'package:flutter/material.dart';

/// 車両の走行軌跡（X-Z平面）を保持する。
/// CustomPainter の repaint リスナーとして使うことで、Widget ツリーを再ビルドせずに
/// キャンバスだけを再描画できる（60Hz更新でもパフォーマンスを維持するため）。
/// Holds the vehicle's driving trajectory (X-Z plane).
/// Used as a CustomPainter's repaint listener so only the canvas repaints,
/// not the widget tree — keeps 60Hz updates cheap.
class TrajectoryNotifier extends ChangeNotifier {
  final List<Offset> _points = [];

  // 画面を軌跡全体にフィットさせるための外接矩形。点を追加するたびに更新する
  // Bounding box of all recorded points, kept up to date as points are added,
  // so the view can be fit to the whole trajectory so far.
  Rect? _bounds;

  List<Offset> get points => _points;
  Offset? get currentPoint => _points.isEmpty ? null : _points.last;
  Rect? get bounds => _bounds;

  void addPoint(double x, double z) {
    final point = Offset(x, z);
    _points.add(point);
    _bounds = _bounds == null
        ? Rect.fromPoints(point, point)
        : _bounds!.expandToInclude(Rect.fromPoints(point, point));
    notifyListeners();
  }

  /// 軌跡だけを消去する。以降に届く座標からまた描画を再開する。
  /// Clears the trajectory only; drawing resumes from whatever position arrives next.
  void reset() {
    _points.clear();
    _bounds = null;
    notifyListeners();
  }
}
