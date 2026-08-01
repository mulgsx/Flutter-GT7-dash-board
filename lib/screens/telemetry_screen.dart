import 'package:flutter/material.dart';
import '../services/gt7_telemetry_service.dart';
import '../widgets/telemetry_drawer_widget.dart';
import '../widgets/rpm_display_widget.dart';
import '../widgets/warning_indicator_widget.dart';

class TelemetryScreen extends StatelessWidget {
  // GT7テレメトリサービスを受け取り、画面全体で共有する
  // Accepts the GT7 telemetry service instance shared across this screen
  final GT7TelemetryService service;

  const TelemetryScreen({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // drawer: 左から開く / endDrawer: 右から開く（現在は左）
      // drawer: slides in from the left / endDrawer: from the right (currently left)
      // Drawer は service を直接受け取り、自分で状態を監視する
      // TelemetryDrawer watches its own state internally
      drawer: TelemetryDrawer(service: service),
      appBar: AppBar(
        title: const Text('GT7 Dashboard'),
        leading: SafeArea(
          child: Builder(
            // Scaffold.of(context) は Scaffold より内側の context が必要なため Builder で包む
            // Builder provides a context below the Scaffold so Scaffold.of(context) can find it
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              // ゲージを追加するときはここに _buildGaugeCard(...) を並べていく
              // To add more gauges, append _buildGaugeCard(...) calls here
              children: [
                // RPM
                _buildGaugeCard(
                  child: RpmDisplay(rpmNotifier: service.rpmNotifier),
                ),
                // warning indicator
                Align(
                  alignment: Alignment.centerLeft,
                  child: WarningIndicator(
                    rpmNotifier: service.rpmNotifier,
                    revWarningRpmNotifier: service.revWarningRpmNotifier,
                  ),
                ),
                const SizedBox(height: 12),

                // revWarningRpm
                ValueListenableBuilder<int>(
                  valueListenable: service.revWarningRpmNotifier,
                  builder: (context, revWarningRpm, _) =>
                      Text('Rev Warning RPM: $revWarningRpm'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ゲージを共通のカードレイアウトで包むヘルパー
  // Wraps a gauge widget in a shared card layout
  Widget _buildGaugeCard({required Widget child}) {
    return Card(
      elevation: 2,
      child: Padding(padding: const EdgeInsets.all(16.0), child: child),
    );
  }
}
