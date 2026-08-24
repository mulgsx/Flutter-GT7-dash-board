import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import '../models/lap_capture.dart';
import '../models/telemetry_sample.dart';

/// 確定した全ラップ(種別を問わず)を、間引いたCSV形式で1つのログファイルに
/// 追記していく。ファイルはDownload/GT7LapAnalyzer/に置かれ、ファイルアプリから
/// そのまま見える(特別な権限は不要)
/// Appends every completed lap (any type), as downsampled CSV, into a single
/// growing log file under Download/GT7LapAnalyzer/ — visible directly from any
/// file manager app, with no special storage permission required.
class LapLogWriter {
  // 出力するサンプル間隔の目安(60Hzのままだと1周で数千行になるため間引く)
  // Target sample interval for the output (thinned so a lap isn't thousands of lines at 60Hz)
  static const int _sampleIntervalMs = 200;

  static const _channel = MethodChannel('gt7_trj_log/downloads_log');
  static const _folderName = 'GT7LapAnalyzer';
  static const _fileName = 'gt7_lap_log.txt';

  Future<void> write(LapCapture lap) async {
    // このMethodChannelはMainActivity.kt側(Android専用)にしか実装がなく、
    // iOSで呼ぶと対応するネイティブハンドラが存在せず例外になる
    // This MethodChannel is only implemented on the Android side
    // (MainActivity.kt) — calling it on iOS has no native handler and throws
    if (!Platform.isAndroid) return;

    await _channel.invokeMethod<void>('appendToDownloadsLog', {
      'folderName': _folderName,
      'fileName': _fileName,
      'text': _render(lap),
    });
  }

  String _render(LapCapture lap) {
    final buffer = StringBuffer();
    buffer.writeln('---');
    buffer.writeln('TYPE: ${lap.type.label}');
    buffer.writeln('START_TIME: ${lap.startTime.toIso8601String()}');
    buffer.writeln(
      'START_SPEED_KMH: ${lap.startSpeedKmh.toStringAsFixed(1)}',
    );
    buffer.writeln('LAP_TIME_MS: ${lap.lapTimeMs}');
    buffer.writeln(
      'elapsed_ms,distance_m,speed_kmh,throttle,brake,steering,pos_x,pos_y,pos_z,gear',
    );
    for (final sample in _thinned(lap.samples)) {
      buffer.writeln(_csvRow(sample));
    }
    return buffer.toString();
  }

  List<TelemetrySample> _thinned(List<TelemetrySample> samples) {
    if (samples.isEmpty) return samples;
    final result = <TelemetrySample>[samples.first];
    var lastKeptMs = samples.first.elapsedMs;
    for (final sample in samples.skip(1)) {
      if (sample.elapsedMs - lastKeptMs >= _sampleIntervalMs) {
        result.add(sample);
        lastKeptMs = sample.elapsedMs;
      }
    }
    if (result.last != samples.last) {
      result.add(samples.last);
    }
    return result;
  }

  String _csvRow(TelemetrySample sample) {
    final steering = sample.steering == null
        ? ''
        : sample.steering!.toStringAsFixed(2);
    return [
      sample.elapsedMs,
      sample.distanceM.toStringAsFixed(1),
      sample.speedKmh.toStringAsFixed(1),
      sample.throttle.toStringAsFixed(2),
      sample.brake.toStringAsFixed(2),
      steering,
      sample.posX.toStringAsFixed(1),
      sample.posY.toStringAsFixed(1),
      sample.posZ.toStringAsFixed(1),
      sample.gear,
    ].join(',');
  }
}
