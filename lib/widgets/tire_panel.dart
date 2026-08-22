import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'hud_panel.dart';

/// タイヤ温度4輪 + TCS作動インジケーター
/// 4-corner tire temperature readout + TCS intervention badge
class TirePanel extends StatefulWidget {
  final ValueNotifier<double> tireTempFLNotifier;
  final ValueNotifier<double> tireTempFRNotifier;
  final ValueNotifier<double> tireTempRLNotifier;
  final ValueNotifier<double> tireTempRRNotifier;
  final ValueNotifier<bool> tcsActiveNotifier;

  const TirePanel({
    super.key,
    required this.tireTempFLNotifier,
    required this.tireTempFRNotifier,
    required this.tireTempRLNotifier,
    required this.tireTempRRNotifier,
    required this.tcsActiveNotifier,
  });

  @override
  State<TirePanel> createState() => _TirePanelState();
}

class _TirePanelState extends State<TirePanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    widget.tcsActiveNotifier.addListener(_onTcsChange);
  }

  void _onTcsChange() {
    if (widget.tcsActiveNotifier.value) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.value = 0;
    }
  }

  @override
  void dispose() {
    widget.tcsActiveNotifier.removeListener(_onTcsChange);
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HudPanel(
      title: 'Tire Temperature',
      trailing: AnimatedBuilder(
        animation: Listenable.merge([
          widget.tcsActiveNotifier,
          _pulseController,
        ]),
        builder: (context, _) {
          final active = widget.tcsActiveNotifier.value;
          final opacity = active ? 1.0 - _pulseController.value * 0.55 : 1.0;
          return Opacity(
            opacity: opacity,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: active
                    ? AppColors.warning.withValues(alpha: 0.18)
                    : AppColors.surface2,
                border: Border.all(
                  color: active
                      ? AppColors.warning.withValues(alpha: 0.4)
                      : AppColors.hairline,
                ),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'TCS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: active ? AppColors.warning : AppColors.hudTextMuted,
                ),
              ),
            ),
          );
        },
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Expanded(child: _tireTile('FL', widget.tireTempFLNotifier)),
                  const SizedBox(width: 14),
                  Expanded(child: _tireTile('FR', widget.tireTempFRNotifier)),
                ],
              ),
              SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _tireTile('RL', widget.tireTempRLNotifier)),
                  const SizedBox(width: 14),
                  Expanded(child: _tireTile('RR', widget.tireTempRRNotifier)),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Color _tempColor(double temp) {
    if (temp < 70) return AppColors.cold;
    if (temp < 100) return AppColors.goodBright;
    if (temp < 120) return AppColors.warning;
    return AppColors.criticalBright;
  }

  Widget _tireTile(String pos, ValueNotifier<double> tempNotifier) {
    return ValueListenableBuilder<double>(
      valueListenable: tempNotifier,
      builder: (context, temp, _) {
        final color = _tempColor(temp);
        final hot = temp >= 120;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            border: Border.all(color: hot ? color : AppColors.hairline),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                pos,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: AppColors.hudTextMuted,
                ),
              ),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: temp.round().toString(),
                      style: const TextStyle(
                        fontFamily: AppColors.segmentFontFamily,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: AppColors.hudTextPrimary,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
