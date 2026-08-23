import 'package:flutter/material.dart';
import 'package:gt7_trj_log/theme/la_colors.dart';
import 'package:gt7_trj_log/theme/la_dimens.dart';

/// Lap Analyzer画面共通のカード風パネル(白背景・角丸・薄い影)
/// Shared card-style panel for the Lap Analyzer screens (white background,
/// rounded corners, a subtle shadow)
class LAPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const LAPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: LAColors.panelBackground,
        borderRadius: BorderRadius.circular(LADimens.panelRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
