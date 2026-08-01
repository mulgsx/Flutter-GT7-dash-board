import 'package:flutter/material.dart';

/// Rev Warning RPM を超えている間だけ赤く点滅する警告インジケーター
/// 普段（未到達時）は非活性色のまま / Blinks red only while RPM is at/above the rev warning
/// threshold; shows an inactive color otherwise
class WarningIndicator extends StatefulWidget {
  final ValueNotifier<double> rpmNotifier;
  final ValueNotifier<int> revWarningRpmNotifier;

  const WarningIndicator({
    super.key,
    required this.rpmNotifier,
    required this.revWarningRpmNotifier,
  });

  @override
  State<WarningIndicator> createState() => _WarningIndicatorState();
}

class _WarningIndicatorState extends State<WarningIndicator>
    with SingleTickerProviderStateMixin {
  static final Color _inactiveColor = Colors.grey.shade800;

  late final AnimationController _blinkController;
  bool _isWarning = false;

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
    final revWarningRpm = widget.revWarningRpmNotifier.value;
    // 未設定（0以下）の間は警告扱いにしない / Never warn while no threshold (<= 0) has been set
    final isWarning =
        revWarningRpm > 0 && widget.rpmNotifier.value >= revWarningRpm;
    if (isWarning == _isWarning) return;

    setState(() => _isWarning = isWarning);
    if (isWarning) {
      _blinkController.repeat(reverse: true);
    } else {
      _blinkController.stop();
      // 非活性色に確実に戻す / Snap back to the inactive color
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _blinkController,
      builder: (context, _) {
        final color = Color.lerp(
          _inactiveColor,
          Colors.redAccent,
          _blinkController.value,
        )!;
        return Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        );
      },
    );
  }
}
