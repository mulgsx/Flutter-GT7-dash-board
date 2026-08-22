import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'lcd_grid_texture.dart';

const int _segCount = 32;

/// 上部バー：(任意の)戻るボタン + RPMセグメントバー + ギア表示
/// Top bar: an optional back button + segmented RPM bar + gear readout
class HudTopBar extends StatefulWidget {
  final ValueNotifier<double> rpmNotifier;
  final ValueNotifier<int> gearNotifier;
  final ValueNotifier<int> revWarningRpmNotifier;
  final ValueNotifier<int> revLimiterRpmNotifier;
  // 一番左に配置する戻るボタンなど / A leading widget (e.g. a back button), placed at the far left
  final Widget? leading;

  const HudTopBar({
    super.key,
    required this.rpmNotifier,
    required this.gearNotifier,
    required this.revWarningRpmNotifier,
    required this.revLimiterRpmNotifier,
    this.leading,
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
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface1,
        border: Border.all(color: AppColors.bezel),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: LcdGridTexture()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Row(
      children: [
        if (widget.leading != null) ...[
          widget.leading!,
          const SizedBox(width: 14),
        ],
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
              // 三角波の中間点で赤⇔unlitSegmentを瞬時に切り替える（フェードさせない）
              // Flip red⇔unlitSegment instantly at the triangle wave's midpoint — no fade
              final blinkShowsRed = _blinkController.value >= 0.5;

              return SizedBox(
                height: 45,
                child: Row(
                  children: List.generate(_segCount, (i) {
                    final lit = i < litCount;
                    final segRpm = ((i + 1) / _segCount) * maxRpm;
                    // 警告RPM到達後はバー全体を赤へ切り替えて一斉に点滅させる
                    // （個々のセグメント位置ではなく、現在のRPMそのもので判定）
                    // Once past the warning RPM, force the whole lit bar to red
                    // and blink it together, rather than coloring per segment position
                    final Color color;
                    final bool showGlow;
                    if (!lit) {
                      color = AppColors.unlitSegment;
                      showGlow = false;
                    } else if (_blinking) {
                      color = blinkShowsRed
                          ? AppColors.critical
                          : AppColors.unlitSegment;
                      showGlow = blinkShowsRed;
                    } else {
                      color = _zoneColor(segRpm, warnRpm, warnRpm);
                      showGlow = true;
                    }
                    return Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: showGlow
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
                style: TextStyle(
                  // DSEG7 は文字の造形がないため、N（ニュートラル）表示のみ通常フォントのまま
                  // DSEG7 has no real letterforms, so keep the 'N' (neutral) label in the normal font
                  fontFamily: gear == 0 ? null : AppColors.segmentFontFamily,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppColors.hudTextPrimary,
                  height: 1,
                  letterSpacing: 1,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// HUD上部バー共通の角丸square アイコンボタン(メニュー・戻る・Track Mapなどで共用)
/// Shared square icon button for the HUD top bar (menu, back, Track Map, etc.)
class HudIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  const HudIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final button = InkWell(
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
        child: Icon(icon, color: AppColors.hudTextPrimary, size: 20),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
