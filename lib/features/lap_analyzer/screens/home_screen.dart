import 'dart:async';
import 'package:flutter/material.dart';
import '../../../screens/telemetry_screen.dart';
import '../../../services/gt7_telemetry_service.dart';
import '../../../widgets/telemetry_drawer_widget.dart';
import '../models/lap_capture.dart';
import '../services/lap_capture_service.dart';
import '../services/lap_log_writer.dart';
import '../services/realtime_diff_service.dart';
import '../services/reference_lap_store.dart';
import 'capture_screen.dart';
import 'offline_compare_screen.dart';
import 'realtime_compare_screen.dart';

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

    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('テレメトリを受信できていません'),
        content: const Text(
          'PS5からのUDPテレメトリが届いていません。IPアドレスや受信開始の状態を確認してください。\n'
          'このまま進んでも、接続が確立するまでラップは記録されません。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('戻る'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('このまま進む'),
          ),
        ],
      ),
    );
    return proceed ?? false;
  }

  Future<void> _openCapture(LapType type) async {
    if (!await _ensureConnected()) return;
    if (!mounted) return;

    final resultNotifier = type == LapType.target
        ? _targetLapNotifier
        : _bestLapNotifier;
    final label = type == LapType.target ? 'ターゲット' : 'ベストラップ';

    if (resultNotifier.value != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('$labelを削除しますか?'),
          content: Text('既存の$labelを削除して、新しく記録し直します。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
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
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('$labelが未読み込みです'),
          content: Text('先に$labelを読み込んでください。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
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
    return Scaffold(
      // 接続設定(IPアドレス・受信開始/停止・Rev Warning)はダッシュボードと共通のDrawerを使う
      // Reuses the same Drawer as the dashboard for connection settings
      // (IP address, start/stop receiving, Rev Warning)
      drawer: TelemetryDrawer(service: widget.telemetryService),
      appBar: AppBar(
        title: const Text('Lap Analyzer'),
        leading: SafeArea(
          child: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.dashboard),
            tooltip: 'Dashboard',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) =>
                    TelemetryScreen(service: widget.telemetryService),
              ),
            ),
          ),
        ],
      ),
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
                  ValueListenableBuilder<LapCapture?>(
                    valueListenable: _targetLapNotifier,
                    builder: (context, target, _) => Text(
                      target == null
                          ? 'ターゲット: 未読み込み'
                          : 'ターゲット: ${_formatLapTime(target.lapTimeMs)}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ValueListenableBuilder<LapCapture?>(
                    valueListenable: _bestLapNotifier,
                    builder: (context, best, _) => Text(
                      best == null
                          ? 'ベスト: 未読み込み'
                          : 'ベスト: ${_formatLapTime(best.lapTimeMs)}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => _openCapture(LapType.target),
                    child: const Text('ターゲット読み込み'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => _openCapture(LapType.best),
                    child: const Text('自分のベストラップ読み込み'),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'リアルタイム差分比較(比較相手を選択)',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<LapCapture?>(
                    valueListenable: _targetLapNotifier,
                    builder: (context, target, _) => _RealtimeCompareButton(
                      label: 'ターゲットと比較',
                      available: target != null,
                      onPressed: () => _openRealtimeCompare(target, 'ターゲット'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ValueListenableBuilder<LapCapture?>(
                    valueListenable: _bestLapNotifier,
                    builder: (context, best, _) => _RealtimeCompareButton(
                      label: 'ベストラップと比較',
                      available: best != null,
                      onPressed: () => _openRealtimeCompare(best, 'ベストラップ'),
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
                          return TextButton(
                            onPressed: canCompare
                                ? () => _openOfflineCompare(target, best)
                                : null,
                            child: const Text('オフライン比較(ターゲット vs ベスト)'),
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

/// データ未読み込み時は非活性の見た目にしつつ、タップは常に受け付けて
/// (未読み込みなら案内ダイアログを出すため)ボタン自体は無効化しない
/// Looks disabled when the data isn't loaded yet, but always accepts taps
/// (so a missing-data tap can show the guidance dialog) — the button itself
/// is never truly disabled.
class _RealtimeCompareButton extends StatelessWidget {
  final String label;
  final bool available;
  final VoidCallback onPressed;

  const _RealtimeCompareButton({
    required this.label,
    required this.available,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: available
          ? null
          : ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade300,
              foregroundColor: Colors.grey.shade600,
              elevation: 0,
            ),
      child: Text(label, textAlign: TextAlign.center),
    );
  }
}
