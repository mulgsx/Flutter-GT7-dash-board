import 'package:flutter/material.dart';
import 'package:gt7_trj_log/features/lap_analyzer/models/lap_capture.dart';
import 'package:gt7_trj_log/features/lap_analyzer/widgets/input_trace_chart.dart';
import 'package:gt7_trj_log/theme/la_strings.dart';
import 'package:gt7_trj_log/theme/la_text_styles.dart';
import 'package:gt7_trj_log/widgets/lap_analyzer/la_panel.dart';
import 'package:gt7_trj_log/widgets/lap_analyzer/la_scaffold.dart';

/// ターゲット vs ベストのオフライン比較画面(throttle/brakeを距離軸で並べて表示)
/// Offline target vs best comparison screen (throttle/brake plotted against distance)
class OfflineCompareScreen extends StatelessWidget {
  final LapCapture target;
  final LapCapture best;

  const OfflineCompareScreen({
    super.key,
    required this.target,
    required this.best,
  });

  @override
  Widget build(BuildContext context) {
    return LAScaffold(
      title: LAStrings.offlineCompareTitle,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LAPanel(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Text(
                    LAStrings.targetLoaded(
                      _formatLapTime(target.lapTimeMs),
                    ),
                    style: LATextStyles.value,
                  ),
                  Text(
                    LAStrings.bestLoaded(
                      _formatLapTime(best.lapTimeMs),
                    ),
                    style: LATextStyles.value,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(child: InputTraceChart(target: target, best: best)),
            const SizedBox(height: 8),
            const _Legend(),
          ],
        ),
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
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      children: const [
        _LegendItem(color: Colors.greenAccent, label: LAStrings.targetThrottle),
        _LegendItem(color: Color(0xFF1B5E20), label: LAStrings.bestThrottle),
        _LegendItem(color: Colors.redAccent, label: LAStrings.targetBrake),
        _LegendItem(color: Color(0xFFB71C1C), label: LAStrings.bestBrake),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: LATextStyles.label),
      ],
    );
  }
}
