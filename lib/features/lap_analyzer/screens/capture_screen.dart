import 'package:flutter/material.dart';
import 'package:gt7_trj_log/features/lap_analyzer/models/lap_capture.dart';
import 'package:gt7_trj_log/features/lap_analyzer/models/telemetry_sample.dart';
import 'package:gt7_trj_log/features/lap_analyzer/services/lap_capture_service.dart';
import 'package:gt7_trj_log/features/lap_analyzer/widgets/capture_progress_painter.dart';
import 'package:gt7_trj_log/theme/la_icons.dart';
import 'package:gt7_trj_log/theme/la_strings.dart';
import 'package:gt7_trj_log/theme/la_text_styles.dart';
import 'package:gt7_trj_log/widgets/dialogs/la_confirm_dialog.dart';
import 'package:gt7_trj_log/widgets/lap_analyzer/la_button.dart';
import 'package:gt7_trj_log/widgets/lap_analyzer/la_panel.dart';
import 'package:gt7_trj_log/widgets/lap_analyzer/la_scaffold.dart';
import 'package:gt7_trj_log/widgets/lap_analyzer/la_secondary_button.dart';

/// ターゲット/ベストラップ読み込み共通画面。次のラップ境界から1周分をキャプチャし、
/// 完了したら「記録できました」表示に切り替える(自動では戻らない)
/// Shared target/best lap capture screen. Captures one full lap starting at
/// the next lap boundary, then switches to a "recorded" state (does not auto-navigate back)
class CaptureScreen extends StatefulWidget {
  final LapCaptureService lapCaptureService;
  final ValueNotifier<LapCapture?> resultNotifier;
  final LapType type;

  const CaptureScreen({
    super.key,
    required this.lapCaptureService,
    required this.resultNotifier,
    required this.type,
  });

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  LapCapture? _initialValue;
  LapCapture? _completedLap;

  @override
  void initState() {
    super.initState();
    _initialValue = widget.resultNotifier.value;
    widget.resultNotifier.addListener(_onResultChanged);
    widget.lapCaptureService.requestCapture(widget.type);
  }

  void _onResultChanged() {
    if (!identical(widget.resultNotifier.value, _initialValue) && mounted) {
      setState(() => _completedLap = widget.resultNotifier.value);
    }
  }

  void _retryCapture() {
    setState(() {
      // 次に完了を検知できるよう、直前の値を新しい基準点にしてから再要求する
      // Re-baseline against the value just captured so the next completion is detected
      _initialValue = widget.resultNotifier.value;
      _completedLap = null;
    });
    widget.lapCaptureService.requestCapture(widget.type);
  }

  @override
  void dispose() {
    widget.resultNotifier.removeListener(_onResultChanged);
    // 完了前に画面を離れた場合は、キャプチャ待機を取り消す
    // Cancels the pending capture if the user navigates away before it completes
    widget.lapCaptureService.cancelCapture();
    super.dispose();
  }

  String _formatLapTime(int ms) {
    if (ms < 0) return '--:--.---';
    final duration = Duration(milliseconds: ms);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    final millis = duration.inMilliseconds % 1000;
    return "$minutes'${seconds.toString().padLeft(2, '0')}."
        "${millis.toString().padLeft(3, '0')}";
  }

  Future<bool> _confirmDiscardRecording() {
    return LAConfirmDialog.show(
      context,
      title: LAStrings.discardRecordingTitle,
      message: LAStrings.discardRecordingMessage,
      cancelLabel: LAStrings.continueRecording,
      confirmLabel: LAStrings.back,
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.type == LapType.target
        ? LAStrings.target
        : LAStrings.best;
    final completed = _completedLap;
    return ValueListenableBuilder<bool>(
      valueListenable: widget.lapCaptureService.isArmedRecordingNotifier,
      builder: (context, armed, child) {
        // 記録中(軌跡が赤色の時)に戻ろうとした場合のみ確認ダイアログを出す
        // Only warn on back navigation while actively recording (red trajectory)
        final blockBack = completed == null && armed;
        return PopScope(
          canPop: !blockBack,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            final shouldLeave = await _confirmDiscardRecording();
            if (shouldLeave && context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: child!,
        );
      },
      child: LAScaffold(
        title: LAStrings.captureTitle(label),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LAPanel(
                  child: completed == null
                      ? ValueListenableBuilder<bool>(
                          valueListenable:
                              widget.lapCaptureService.isArmedRecordingNotifier,
                          builder: (context, armed, _) => Text(
                            armed
                                ? LAStrings.recordingArmedInstruction(
                                    label,
                                  )
                                : LAStrings.waitingForLapStart,
                            textAlign: TextAlign.center,
                            style: LATextStyles.heading,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              LAIcons.success,
                              color: Colors.greenAccent,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              LAStrings.recordedResult(
                                label,
                                _formatLapTime(completed.lapTimeMs),
                              ),
                              textAlign: TextAlign.center,
                              style: LATextStyles.heading,
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 16),
                // 計測中(または確定済み)の軌跡を描画し、どれだけ読めているか可視化する
                // Draws the in-progress (or completed) trajectory, to show how much was captured
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: completed != null
                        ? CustomPaint(
                            size: Size.infinite,
                            painter: CaptureProgressPainter(
                              samplesProvider: () => completed.samples,
                            ),
                          )
                        : ValueListenableBuilder<bool>(
                            valueListenable:
                                widget.lapCaptureService.isArmedRecordingNotifier,
                            builder: (context, armed, _) {
                              return ValueListenableBuilder<bool>(
                                valueListenable: widget
                                    .lapCaptureService
                                    .wasLastSegmentDiscardedNotifier,
                                builder: (context, discarded, _) {
                                  return ValueListenableBuilder<TelemetrySample?>(
                                    valueListenable: widget
                                        .lapCaptureService
                                        .currentSampleNotifier,
                                    builder: (context, sample, _) {
                                      if (sample == null) {
                                        return const Center(
                                          child: CircularProgressIndicator(),
                                        );
                                      }
                                      // アーム前は「たまたま今走っている途中のラップ」なので、
                                      // キャプチャ対象と混同しないよう控えめな色で表示する。
                                      // 直前の区間が破棄された直後は、armedでも一瞬白で
                                      // 「無効化された」ことを示す
                                      // Before arming this is just whatever lap happens to
                                      // be in progress, so it's drawn in a muted color to
                                      // avoid confusion with the lap that will actually be
                                      // captured. Right after the previous segment was
                                      // discarded, briefly show white (even while armed) to
                                      // signal the invalidation.
                                      final color = discarded
                                          ? Colors.white
                                          : (armed
                                                ? Colors.redAccent
                                                : Colors.white24);
                                      return CustomPaint(
                                        size: Size.infinite,
                                        painter: CaptureProgressPainter(
                                          repaint: widget
                                              .lapCaptureService
                                              .currentSampleNotifier,
                                          samplesProvider: () => widget
                                              .lapCaptureService
                                              .currentLapSamples,
                                          color: color,
                                        ),
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                if (completed == null)
                  ValueListenableBuilder<bool>(
                    valueListenable:
                        widget.lapCaptureService.isArmedRecordingNotifier,
                    builder: (context, armed, _) {
                      return ValueListenableBuilder<TelemetrySample?>(
                        valueListenable:
                            widget.lapCaptureService.currentSampleNotifier,
                        builder: (context, sample, _) {
                          final count =
                              widget.lapCaptureService.currentLapSamples.length;
                          final distanceM = sample?.distanceM ?? 0;
                          final elapsedSec = (sample?.elapsedMs ?? 0) / 1000;
                          final label = armed
                              ? LAStrings.recordingLabel
                              : LAStrings.monitoringLabel;
                          return Text(
                            LAStrings.recordingProgress(
                              label,
                              count,
                              distanceM.toStringAsFixed(0),
                              elapsedSec.toStringAsFixed(1),
                            ),
                            textAlign: TextAlign.center,
                            style: LATextStyles.value,
                          );
                        },
                      );
                    },
                  )
                else ...[
                  Text(
                    LAStrings.recordingComplete(
                      completed.samples.length,
                      completed.samples.isEmpty
                          ? '0'
                          : completed.samples.last.distanceM.toStringAsFixed(0),
                    ),
                    textAlign: TextAlign.center,
                    style: LATextStyles.value,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: LASecondaryButton(
                          label: LAStrings.retryCapture,
                          onPressed: _retryCapture,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: LAButton(
                          label: LAStrings.returnHome,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
