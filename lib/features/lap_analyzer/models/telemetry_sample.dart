/// ラップ内の1サンプル分の時系列データ点
/// A single time-series data point within a lap
class TelemetrySample {
  final int elapsedMs; // ラップ開始からの経過時間 / Time since lap start
  final double distanceM; // ラップ開始からの走行距離（積算） / Cumulative distance since lap start
  final double speedKmh;
  final double throttle; // 0.0〜1.0
  final double brake; // 0.0〜1.0
  // GT7 UDPに生のステアリング角フィールドは見つかっていないため常にnull
  // No raw steering angle field has been found in the GT7 UDP packet, so this is always null
  final double? steering;
  final double posX;
  final double posY;
  final double posZ;

  const TelemetrySample({
    required this.elapsedMs,
    required this.distanceM,
    required this.speedKmh,
    required this.throttle,
    required this.brake,
    required this.steering,
    required this.posX,
    required this.posY,
    required this.posZ,
  });

  Map<String, dynamic> toJson() => {
    'elapsedMs': elapsedMs,
    'distanceM': distanceM,
    'speedKmh': speedKmh,
    'throttle': throttle,
    'brake': brake,
    'steering': steering,
    'posX': posX,
    'posY': posY,
    'posZ': posZ,
  };

  factory TelemetrySample.fromJson(Map<String, dynamic> json) {
    return TelemetrySample(
      elapsedMs: json['elapsedMs'] as int,
      distanceM: (json['distanceM'] as num).toDouble(),
      speedKmh: (json['speedKmh'] as num).toDouble(),
      throttle: (json['throttle'] as num).toDouble(),
      brake: (json['brake'] as num).toDouble(),
      steering: (json['steering'] as num?)?.toDouble(),
      posX: (json['posX'] as num).toDouble(),
      posY: (json['posY'] as num).toDouble(),
      posZ: (json['posZ'] as num).toDouble(),
    );
  }
}
