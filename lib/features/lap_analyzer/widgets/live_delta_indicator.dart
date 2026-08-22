import 'package:flutter/material.dart';
import '../services/realtime_diff_service.dart';

/// リアルタイム差分比較の各指標をまとめて表示するウィジェット
/// Displays all of the real-time comparison metrics together
class LiveDeltaIndicator extends StatelessWidget {
  final RealtimeDiffService service;

  const LiveDeltaIndicator({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ValueListenableBuilder<double?>(
          valueListenable: service.deltaSecondsNotifier,
          builder: (context, delta, _) => _DeltaTimeDisplay(deltaSeconds: delta),
        ),
        const SizedBox(height: 16),
        ValueListenableBuilder<double?>(
          valueListenable: service.brakingPointDeltaMetersNotifier,
          builder: (context, delta, _) => _MetricRow(
            label: 'ブレーキング地点差',
            value: delta,
            unit: 'm',
            positiveIsGood: false, // 正=奥まで我慢=良い方向として色は反転させる
            invertColor: true,
          ),
        ),
        ValueListenableBuilder<double?>(
          valueListenable: service.throttlePointDeltaMetersNotifier,
          builder: (context, delta, _) => _MetricRow(
            label: 'アクセル開始地点差',
            value: delta,
            unit: 'm',
            positiveIsGood: false,
          ),
        ),
        ValueListenableBuilder<double?>(
          valueListenable: service.cornerEntrySpeedDeltaKmhNotifier,
          builder: (context, delta, _) => _MetricRow(
            label: 'コーナー進入速度差',
            value: delta,
            unit: 'km/h',
            positiveIsGood: true,
          ),
        ),
        ValueListenableBuilder<double?>(
          valueListenable: service.topSpeedDeltaKmhNotifier,
          builder: (context, delta, _) => _MetricRow(
            label: '区間最高速度差',
            value: delta,
            unit: 'km/h',
            positiveIsGood: true,
          ),
        ),
        ValueListenableBuilder<double?>(
          valueListenable: service.lineOffsetMetersNotifier,
          builder: (context, offset, _) => _MetricRow(
            label: 'ライン横ズレ',
            value: offset,
            unit: 'm',
            positiveIsGood: null, // 単なるズレ量なので色分けしない
          ),
        ),
      ],
    );
  }
}

class _DeltaTimeDisplay extends StatelessWidget {
  final double? deltaSeconds;

  const _DeltaTimeDisplay({required this.deltaSeconds});

  @override
  Widget build(BuildContext context) {
    final delta = deltaSeconds;
    final color = delta == null
        ? Colors.grey
        : (delta <= 0 ? Colors.greenAccent : Colors.redAccent);
    final text = delta == null
        ? '--.---'
        : '${delta <= 0 ? '-' : '+'}${delta.abs().toStringAsFixed(3)}';
    return Center(
      child: Text(
        text,
        style: TextStyle(
          fontSize: 56,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final double? value;
  final String unit;
  // true: 正の値が良い(緑) / false: 正の値が悪い(赤) / null: 色分けしない
  // true: positive is good (green) / false: positive is bad (red) / null: no color coding
  final bool? positiveIsGood;
  final bool invertColor;

  const _MetricRow({
    required this.label,
    required this.value,
    required this.unit,
    required this.positiveIsGood,
    this.invertColor = false,
  });

  @override
  Widget build(BuildContext context) {
    Color? color;
    if (value != null && positiveIsGood != null) {
      final isPositive = value! >= 0;
      final isGood = invertColor
          ? (isPositive != positiveIsGood!)
          : (isPositive == positiveIsGood!);
      color = isGood ? Colors.greenAccent : Colors.redAccent;
    }

    final text = value == null
        ? '--'
        : '${value! >= 0 ? '+' : ''}${value!.toStringAsFixed(1)} $unit';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            text,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
