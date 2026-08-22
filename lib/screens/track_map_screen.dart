import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/gt7_telemetry_service.dart';
import '../widgets/trajectory_painter.dart';

/// 黒背景に赤い線で走行軌跡を描く、指2本で拡大縮小できるトラックマップ画面。
/// A track map screen: red trajectory line on a black background, pinch-to-zoom with two fingers.
class TrackMapScreen extends StatefulWidget {
  final GT7TelemetryService service;

  const TrackMapScreen({super.key, required this.service});

  @override
  State<TrackMapScreen> createState() => _TrackMapScreenState();
}

class _TrackMapScreenState extends State<TrackMapScreen> {
  // ワールド座標(m) → キャンバス座標(px) の変換係数とキャンバスサイズ
  // World coordinates (m) → canvas coordinates (px): scale factor and canvas size
  static const double _pixelsPerMeter = 2.0;
  static const double _canvasSize =
      40000; // 中心から半径約±10kmをカバー / Covers roughly ±10km from center
  // 1点しかない（走り出し直後）ときに使う最小表示範囲(m) / Minimum view span (m) used when there's only one point so far
  static const double _minSpanMeters = 60;
  // フィット時に外接矩形の周囲に持たせる余白の比率 / Padding ratio added around the bounding box when fitting
  static const double _fitPadding = 1.25;

  final TransformationController _transformationController =
      TransformationController();
  // LayoutBuilder から得た実際のビューポートサイズ / The current viewport size, from LayoutBuilder
  Size? _viewportSize;
  // ユーザーが一度でも手動でパン/ズームしたら、以降は自動フィットを止めて操作を尊重する
  // 手動操作を邪魔しないよう、リセットが押されるまで自動フィットは再開しない
  // Once the user manually pans/zooms, auto-fit stops respecting their view;
  // it won't resume until Reset is pressed.
  bool _autoFitEnabled = true;

  @override
  void initState() {
    super.initState();
    // 画面遷移後もフルスクリーン表示を維持する / Keeps fullscreen display across screen transitions
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    widget.service.trajectory.addListener(_fitToTrajectory);
  }

  @override
  void dispose() {
    widget.service.trajectory.removeListener(_fitToTrajectory);
    _transformationController.dispose();
    super.dispose();
  }

  Offset _worldToCanvas(Offset world) {
    return Offset(
      _canvasSize / 2 + world.dx * _pixelsPerMeter,
      _canvasSize / 2 + world.dy * _pixelsPerMeter,
    );
  }

  // 記録済みの軌跡全体が収まるように表示範囲を自動調整する
  // Automatically adjusts the view so the entire recorded trajectory stays in frame
  void _fitToTrajectory() {
    if (!_autoFitEnabled) return;
    final bounds = widget.service.trajectory.bounds;
    final viewportSize = _viewportSize;
    if (bounds == null || viewportSize == null) return;

    final spanX = (bounds.width * _pixelsPerMeter).clamp(
      _minSpanMeters * _pixelsPerMeter,
      double.infinity,
    );
    final spanY = (bounds.height * _pixelsPerMeter).clamp(
      _minSpanMeters * _pixelsPerMeter,
      double.infinity,
    );
    final scaleX = viewportSize.width / (spanX * _fitPadding);
    final scaleY = viewportSize.height / (spanY * _fitPadding);
    final scale = scaleX < scaleY ? scaleX : scaleY;

    final centerWorld = bounds.center;
    final centerCanvas = _worldToCanvas(centerWorld);

    _transformationController.value = Matrix4.identity()
      ..translateByDouble(viewportSize.width / 2, viewportSize.height / 2, 0, 1)
      ..scaleByDouble(scale, scale, scale, 1)
      ..translateByDouble(-centerCanvas.dx, -centerCanvas.dy, 0, 1);
  }

  void _resetTrajectory() {
    widget.service.trajectory.reset();
    // 手動操作の状態も一緒にリセットし、次の走行では自動フィットから再開する
    // Reset the manual-navigation flag too, so the next drive starts back in auto-fit mode
    _autoFitEnabled = true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // テキスト入力を使わない画面なのでキーボード表示時の圧縮は不要
      // No text input on this screen, so keyboard-triggered resizing isn't needed
      resizeToAvoidBottomInset: false,
      body: Stack(
        // Stack はデフォルトで非配置の子(ここではボタン行)のサイズに合わせて自身を
        // 収縮させるため、Positioned.fill の子を画面全体に広げるには expand が必要
        // Stack shrinks to its non-positioned children (here, the button row) by
        // default; expand is required so the Positioned.fill child fills the screen
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                _viewportSize = constraints.biggest;
                return InteractiveViewer(
                  constrained: false,
                  // パン・ピンチズームともに有効にする / Both pan and pinch-zoom are enabled
                  minScale: 0.05,
                  maxScale: 40,
                  boundaryMargin: const EdgeInsets.all(double.infinity),
                  transformationController: _transformationController,
                  // ユーザーが自分で操作したら、以降は自動フィットしない(操作を尊重する)
                  // Once the user interacts manually, stop auto-fitting so their view is respected
                  onInteractionStart: (_) => _autoFitEnabled = false,
                  child: SizedBox(
                    width: _canvasSize,
                    height: _canvasSize,
                    child: CustomPaint(
                      painter: TrajectoryPainter(
                        trajectory: widget.service.trajectory,
                        worldToCanvas: _worldToCanvas,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _OverlayIconButton(
                    icon: Icons.arrow_back,
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  _OverlayIconButton(
                    icon: Icons.refresh,
                    tooltip: 'Reset trajectory',
                    onPressed: _resetTrajectory,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 黒背景でも視認できる半透明の丸型アイコンボタン
// Semi-transparent circular icon button, readable against the black background
class _OverlayIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _OverlayIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white12,
      shape: const CircleBorder(),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}
