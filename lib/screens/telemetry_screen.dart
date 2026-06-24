import 'package:flutter/material.dart';
import '../services/gt7_telemetry_service.dart';
import '../widgets/telemetry_drawer_widget.dart';
import '../widgets/rpm_display_widget.dart';

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
                  drawer: TelemetryDrawer(
                    ipController: service.ipController,
                    isListening: isListening,
                    onStart: () =>
                        service.startListening(service.ipController.text),
                    onStop: service.stopListening,
                    packetCount: count,
                    status: status,
                  ),
                  appBar: AppBar(
                    title: const Text('GT7 Dashboard'),
                    leading: SafeArea(
                      child: Builder(
                        builder: (context) => IconButton(
                          icon: const Icon(Icons.menu),
                          onPressed: () => Scaffold.of(context).openDrawer(),
                        ),
                      ),
                    ),
                  ),
                  body: SafeArea(
                    child: Padding(
                      // ここにコンテンツを追加
                      // add content here
                      padding: const EdgeInsets.all(16.0),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Card(
                              elevation: 2,
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                // RPMを表示
                                // show RPM
                                child: RpmDisplay(
                                  rpmNotifier: service.rpmNotifier,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
