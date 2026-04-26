import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/gt7_telemetry_service.dart';
import '../widgets/telemetry_drawer_widget.dart';
import '../widgets/retro_widgets.dart';

class RetroDashboardScreen extends StatelessWidget {
  final GT7TelemetryService service;

  const RetroDashboardScreen({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: service.isListeningNotifier,
      builder: (_, isListening, __) => ValueListenableBuilder<int>(
        valueListenable: service.packetCountNotifier,
        builder: (_, count, __) => ValueListenableBuilder<String>(
          valueListenable: service.statusNotifier,
          builder: (_, status, __) => Scaffold(
            backgroundColor: rBg,
            drawer: TelemetryDrawer(
              ipController: service.ipController,
              isListening: isListening,
              onStart: () => service.startListening(service.ipController.text),
              onStop: service.stopListening,
              packetCount: count,
              status: status,
            ),
            body: SafeArea(
              child: Builder(
                builder: (ctx) => GestureDetector(
                  onLongPress: () => Scaffold.of(ctx).openDrawer(),
                  child: ScanlinesOverlay(
                    child: _DashboardData(service: service),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardData extends StatelessWidget {
  final GT7TelemetryService service;

  const _DashboardData({required this.service});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: service.rpmNotifier,
      builder: (_, rpm, __) => ValueListenableBuilder<double>(
        valueListenable: service.speedKmhNotifier,
        builder: (_, speed, __) => ValueListenableBuilder<int>(
          valueListenable: service.gearNotifier,
          builder: (_, gear, __) => ValueListenableBuilder<double>(
            valueListenable: service.gasNotifier,
            builder: (_, gas, __) => ValueListenableBuilder<double>(
              valueListenable: service.brakeNotifier,
              builder: (_, brake, __) => _DashboardLayout(
                rpm: rpm,
                speedKmh: speed,
                gear: gear,
                gas: gas,
                brake: brake,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardLayout extends StatelessWidget {
  final double rpm;
  final double speedKmh;
  final int gear;
  final double gas;
  final double brake;

  const _DashboardLayout({
    required this.rpm,
    required this.speedKmh,
    required this.gear,
    required this.gas,
    required this.brake,
  });

  String get _gearLabel {
    if (gear == 0) return 'N';
    if (gear == 15) return 'R';
    return '$gear';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: rBg,
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          // Tach bar
          Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
            decoration: retroPanelDeco(),
            child: TachBarWidget(rpm: rpm),
          ),
          const SizedBox(height: 8),
          // Middle row
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left: Clock
                Container(
                  width: 148,
                  decoration: retroPanelDeco(),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      RetroClock(),
                      _Divider(),
                      _OdoPlaceholder(),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Center: Speed + Gear
                Expanded(
                  child: Container(
                    decoration: retroPanelDeco(),
                    child: _SpeedPanel(
                      speedKmh: speedKmh.round(),
                      gearLabel: _gearLabel,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Right: Gas + Brake
                Container(
                  width: 148,
                  decoration: retroPanelDeco(),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      BarGaugeWidget(
                        value: gas,
                        label: 'GAS',
                        leftLabel: '0',
                        rightLabel: '100',
                        color: rGreen,
                      ),
                      const _Divider(),
                      BarGaugeWidget(
                        value: brake,
                        label: 'BRAKE',
                        leftLabel: '0',
                        rightLabel: '100',
                        color: rRed,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Warning lights
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: retroPanelDeco(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                WarnLightWidget(label: 'ENGINE', active: false, color: rAmber, icon: Icons.settings),
                WarnLightWidget(label: 'CHARGE', active: false, color: rAmber, icon: Icons.bolt),
                WarnLightWidget(label: 'BRAKE',  active: false, color: rRed,   icon: Icons.stop_circle),
                WarnLightWidget(label: 'OIL',    active: false, color: rRed,   icon: Icons.opacity),
                WarnLightWidget(label: 'FUEL',   active: false, color: rAmber, icon: Icons.local_gas_station),
                WarnLightWidget(label: 'LIGHT',  active: false, color: rCyan,  icon: Icons.lightbulb),
                WarnLightWidget(label: 'DOOR',   active: false, color: rAmber, icon: Icons.sensor_door),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeedPanel extends StatelessWidget {
  final int speedKmh;
  final String gearLabel;

  const _SpeedPanel({required this.speedKmh, required this.gearLabel});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dh = (constraints.maxHeight * 0.5).clamp(40.0, 84.0);
        final dw = dh * 0.55;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const TurnArrowWidget(isLeft: true),
                const SizedBox(width: 14),
                SevenSegDisplay(
                  value: speedKmh,
                  digits: 3,
                  onColor: rCyan,
                  offColor: rCyanDim,
                  digitWidth: dw,
                  digitHeight: dh,
                ),
                const SizedBox(width: 14),
                const TurnArrowWidget(isLeft: false),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'SPEED km/h',
              style: retroText(size: 9, color: rCyan.withValues(alpha: 0.75), spacing: 5, glow: false),
            ),
            const SizedBox(height: 10),
            // Gear indicator
            Container(
              width: 52,
              height: 46,
              decoration: BoxDecoration(
                color: rGreen.withValues(alpha: 0.07),
                border: Border.all(color: rGreen.withValues(alpha: 0.35)),
                borderRadius: BorderRadius.circular(5),
              ),
              alignment: Alignment.center,
              child: Text(
                gearLabel,
                style: GoogleFonts.orbitron(
                  fontSize: 28,
                  color: rGreen,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: rGreen.withValues(alpha: 0.7), blurRadius: 10)],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: rBorder);
}

class _OdoPlaceholder extends StatelessWidget {
  const _OdoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('ODO km', style: retroText(size: 7, color: rDim, glow: false)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF020808),
            border: Border.all(color: rBorder),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            '000000',
            style: GoogleFonts.shareTechMono(
              fontSize: 16,
              color: rGreen,
              letterSpacing: 4,
              shadows: [Shadow(color: rGreen.withValues(alpha: 0.5), blurRadius: 5)],
            ),
          ),
        ),
      ],
    );
  }
}
