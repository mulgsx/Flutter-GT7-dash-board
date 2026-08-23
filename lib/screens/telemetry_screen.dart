import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/gt7_telemetry_service.dart';
import '../theme/app_colors.dart';
import '../widgets/telemetry_drawer_widget.dart';
import '../widgets/hud_top_bar.dart';
import '../widgets/fuel_panel.dart';
import '../widgets/tire_panel.dart';
import '../widgets/lap_panel.dart';

class TelemetryScreen extends StatefulWidget {
  // GT7テレメトリサービスを受け取り、画面全体で共有する
  // Accepts the GT7 telemetry service instance shared across this screen
  final GT7TelemetryService service;

  const TelemetryScreen({super.key, required this.service});

  @override
  State<TelemetryScreen> createState() => _TelemetryScreenState();
}

class _TelemetryScreenState extends State<TelemetryScreen> {
  @override
  void initState() {
    super.initState();
    // ダッシュボードはGT7と同じ横向きレイアウト前提なので、表示中だけ横向きに固定する
    // The dashboard is laid out for GT7's landscape orientation, so lock to
    // landscape only while this screen is shown
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    // 他画面は縦横どちらにも対応するので、離れる際は向きの固定を解除する
    // Other screens support both orientations, so release the lock on exit
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    return Scaffold(
      backgroundColor: AppColors.surface0,
      // drawer: 左から開く / endDrawer: 右から開く（現在は左）
      // drawer: slides in from the left / endDrawer: from the right (currently left)
      // Drawer は service を直接受け取り、自分で状態を監視する
      // TelemetryDrawer watches its own state internally
      drawer: TelemetryDrawer(service: service),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              HudTopBar(
                rpmNotifier: service.rpmNotifier,
                gearNotifier: service.gearNotifier,
                revWarningRpmNotifier: service.revWarningRpmNotifier,
                revLimiterRpmNotifier: service.revLimiterRpmNotifier,
                leading: Builder(
                  // 他画面からプッシュされている場合のみ、一番左に戻るボタンを表示する
                  // Shows a back button at the far left, only when pushed from another screen
                  builder: (context) => Navigator.of(context).canPop()
                      ? HudIconButton(
                          icon: Icons.arrow_back,
                          tooltip: 'Back',
                          onTap: () => Navigator.of(context).pop(),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 105,
                      child: FuelPanel(
                        fuelLevelNotifier: service.fuelLevelNotifier,
                        fuelCapacityNotifier: service.fuelCapacityNotifier,
                        lapFuelConsumptionNotifier:
                            service.lapFuelConsumptionNotifier,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 150,
                      child: TirePanel(
                        tireTempFLNotifier: service.tireTempFLNotifier,
                        tireTempFRNotifier: service.tireTempFRNotifier,
                        tireTempRLNotifier: service.tireTempRLNotifier,
                        tireTempRRNotifier: service.tireTempRRNotifier,
                        tcsActiveNotifier: service.tcsActiveNotifier,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 100,
                      child: LapPanel(
                        currentLapNotifier: service.currentLapNotifier,
                        totalLapsNotifier: service.totalLapsNotifier,
                        lastLapTimeNotifier: service.lastLapTimeNotifier,
                        bestLapTimeNotifier: service.bestLapTimeNotifier,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
