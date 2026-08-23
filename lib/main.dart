import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'features/lap_analyzer/screens/home_screen.dart';
import 'services/gt7_telemetry_service.dart';

void main() {
  // runApp() より前に SystemChrome を使うため先にバインディングを初期化する
  // Must be called before SystemChrome since runApp() hasn't initialized the binding yet
  WidgetsFlutterBinding.ensureInitialized();

  // バーを透明にしてコンテンツを画面端まで広げる / Make bars transparent to extend content to screen edges
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, // 透明 / transparent
      systemNavigationBarColor: Colors.transparent, // 透明 / transparent
    ),
  );

  // システムバーを非表示にして表示領域を最大化する / Hide system bars to maximize display area
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // 走行中にダッシュボードとして常時表示するため、画面が自動スリープしないようにする
  // Keep the screen awake while the app is running, since it's used as an always-on dashboard
  WakelockPlus.enable();

  // ダッシュボード画面(TelemetryScreen)だけ横向きに固定し、それ以外の画面は
  // 縦向きにも対応させたいので、アプリ全体では向きを固定しない
  // (ダッシュボード側で表示中だけ横向きに固定する)
  // Only the Dashboard screen (TelemetryScreen) needs to stay landscape-locked;
  // other screens should support portrait too, so the orientation isn't
  // fixed app-wide here (TelemetryScreen locks it itself while shown)
  runApp(const Gt7TrjLogApp());
}

class Gt7TrjLogApp extends StatelessWidget {
  const Gt7TrjLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NSGT7',
      // アプリ全体で日本語表示を Noto Sans JP に明示的に固定する
      // Explicitly pins Japanese text app-wide to Noto Sans JP
      // colorSchemeを指定しないとMaterial 3既定の紫系シード色になるため、
      // 白黒基調のLAカラーパレットに合わせて明示的に指定する
      // Without an explicit colorScheme, Material 3 defaults to a purple
      // seed color; set one explicitly to match the black/white LA palette
      theme: ThemeData(
        fontFamily: 'Noto Sans JP',
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.black,
          brightness: Brightness.light,
          primary: Colors.black87,
          onPrimary: Colors.white,
          surface: Colors.white,
          onSurface: Colors.black87,
        ),
      ),
      home: const TelemetryAppScreen(),
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
    return LapAnalyzerHomeScreen(telemetryService: service);
  }
}
