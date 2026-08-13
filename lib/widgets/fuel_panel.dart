import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'hud_panel.dart';

/// 燃料残量 + 残りラップ数パネル / Fuel remaining + laps-remaining panel
class FuelPanel extends StatelessWidget {
  final ValueNotifier<double> fuelLevelNotifier;
  final ValueNotifier<double> fuelCapacityNotifier;
  final ValueNotifier<double> lapFuelConsumptionNotifier;

  const FuelPanel({
    super.key,
    required this.fuelLevelNotifier,
    required this.fuelCapacityNotifier,
    required this.lapFuelConsumptionNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return HudPanel(
      title: 'Fuel / Laps Remaining',
      child: AnimatedBuilder(
        animation: Listenable.merge([
          fuelLevelNotifier,
          fuelCapacityNotifier,
          lapFuelConsumptionNotifier,
        ]),
        builder: (context, _) {
          final level = fuelLevelNotifier.value;
          final capacity = fuelCapacityNotifier.value;
          final consumption = lapFuelConsumptionNotifier.value;
          final hasFuelData = capacity > 0;
          final pct = hasFuelData ? (level / capacity).clamp(0.0, 1.0) : 0.0;

          final Color fillColor;
          if (!hasFuelData) {
            fillColor = AppColors.hudTextMuted;
          } else if (pct < 0.15) {
            fillColor = AppColors.criticalBright;
          } else if (pct < 0.30) {
            fillColor = AppColors.warning;
          } else {
            fillColor = AppColors.cold;
          }

          final lapsRemaining = (hasFuelData && consumption > 0)
              ? (level / consumption).floor()
              : null;
          final lowLaps = hasFuelData && pct < 0.15;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ---- vertical gauge ----
              SizedBox(
                width: 40,
                child: Column(
                  children: [
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.surface2,
                          border: Border.all(color: AppColors.hairline),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: FractionallySizedBox(
                            heightFactor: hasFuelData ? pct : 0.0,
                            widthFactor: 1.0,
                            child: DecoratedBox(
                              decoration: BoxDecoration(color: fillColor),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hasFuelData ? '${(pct * 100).round()}%' : 'EV',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.hudTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // ---- stats ----
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: hasFuelData ? level.toStringAsFixed(1) : '--',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: AppColors.hudTextPrimary,
                            ),
                          ),
                          TextSpan(
                            text: hasFuelData
                                ? ' / ${capacity.toStringAsFixed(0)} L'
                                : '',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.hudTextMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Text(
                      'FUEL REM',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.hudTextMuted,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: lapsRemaining?.toString() ?? '--',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: lowLaps
                                  ? AppColors.criticalBright
                                  : AppColors.goodBright,
                            ),
                          ),
                          const TextSpan(
                            text: ' laps',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.hudTextMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Text(
                      'LAPS REM',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.hudTextMuted,
                      ),
                    ),
                    if (consumption > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        '直近ラップ: ${consumption.toStringAsFixed(1)} L/lap',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.hudTextSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
