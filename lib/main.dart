import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/telemetry_screen.dart';
import 'services/gt7_telemetry_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]).then((_) {
    runApp(const GT7DashboardApp());
  });
}

class GT7DashboardApp extends StatelessWidget {
  const GT7DashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: TelemetryAppScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class TelemetryAppScreen extends StatefulWidget {
  const TelemetryAppScreen({super.key});

  @override
  State<TelemetryAppScreen> createState() => _TelemetryAppScreenState();
}

class _TelemetryAppScreenState extends State<TelemetryAppScreen> {
  late final GT7TelemetryService service;

  @override
  void initState() {
    super.initState();
    service = GT7TelemetryService();
    service.loadSavedIp();
  }

  @override
  void dispose() {
    service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TelemetryScreen(service: service);
  }
}
