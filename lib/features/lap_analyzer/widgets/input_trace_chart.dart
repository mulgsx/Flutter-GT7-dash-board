import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/lap_capture.dart';
import '../models/telemetry_sample.dart';

/// ターゲット・ベストのthrottle/brakeを距離軸で並べて表示するチャート
/// Chart comparing target/best throttle and brake traces against distance
class InputTraceChart extends StatelessWidget {
  final LapCapture target;
  final LapCapture best;

  const InputTraceChart({super.key, required this.target, required this.best});

  @override
  Widget build(BuildContext context) {
    // 高さは親(Expanded)に委ねる。固定値にすると画面より小さい端末でオーバー
    // フローし、大きい画面では余白ができるだけで無駄になる
    // Height is left to the parent (Expanded). A fixed value would overflow
    // on screens smaller than it, and just waste space on larger ones.
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 1,
        gridData: const FlGridData(show: true),
        titlesData: const FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 32),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 28),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          _series(target, (s) => s.throttle, Colors.greenAccent),
          _series(best, (s) => s.throttle, Colors.green.shade900),
          _series(target, (s) => s.brake, Colors.redAccent),
          _series(best, (s) => s.brake, Colors.red.shade900),
        ],
      ),
    );
  }

  LineChartBarData _series(
    LapCapture lap,
    double Function(TelemetrySample sample) value,
    Color color,
  ) {
    return LineChartBarData(
      spots: lap.samples
          .map((s) => FlSpot(s.distanceM, value(s)))
          .toList(growable: false),
      color: color,
      barWidth: 2,
      dotData: const FlDotData(show: false),
      isCurved: false,
    );
  }
}
