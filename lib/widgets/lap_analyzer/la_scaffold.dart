import 'package:flutter/material.dart';
import 'package:gt7_trj_log/theme/la_colors.dart';
import 'package:gt7_trj_log/theme/la_dimens.dart';

/// Lap Analyzer画面共通のScaffold(背景色・AppBarの見た目を統一する)。
/// ダッシュボード(HUD)画面はこれを使わず、独自の見た目のまま
/// Shared Scaffold for the Lap Analyzer screens (unifies the background color
/// and AppBar look). The dashboard (HUD) screen doesn't use this and keeps
/// its own distinct look.
class LAScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final Widget? leading;
  final double? leadingWidth;
  final List<Widget>? actions;
  final Widget? drawer;

  const LAScaffold({
    super.key,
    required this.title,
    required this.body,
    this.leading,
    this.leadingWidth,
    this.actions,
    this.drawer,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LAColors.background,
      drawer: drawer,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: LAColors.appBarBackground,
        foregroundColor: LAColors.appBarForeground,
        elevation: LADimens.appBarElevation,
        leading: leading,
        leadingWidth: leadingWidth,
        actions: actions,
      ),
      body: body,
    );
  }
}
