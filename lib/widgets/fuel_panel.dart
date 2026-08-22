import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'hud_panel.dart';

const int _fuelSegCount = 20;

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
          final consumptionPct = hasFuelData
              ? (consumption / capacity) * 100
              : 0.0;
          final litSegCount = hasFuelData ? (pct * _fuelSegCount).round() : 0;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ---- vertical gauge：RPMバーと同じブロック意匠、20段の薄いセグメント ----
              // Vertical gauge, styled like the RPM bar: 20 thin stacked block segments
              SizedBox(
                width: 40,
                child: Column(
                  children: [
                    Expanded(
                      child: Column(
                        children: List.generate(_fuelSegCount, (i) {
                          // i=0 が最上段。下から数えた段数がlitCount未満なら点灯
                          // i=0 is the topmost segment; lit when its distance from the
                          // bottom is less than litCount
                          final litFromBottom = _fuelSegCount - 1 - i;
                          final lit = litFromBottom < litSegCount;
                          return Expanded(
                            child: Container(
                              width: double.infinity,
                              margin: const EdgeInsets.symmetric(vertical: 1),
                              decoration: BoxDecoration(
                                color: lit ? fillColor : AppColors.unlitSegment,
                                borderRadius: BorderRadius.circular(2),
                                boxShadow: lit
                                    ? [
                                        BoxShadow(
                                          color: fillColor.withValues(
                                            alpha: 0.5,
                                          ),
                                          blurRadius: 4,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    // const SizedBox(height: 6),
                    // Text(
                    //   hasFuelData ? '${(pct * 100).round()}%' : 'EV',
                    //   style: TextStyle(
                    //     // DSEG7 は文字の造形がないため、EV表示のみ通常フォントのまま
                    //     // DSEG7 has no real letterforms, so keep the 'EV' label in the normal font
                    //     fontFamily: hasFuelData
                    //         ? AppColors.segmentFontFamily
                    //         : null,
                    //     fontSize: 12,
                    //     fontWeight: FontWeight.w700,
                    //     color: AppColors.hudTextSecondary,
                    //     letterSpacing: 0.5,
                    //   ),
                    // ),
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
                    Text(
                      hasFuelData ? '${(pct * 100).round()}%' : '--%',
                      style: const TextStyle(
                        fontFamily: AppColors.segmentFontFamily,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: AppColors.hudTextPrimary,
                        letterSpacing: 1,
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
                              fontFamily: AppColors.segmentFontFamily,
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: lowLaps
                                  ? AppColors.criticalBright
                                  : AppColors.goodBright,
                              letterSpacing: 1,
                            ),
                          ),
                          const TextSpan(
                            text: ' Laps',
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
                        '直近ラップ: ${consumptionPct.toStringAsFixed(1)}%/lap',
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
