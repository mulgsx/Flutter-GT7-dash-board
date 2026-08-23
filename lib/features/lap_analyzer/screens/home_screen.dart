import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gt7_trj_log/features/lap_analyzer/models/lap_capture.dart';
import 'package:gt7_trj_log/features/lap_analyzer/screens/capture_screen.dart';
import 'package:gt7_trj_log/features/lap_analyzer/screens/offline_compare_screen.dart';
import 'package:gt7_trj_log/features/lap_analyzer/screens/realtime_compare_screen.dart';
import 'package:gt7_trj_log/features/lap_analyzer/services/lap_capture_service.dart';
import 'package:gt7_trj_log/features/lap_analyzer/services/lap_log_writer.dart';
import 'package:gt7_trj_log/features/lap_analyzer/services/realtime_diff_service.dart';
import 'package:gt7_trj_log/features/lap_analyzer/services/reference_lap_store.dart';
import 'package:gt7_trj_log/screens/telemetry_screen.dart';
import 'package:gt7_trj_log/services/gt7_telemetry_service.dart';
import 'package:gt7_trj_log/theme/la_strings.dart';
import 'package:gt7_trj_log/theme/la_text_styles.dart';
import 'package:gt7_trj_log/widgets/dialogs/la_confirm_dialog.dart';
import 'package:gt7_trj_log/widgets/lap_analyzer/la_button.dart';
import 'package:gt7_trj_log/widgets/lap_analyzer/la_panel.dart';
import 'package:gt7_trj_log/widgets/lap_analyzer/la_scaffold.dart';
import 'package:gt7_trj_log/widgets/lap_analyzer/la_text_button.dart';
import 'package:gt7_trj_log/widgets/telemetry_drawer_widget.dart';

/// Lap Analyzerのホーム画面。3つのボタン(ターゲット読み込み・ベスト読み込み・
/// リアルタイム差分比較)と、読み込み済みラップタイムの表示のみを持つ
/// Lap Analyzer's home screen: just the three buttons (load target, load
/// best, real-time diff) plus the currently loaded lap times, if any
class LapAnalyzerHomeScreen extends StatefulWidget {
  final GT7TelemetryService telemetryService;

  const LapAnalyzerHomeScreen({super.key, required this.telemetryService});

  @override
  State<LapAnalyzerHomeScreen> createState() => _LapAnalyzerHomeScreenState();
}

class _LapAnalyzerHomeScreenState extends State<LapAnalyzerHomeScreen> {
  late final ReferenceLapStore _referenceLapStore;
  late final LapLogWriter _lapLogWriter;
  late final LapCaptureService _lapCaptureService;
  late final RealtimeDiffService _realtimeDiffService;

  final ValueNotifier<LapCapture?> _targetLapNotifier = ValueNotifier(null);
  final ValueNotifier<LapCapture?> _bestLapNotifier = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    _referenceLapStore = ReferenceLapStore();
    _lapLogWriter = LapLogWriter();
    _realtimeDiffService = RealtimeDiffService();
    _lapCaptureService = LapCaptureService(
      telemetryService: widget.telemetryService,
      onLapCompleted: (lap) {
        unawaited(_lapLogWriter.write(lap));
      },
      onReferenceLapCaptured: (lap) {
        unawaited(_saveReferenceLap(lap));
      },
    );
    unawaited(_loadSavedLaps());
  }

  Future<void> _saveReferenceLap(LapCapture lap) async {
    // 画面表示をディスク書き込み(数千サンプルのJSON化)の完了を待たせず即座に切り替える。
    // 保存自体は裏で継続する
    // Update the UI immediately, without waiting on the disk write (JSON-encoding
    // thousands of samples); the save itself continues in the background
    if (lap.type == LapType.target) {
      _targetLapNotifier.value = lap;
      _realtimeDiffService.setTarget(lap);
    } else if (lap.type == LapType.best) {
      _bestLapNotifier.value = lap;
    }
    await _referenceLapStore.save(lap);
  }

  Future<void> _loadSavedLaps() async {
    final target = await _referenceLapStore.load(LapType.target);
    final best = await _referenceLapStore.load(LapType.best);
    if (!mounted) return;
    _targetLapNotifier.value = target;
    _bestLapNotifier.value = best;
    if (target != null) {
      _realtimeDiffService.setTarget(target);
    }
  }

  @override
  void dispose() {
    _lapCaptureService.dispose();
    _realtimeDiffService.dispose();
    _targetLapNotifier.dispose();
    _bestLapNotifier.dispose();
    super.dispose();
  }

  // UDPでテレメトリを実際に受信できているかを確認し、できていなければ警告ダイアログを出す。
  // trueが返るまで(=受信中、またはユーザーが「続行」を選ぶまで)遷移を行わないようにする
  // Confirms telemetry is actually being received over UDP; if not, shows a warning
  // dialog. Callers should not navigate unless this returns true (receiving, or the
  // user chose to proceed anyway).
  Future<bool> _ensureConnected() async {
    if (widget.telemetryService.statusTypeNotifier.value ==
        StatusType.receiving) {
      return true;
    }

    return LAConfirmDialog.show(
      context,
      title: LAStrings.notReceivingTitle,
      message: LAStrings.notReceivingMessage,
      cancelLabel: LAStrings.back,
      confirmLabel: LAStrings.proceedAnyway,
    );
  }

  Future<void> _openCapture(LapType type) async {
    if (!await _ensureConnected()) return;
    if (!mounted) return;

    final resultNotifier = type == LapType.target
        ? _targetLapNotifier
        : _bestLapNotifier;
    final label = type == LapType.target
        ? LAStrings.target
        : LAStrings.best;

    if (resultNotifier.value != null) {
      final confirmed = await LAConfirmDialog.show(
        context,
        title: LAStrings.deleteConfirmTitle(label),
        message: LAStrings.deleteConfirmMessage(label),
      );
      if (!confirmed) return;
      if (!mounted) return;

      await _referenceLapStore.delete(type);
      resultNotifier.value = null;
      if (type == LapType.target) {
        _realtimeDiffService.clearTarget();
      }
      if (!mounted) return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CaptureScreen(
          lapCaptureService: _lapCaptureService,
          resultNotifier: resultNotifier,
          type: type,
        ),
      ),
    );
  }

  Future<void> _openRealtimeCompare(LapCapture? opponent, String label) async {
    if (opponent == null) {
      await LAConfirmDialog.showInfo(
        context,
        title: LAStrings.notLoadedTitle(label),
        message: LAStrings.notLoadedMessage(label),
      );
      return;
    }

    if (!await _ensureConnected()) return;
    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RealtimeCompareScreen(
          lapCaptureService: _lapCaptureService,
          realtimeDiffService: _realtimeDiffService,
          target: opponent,
          opponentLabel: label,
        ),
      ),
    );
  }

  void _openOfflineCompare(LapCapture target, LapCapture best) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OfflineCompareScreen(target: target, best: best),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return LAScaffold(
      title: LAStrings.homeTitle,
      // 接続設定(IPアドレス・受信開始/停止・Rev Warning)はダッシュボードと共通のDrawerを使う
      // Reuses the same Drawer as the dashboard for connection settings
      // (IP address, start/stop receiving, Rev Warning)
      drawer: TelemetryDrawer(service: widget.telemetryService),
      leadingWidth: 88,
      leading: SafeArea(
        child: Builder(
          builder: (context) => LATextButton(
            label: LAStrings.ipSettings,
            onPressed: () => Scaffold.of(context).openDrawer(),
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ),
      actions: [
        LATextButton(
          label: LAStrings.dashboardScreen,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) =>
                  TelemetryScreen(service: widget.telemetryService),
            ),
          ),
        ),
      ],
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LAPanel(
                    child: Column(
                      children: [
                        ValueListenableBuilder<LapCapture?>(
                          valueListenable: _targetLapNotifier,
                          builder: (context, target, _) => Text(
                            target == null
                                ? LAStrings.targetNotLoaded
                                : LAStrings.targetLoaded(
                                    _formatLapTime(target.lapTimeMs),
                                  ),
                            textAlign: TextAlign.center,
                            style: LATextStyles.value,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ValueListenableBuilder<LapCapture?>(
                          valueListenable: _bestLapNotifier,
                          builder: (context, best, _) => Text(
                            best == null
                                ? LAStrings.bestNotLoaded
                                : LAStrings.bestLoaded(
                                    _formatLapTime(best.lapTimeMs),
                                  ),
                            textAlign: TextAlign.center,
                            style: LATextStyles.value,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  LAButton(
                    label: LAStrings.loadTarget,
                    onPressed: () => _openCapture(LapType.target),
                  ),
                  const SizedBox(height: 12),
                  LAButton(
                    label: LAStrings.loadBest,
                    onPressed: () => _openCapture(LapType.best),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    LAStrings.realtimeCompareSectionLabel,
                    textAlign: TextAlign.center,
                    style: LATextStyles.label,
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<LapCapture?>(
                    valueListenable: _targetLapNotifier,
                    builder: (context, target, _) => LAButton(
                      label: LAStrings.compareWithTarget,
                      looksDisabled: target == null,
                      onPressed: () => _openRealtimeCompare(
                        target,
                        LAStrings.target,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ValueListenableBuilder<LapCapture?>(
                    valueListenable: _bestLapNotifier,
                    builder: (context, best, _) => LAButton(
                      label: LAStrings.compareWithBest,
                      looksDisabled: best == null,
                      onPressed: () =>
                          _openRealtimeCompare(best, LAStrings.best),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ValueListenableBuilder<LapCapture?>(
                    valueListenable: _targetLapNotifier,
                    builder: (context, target, _) {
                      return ValueListenableBuilder<LapCapture?>(
                        valueListenable: _bestLapNotifier,
                        builder: (context, best, _) {
                          final canCompare = target != null && best != null;
                          return LATextButton(
                            label: LAStrings.offlineCompareButton,
                            onPressed: canCompare
                                ? () => _openOfflineCompare(target, best)
                                : null,
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
