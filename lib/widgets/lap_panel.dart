import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'hud_panel.dart';

/// ラップ数・ラップタイムパネル / Lap count + lap time panel
class LapPanel extends StatelessWidget {
  final ValueNotifier<int> currentLapNotifier;
  final ValueNotifier<int> totalLapsNotifier;
  final ValueNotifier<int> lastLapTimeNotifier;
  final ValueNotifier<int> bestLapTimeNotifier;

  const LapPanel({
    super.key,
    required this.currentLapNotifier,
    required this.totalLapsNotifier,
    required this.lastLapTimeNotifier,
    required this.bestLapTimeNotifier,
  });

  static String _formatLapTime(int ms) {
    if (ms < 0) return '--:--.---';
    final m = ms ~/ 60000;
    final s = (ms % 60000) / 1000;
    return '$m:${s.toStringAsFixed(3).padLeft(6, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return HudPanel(
      title: 'Lap',
      child: AnimatedBuilder(
        animation: Listenable.merge([
          currentLapNotifier,
          totalLapsNotifier,
          lastLapTimeNotifier,
          bestLapTimeNotifier,
        ]),
        builder: (context, _) {
          final currentLap = currentLapNotifier.value;
          final totalLaps = totalLapsNotifier.value;

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$currentLap',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppColors.hudTextPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    totalLaps > 0 ? '/ $totalLaps' : '/ ∞',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.hudTextMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _lapTimeRow('LAST LAP', lastLapTimeNotifier.value),
              const SizedBox(height: 12),
              _lapTimeRow(
                'BEST LAP',
                bestLapTimeNotifier.value,
                color: AppColors.goodBright,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _lapTimeRow(String label, int ms, {Color? color}) {
    return Container(
      padding: const EdgeInsets.only(top: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.gridline)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.hudTextMuted),
          ),
          Text(
            _formatLapTime(ms),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color ?? AppColors.hudTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
