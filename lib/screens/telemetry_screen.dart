import 'package:flutter/material.dart';
import '../services/gt7_telemetry_service.dart';
import '../widgets/telemetry_drawer_widget.dart';
import '../widgets/octopus_tachometer_widget.dart';

class TelemetryScreen extends StatelessWidget {
  final GT7TelemetryService service;

  const TelemetryScreen({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: service.isListeningNotifier,
      builder: (context, isListening, _) {
        return ValueListenableBuilder<int>(
          valueListenable: service.packetCountNotifier,
          builder: (context, count, _) {
            return ValueListenableBuilder<String>(
              valueListenable: service.statusNotifier,
              builder: (context, status, _) {
                return Scaffold(
                  backgroundColor: const Color(0xFF05080F),
                  drawer: TelemetryDrawer(
                    ipController: service.ipController,
                    isListening: isListening,
                    onStart: () =>
                        service.startListening(service.ipController.text),
                    onStop: service.stopListening,
                    packetCount: count,
                    status: status,
                  ),
                  // Floating menu button — doesn't push the tachometer down
                  body: Stack(
                    children: [
                      OctopusTachometer(rpmNotifier: service.rpmNotifier),
                      SafeArea(
                        child: Builder(
                          builder: (context) => IconButton(
                            icon: const Icon(Icons.menu,
                                color: Color(0xFF2D4D70)),
                            onPressed: () =>
                                Scaffold.of(context).openDrawer(),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
