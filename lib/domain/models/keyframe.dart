import 'dart:math' as math;
import 'dart:ui' as ui;

/// Easing interpolation curves for keyframe transitions
enum KeyframeCurve {
  linear('Linear'),
  easeInOut('Ease In-Out'),
  easeIn('Ease In'),
  easeOut('Ease Out');

  final String label;
  const KeyframeCurve(this.label);

  /// Evaluates the normalized curve progression [0.0, 1.0]
  double evaluate(double t) {
    final clampedT = t.clamp(0.0, 1.0);
    switch (this) {
      case KeyframeCurve.linear:
        return clampedT;
      case KeyframeCurve.easeInOut:
        // Smooth cubic ease-in-out curve
        return clampedT < 0.5
            ? 4.0 * clampedT * clampedT * clampedT
            : 1.0 - math.pow(-2.0 * clampedT + 2.0, 3) / 2.0;
      case KeyframeCurve.easeIn:
        return clampedT * clampedT * clampedT;
      case KeyframeCurve.easeOut:
        return 1.0 - math.pow(1.0 - clampedT, 3).toDouble();
    }
  }
}

/// Represents a single keyframe point on a clip's timeline
class VideoKeyframe {
  final String id;
  final Duration timestamp; // Offset relative to clip start
  final double scale; // 0.1 to 5.0
  final double rotationDegrees; // -360 to 360
  final double positionX; // Pan X in pixels
  final double positionY; // Pan Y in pixels
  final double opacity; // 0.0 to 1.0
  final KeyframeCurve curve;

  const VideoKeyframe({
    required this.id,
    required this.timestamp,
    this.scale = 1.0,
    this.rotationDegrees = 0.0,
    this.positionX = 0.0,
    this.positionY = 0.0,
    this.opacity = 1.0,
    this.curve = KeyframeCurve.easeInOut,
  });

  double get timeInSeconds => timestamp.inMilliseconds / 1000.0;

  VideoKeyframe copyWith({
    String? id,
    Duration? timestamp,
    double? scale,
    double? rotationDegrees,
    double? positionX,
    double? positionY,
    double? opacity,
    KeyframeCurve? curve,
  }) {
    return VideoKeyframe(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      scale: scale ?? this.scale,
      rotationDegrees: rotationDegrees ?? this.rotationDegrees,
      positionX: positionX ?? this.positionX,
      positionY: positionY ?? this.positionY,
      opacity: opacity ?? this.opacity,
      curve: curve ?? this.curve,
    );
  }

  /// Linearly/cubically interpolates between two adjacent keyframes
  static VideoKeyframe interpolate(
    VideoKeyframe k1,
    VideoKeyframe k2,
    double currentClipTime,
  ) {
    final diff = k2.timeInSeconds - k1.timeInSeconds;
    final rawT = diff <= 0.0001 ? 0.0 : (currentClipTime - k1.timeInSeconds) / diff;
    final curvedT = k1.curve.evaluate(rawT);

    return VideoKeyframe(
      id: 'kf_interpolated',
      timestamp: Duration(milliseconds: (currentClipTime * 1000).round()),
      scale: ui.lerpDouble(k1.scale, k2.scale, curvedT) ?? k1.scale,
      rotationDegrees: ui.lerpDouble(k1.rotationDegrees, k2.rotationDegrees, curvedT) ?? k1.rotationDegrees,
      positionX: ui.lerpDouble(k1.positionX, k2.positionX, curvedT) ?? k1.positionX,
      positionY: ui.lerpDouble(k1.positionY, k2.positionY, curvedT) ?? k1.positionY,
      opacity: (ui.lerpDouble(k1.opacity, k2.opacity, curvedT) ?? k1.opacity).clamp(0.0, 1.0),
      curve: k1.curve,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestampMs': timestamp.inMilliseconds,
    'scale': scale,
    'rotationDegrees': rotationDegrees,
    'positionX': positionX,
    'positionY': positionY,
    'opacity': opacity,
    'curve': curve.name,
  };

  factory VideoKeyframe.fromJson(Map<String, dynamic> json) {
    KeyframeCurve parsedCurve = KeyframeCurve.easeInOut;
    if (json['curve'] is String) {
      parsedCurve = KeyframeCurve.values.firstWhere(
        (c) => c.name == json['curve'],
        orElse: () => KeyframeCurve.easeInOut,
      );
    }

    return VideoKeyframe(
      id: json['id'] as String? ?? 'kf_',
      timestamp: Duration(milliseconds: (json['timestampMs'] as num?)?.toInt() ?? 0),
      scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
      rotationDegrees: (json['rotationDegrees'] as num?)?.toDouble() ?? 0.0,
      positionX: (json['positionX'] as num?)?.toDouble() ?? 0.0,
      positionY: (json['positionY'] as num?)?.toDouble() ?? 0.0,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      curve: parsedCurve,
    );
  }

  @override
  String toString() =>
      'VideoKeyframe(time: ${timeInSeconds}s, scale: $scale, rot: $rotationDegrees, pos: ($positionX, $positionY), op: $opacity, curve: ${curve.name})';
}
