/// Represents a single keyframe point on a clip's timeline
class VideoKeyframe {
  final String id;
  final Duration timestamp; // Offset relative to clip start
  final double scale; // 0.1 to 5.0
  final double rotationDegrees; // -360 to 360
  final double positionX; // Pan X in pixels
  final double positionY; // Pan Y in pixels
  final double opacity; // 0.0 to 1.0

  const VideoKeyframe({
    required this.id,
    required this.timestamp,
    this.scale = 1.0,
    this.rotationDegrees = 0.0,
    this.positionX = 0.0,
    this.positionY = 0.0,
    this.opacity = 1.0,
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
  }) {
    return VideoKeyframe(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      scale: scale ?? this.scale,
      rotationDegrees: rotationDegrees ?? this.rotationDegrees,
      positionX: positionX ?? this.positionX,
      positionY: positionY ?? this.positionY,
      opacity: opacity ?? this.opacity,
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
  };

  factory VideoKeyframe.fromJson(Map<String, dynamic> json) {
    return VideoKeyframe(
      id: json['id'] as String? ?? 'kf_',
      timestamp: Duration(milliseconds: (json['timestampMs'] as num?)?.toInt() ?? 0),
      scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
      rotationDegrees: (json['rotationDegrees'] as num?)?.toDouble() ?? 0.0,
      positionX: (json['positionX'] as num?)?.toDouble() ?? 0.0,
      positionY: (json['positionY'] as num?)?.toDouble() ?? 0.0,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
    );
  }

  @override
  String toString() =>
      'VideoKeyframe(time: s, scale: , rot: , pos: (, ), op: )';
}
