import 'telemetry_sample.dart';

enum LapType { target, best, practice }

extension LapTypeLabel on LapType {
  String get label => switch (this) {
    LapType.target => 'TARGET',
    LapType.best => 'BEST',
    LapType.practice => 'PRACTICE',
  };

  static LapType fromLabel(String label) => switch (label) {
    'TARGET' => LapType.target,
    'BEST' => LapType.best,
    _ => LapType.practice,
  };
}

/// 1周分のラップデータ（種別・開始時刻・開始速度・サンプル列）
/// A single completed lap's data (type, start time, start speed, sample series)
class LapCapture {
  final LapType type;
  final DateTime startTime;
  final double startSpeedKmh; // ラップ開始（周回境界通過）時点の速度 / Speed at the lap boundary crossing
  final int lapTimeMs;
  final List<TelemetrySample> samples;

  const LapCapture({
    required this.type,
    required this.startTime,
    required this.startSpeedKmh,
    required this.lapTimeMs,
    required this.samples,
  });

  Map<String, dynamic> toJson() => {
    'type': type.label,
    'startTime': startTime.toIso8601String(),
    'startSpeedKmh': startSpeedKmh,
    'lapTimeMs': lapTimeMs,
    'samples': samples.map((s) => s.toJson()).toList(),
  };

  factory LapCapture.fromJson(Map<String, dynamic> json) {
    return LapCapture(
      type: LapTypeLabel.fromLabel(json['type'] as String),
      startTime: DateTime.parse(json['startTime'] as String),
      startSpeedKmh: (json['startSpeedKmh'] as num).toDouble(),
      lapTimeMs: json['lapTimeMs'] as int,
      samples: (json['samples'] as List)
          .map((s) => TelemetrySample.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}
