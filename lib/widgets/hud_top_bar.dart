import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

const int _segCount = 32;

/// 上部バー：メニューボタン + RPMセグメントバー + ギア表示
/// Top bar: menu button + segmented RPM bar + gear readout
class HudTopBar extends StatefulWidget {
  final ValueNotifier<double> rpmNotifier;
  final ValueNotifier<int> gearNotifier;
  final ValueNotifier<int> revWarningRpmNotifier;
  final ValueNotifier<int> revLimiterRpmNotifier;

  const HudTopBar({
    super.key,
    required this.rpmNotifier,
    required this.gearNotifier,
    required this.revWarningRpmNotifier,
    required this.revLimiterRpmNotifier,
  });

  @override
  State<HudTopBar> createState() => _HudTopBarState();
}

class _HudTopBarState extends State<HudTopBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blinkController;
  bool _blinking = false;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    widget.rpmNotifier.addListener(_onValueChange);
    widget.revWarningRpmNotifier.addListener(_onValueChange);
  }

  void _onValueChange() {
    // revWarningRpm 到達で赤ゾーンへ点滅開始。WarningIndicator と同じしきい値
    // Blink kicks in at revWarningRpm — same threshold the old WarningIndicator used
    final revWarningRpm = widget.revWarningRpmNotifier.value;
    final shouldBlink =
        revWarningRpm > 0 && widget.rpmNotifier.value >= revWarningRpm;
    if (shouldBlink == _blinking) return;
    setState(() => _blinking = shouldBlink);
    if (shouldBlink) {
      _blinkController.repeat(reverse: true);
    } else {
      _blinkController.stop();
      _blinkController.value = 0;
    }
  }

  @override
  void dispose() {
    widget.rpmNotifier.removeListener(_onValueChange);
    widget.revWarningRpmNotifier.removeListener(_onValueChange);
    _blinkController.dispose();
    super.dispose();
  }

  Color _zoneColor(double rpmAtSeg, int warnRpm, int redRpm) {
    if (redRpm > 0 && rpmAtSeg >= redRpm) return AppColors.criticalBright;
    if (warnRpm > 0 && rpmAtSeg >= warnRpm) return AppColors.warning;
    return AppColors.goodBright;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Builder(
            builder: (context) =>
                _MenuButton(onTap: () => Scaffold.of(context).openDrawer()),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: AnimatedBuilder(
              animation: Listenable.merge([
                widget.rpmNotifier,
                widget.revWarningRpmNotifier,
                widget.revLimiterRpmNotifier,
                _blinkController,
              ]),
              builder: (context, _) {
                final rpm = widget.rpmNotifier.value;
                final warnRpm = widget.revWarningRpmNotifier.value;
                final limiterRpm = widget.revLimiterRpmNotifier.value;
                final maxRpm = limiterRpm > 0
                    ? limiterRpm.toDouble()
                    : (warnRpm > 0 ? warnRpm * 1.15 : 9000.0);
                final litCount = ((rpm / maxRpm) * _segCount).round().clamp(
                  0,
                  _segCount,
                );
                final dimOpacity = _blinking
                    ? 1.0 - _blinkController.value * 0.65
                    : 1.0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 26,
                      child: Row(
                        children: List.generate(_segCount, (i) {
                          final lit = i < litCount;
                          final segRpm = ((i + 1) / _segCount) * maxRpm;
                          // 警告RPM到達後はバー全体を赤へ切り替えて一斉に点滅させる
                          // （個々のセグメント位置ではなく、現在のRPMそのもので判定）
                          // Once past the warning RPM, force the whole lit bar to red
                          // and blink it together, rather than coloring per segment position
                          final Color color;
                          if (!lit) {
                            color = AppColors.unlitSegment;
                          } else if (_blinking) {
                            color = AppColors.criticalBright;
                          } else {
                            color = _zoneColor(segRpm, warnRpm, warnRpm);
                          }
                          final applyDim = lit && _blinking;
                          return Expanded(
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: color.withValues(
                                  alpha: applyDim ? dimOpacity : 1.0,
                                ),
                                borderRadius: BorderRadius.circular(3),
                                boxShadow: lit
                                    ? [
                                        BoxShadow(
                                          color: color.withValues(alpha: 0.5),
                                          blurRadius: 6,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    // const SizedBox(height: 4),
                    // Row(
                    //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    //   children: [
                    //     for (final frac in [0.0, 1 / 3, 2 / 3, 1.0])
                    //       Text(
                    //         (maxRpm * frac / 1000).toStringAsFixed(0),
                    //         style: const TextStyle(
                    //           fontSize: 10,
                    //           color: AppColors.hudTextMuted,
                    //         ),
                    //       ),
                    //   ],
                    // ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 14),
          ValueListenableBuilder<int>(
            valueListenable: widget.gearNotifier,
            builder: (context, gear, _) {
              return Container(
                width: 58,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  border: Border.all(color: AppColors.hairline),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  gear == 0 ? 'N' : '$gear',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: AppColors.hudTextPrimary,
                    height: 1,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final VoidCallback onTap;

  const _MenuButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface2,
          border: Border.all(color: AppColors.hairline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.menu,
          color: AppColors.hudTextPrimary,
          size: 20,
        ),
      ),
    );
  }
}
