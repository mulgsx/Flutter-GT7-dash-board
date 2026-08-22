import 'package:flutter/material.dart';
import '../models/lap_capture.dart';
import '../widgets/input_trace_chart.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('オフライン比較')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text('ターゲット: ${_formatLapTime(target.lapTimeMs)}'),
                Text('ベスト: ${_formatLapTime(best.lapTimeMs)}'),
              ],
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
        _LegendItem(color: Colors.greenAccent, label: 'ターゲット throttle'),
        _LegendItem(color: Color(0xFF1B5E20), label: 'ベスト throttle'),
        _LegendItem(color: Colors.redAccent, label: 'ターゲット brake'),
        _LegendItem(color: Color(0xFFB71C1C), label: 'ベスト brake'),
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
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
