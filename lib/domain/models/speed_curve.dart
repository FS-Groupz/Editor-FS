import 'dart:math' as math;

/// Represents a single control point on a 2D speed-time curve
class SpeedCurvePoint {
  final double timeRatio; // 0.0 to 1.0 (relative position along clip)
  final double speedMultiplier; // e.g. 0.1x to 50.0x

  const SpeedCurvePoint({
    required this.timeRatio,
    required this.speedMultiplier,
  });

  SpeedCurvePoint copyWith({double? timeRatio, double? speedMultiplier}) {
    return SpeedCurvePoint(
      timeRatio: timeRatio ?? this.timeRatio,
      speedMultiplier: speedMultiplier ?? this.speedMultiplier,
    );
  }

  Map<String, dynamic> toJson() => {
        'timeRatio': timeRatio,
        'speedMultiplier': speedMultiplier,
      };

  factory SpeedCurvePoint.fromJson(Map<String, dynamic> json) => SpeedCurvePoint(
        timeRatio: (json['timeRatio'] as num).toDouble(),
        speedMultiplier: (json['speedMultiplier'] as num).toDouble(),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpeedCurvePoint &&
          runtimeType == other.runtimeType &&
          timeRatio == other.timeRatio &&
          speedMultiplier == other.speedMultiplier;

  @override
  int get hashCode => timeRatio.hashCode ^ speedMultiplier.hashCode;
}

enum SpeedCurvePresetType {
  none,
  montage,
  hero,
  bullet,
  jumpCut,
  flashIn,
  flashOut,
  custom,
}

/// CapCut-style non-linear speed ramping curve
class SpeedCurve {
  final SpeedCurvePresetType type;
  final List<SpeedCurvePoint> points;

  const SpeedCurve({
    required this.type,
    required this.points,
  });

  /// Evaluates the instantaneous speed multiplier at given clip time ratio [t] (0.0 to 1.0)
  double evaluateSpeedAt(double t) {
    if (points.isEmpty) return 1.0;
    if (points.length == 1) return points.first.speedMultiplier;
    final clampedT = t.clamp(0.0, 1.0);

    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      if (clampedT >= p1.timeRatio && clampedT <= p2.timeRatio) {
        final span = p2.timeRatio - p1.timeRatio;
        if (span <= 0.0001) return p2.speedMultiplier;
        final factor = (clampedT - p1.timeRatio) / span;
        return p1.speedMultiplier + factor * (p2.speedMultiplier - p1.speedMultiplier);
      }
    }
    return points.last.speedMultiplier;
  }

  /// Calculates the effective average speed over the entire curve.
  /// Used for calculating the total timeline duration: originalTrimDuration / averageSpeed.
  double get averageSpeed {
    if (points.isEmpty) return 1.0;
    const samples = 40;
    double totalInverseSpeed = 0.0;
    for (int i = 0; i < samples; i++) {
      final t = i / (samples - 1);
      final s = evaluateSpeedAt(t).clamp(0.05, 100.0);
      totalInverseSpeed += (1.0 / s);
    }
    final avgInverse = totalInverseSpeed / samples;
    return math.max(0.1, 1.0 / avgInverse);
  }

  static SpeedCurve montage() => const SpeedCurve(
        type: SpeedCurvePresetType.montage,
        points: [
          SpeedCurvePoint(timeRatio: 0.0, speedMultiplier: 2.5),
          SpeedCurvePoint(timeRatio: 0.25, speedMultiplier: 0.3),
          SpeedCurvePoint(timeRatio: 0.75, speedMultiplier: 0.3),
          SpeedCurvePoint(timeRatio: 1.0, speedMultiplier: 2.5),
        ],
      );

  static SpeedCurve hero() => const SpeedCurve(
        type: SpeedCurvePresetType.hero,
        points: [
          SpeedCurvePoint(timeRatio: 0.0, speedMultiplier: 1.0),
          SpeedCurvePoint(timeRatio: 0.2, speedMultiplier: 3.5),
          SpeedCurvePoint(timeRatio: 0.45, speedMultiplier: 0.2),
          SpeedCurvePoint(timeRatio: 0.75, speedMultiplier: 0.2),
          SpeedCurvePoint(timeRatio: 1.0, speedMultiplier: 1.0),
        ],
      );

  static SpeedCurve bullet() => const SpeedCurve(
        type: SpeedCurvePresetType.bullet,
        points: [
          SpeedCurvePoint(timeRatio: 0.0, speedMultiplier: 4.0),
          SpeedCurvePoint(timeRatio: 0.4, speedMultiplier: 0.2),
          SpeedCurvePoint(timeRatio: 0.6, speedMultiplier: 0.2),
          SpeedCurvePoint(timeRatio: 1.0, speedMultiplier: 4.0),
        ],
      );

  static SpeedCurve jumpCut() => const SpeedCurve(
        type: SpeedCurvePresetType.jumpCut,
        points: [
          SpeedCurvePoint(timeRatio: 0.0, speedMultiplier: 2.5),
          SpeedCurvePoint(timeRatio: 0.25, speedMultiplier: 0.5),
          SpeedCurvePoint(timeRatio: 0.5, speedMultiplier: 2.5),
          SpeedCurvePoint(timeRatio: 0.75, speedMultiplier: 0.5),
          SpeedCurvePoint(timeRatio: 1.0, speedMultiplier: 2.5),
        ],
      );

  static SpeedCurve flashIn() => const SpeedCurve(
        type: SpeedCurvePresetType.flashIn,
        points: [
          SpeedCurvePoint(timeRatio: 0.0, speedMultiplier: 5.0),
          SpeedCurvePoint(timeRatio: 0.3, speedMultiplier: 1.0),
          SpeedCurvePoint(timeRatio: 1.0, speedMultiplier: 1.0),
        ],
      );

  static SpeedCurve flashOut() => const SpeedCurve(
        type: SpeedCurvePresetType.flashOut,
        points: [
          SpeedCurvePoint(timeRatio: 0.0, speedMultiplier: 1.0),
          SpeedCurvePoint(timeRatio: 0.7, speedMultiplier: 1.0),
          SpeedCurvePoint(timeRatio: 1.0, speedMultiplier: 5.0),
        ],
      );

  static SpeedCurve custom([List<SpeedCurvePoint>? points]) => SpeedCurve(
        type: SpeedCurvePresetType.custom,
        points: points ??
            const [
              SpeedCurvePoint(timeRatio: 0.0, speedMultiplier: 1.0),
              SpeedCurvePoint(timeRatio: 0.3, speedMultiplier: 2.5),
              SpeedCurvePoint(timeRatio: 0.7, speedMultiplier: 0.4),
              SpeedCurvePoint(timeRatio: 1.0, speedMultiplier: 1.0),
            ],
      );

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'points': points.map((p) => p.toJson()).toList(),
      };

  factory SpeedCurve.fromJson(Map<String, dynamic> json) {
    final typeName = json['type'] as String? ?? 'custom';
    final type = SpeedCurvePresetType.values.firstWhere(
      (e) => e.name == typeName,
      orElse: () => SpeedCurvePresetType.custom,
    );
    final rawPoints = (json['points'] as List<dynamic>?) ?? [];
    final pts = rawPoints
        .map((p) => SpeedCurvePoint.fromJson(p as Map<String, dynamic>))
        .toList();
    return SpeedCurve(type: type, points: pts);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpeedCurve &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          _listEquals(points, other.points);

  @override
  int get hashCode => type.hashCode ^ points.length.hashCode;

  static bool _listEquals(List<SpeedCurvePoint> a, List<SpeedCurvePoint> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
