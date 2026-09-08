import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:capcut_video_editor/domain/models/video_clip.dart';

/// Immutable domain model representing the spatial transformation state
/// of an individual media clip on the interactive canvas.
class ClipSpatialTransform {
  /// Associated unique clip ID
  final String clipId;

  /// Horizontal position offset relative to canvas center (default 0.0)
  final double xPos;

  /// Vertical position offset relative to canvas center (default 0.0)
  final double yPos;

  /// Uniform spatial scale factor (default 1.0, must be positive finite)
  final double scale;

  /// Continuous spatial rotation in radians (default 0.0)
  final double rotationAngle;

  /// Minimum allowable scale to prevent inversion or zero-dimension rendering
  static const double minScale = 0.05;

  /// Maximum allowable scale
  static const double maxScale = 20.0;

  const ClipSpatialTransform({
    required this.clipId,
    this.xPos = 0.0,
    this.yPos = 0.0,
    this.scale = 1.0,
    this.rotationAngle = 0.0,
  });

  /// Factory constructor to extract spatial transform directly from a VideoClip
  factory ClipSpatialTransform.fromClip(VideoClip clip) {
    return ClipSpatialTransform(
      clipId: clip.id,
      xPos: clip.xPos,
      yPos: clip.yPos,
      scale: clip.scale,
      rotationAngle: clip.rotationAngle,
    );
  }

  /// Sanitizes and validates scale to ensure it is positive and finite
  static double sanitizeScale(double rawScale, {double fallback = 1.0}) {
    if (rawScale.isNaN || !rawScale.isFinite || rawScale <= 0.0) {
      return fallback;
    }
    return rawScale.clamp(minScale, maxScale);
  }

  /// Sanitizes position coordinate ensuring finite numbers
  static double sanitizePosition(double val, {double fallback = 0.0}) {
    if (val.isNaN || !val.isFinite) return fallback;
    return val;
  }

  /// Sanitizes rotation angle ensuring finite numbers
  static double sanitizeRotation(double val, {double fallback = 0.0}) {
    if (val.isNaN || !val.isFinite) return fallback;
    return val;
  }

  ClipSpatialTransform copyWith({
    String? clipId,
    double? xPos,
    double? yPos,
    double? scale,
    double? rotationAngle,
  }) {
    return ClipSpatialTransform(
      clipId: clipId ?? this.clipId,
      xPos: xPos != null ? sanitizePosition(xPos, fallback: this.xPos) : this.xPos,
      yPos: yPos != null ? sanitizePosition(yPos, fallback: this.yPos) : this.yPos,
      scale: scale != null ? sanitizeScale(scale, fallback: this.scale) : this.scale,
      rotationAngle: rotationAngle != null ? sanitizeRotation(rotationAngle, fallback: this.rotationAngle) : this.rotationAngle,
    );
  }

  /// Applies this spatial transform to an existing VideoClip immutably
  VideoClip applyTo(VideoClip clip) {
    return clip.copyWith(
      xPos: xPos,
      yPos: yPos,
      scale: scale,
      rotationAngle: rotationAngle,
    );
  }

  /// Computes the Flutter Matrix4 representation for this spatial transform,
  /// seamlessly composing continuous spatial transform with legacy step rotation
  /// and horizontal/vertical flips.
  Matrix4 toMatrix4({
    int legacyRotationDegrees = 0,
    bool flipHorizontal = false,
    bool flipVertical = false,
  }) {
    final totalRotation = (legacyRotationDegrees * math.pi / 180.0) + rotationAngle;
    final scaleX = (flipHorizontal ? -1.0 : 1.0) * scale;
    final scaleY = (flipVertical ? -1.0 : 1.0) * scale;

    return Matrix4.identity()
      ..translateByDouble(xPos, yPos, 0.0, 1.0)
      ..rotateZ(totalRotation)
      ..scaleByDouble(scaleX, scaleY, 1.0, 1.0);
  }

  Map<String, dynamic> toJson() {
    return {
      'clipId': clipId,
      'xPos': xPos,
      'yPos': yPos,
      'scale': scale,
      'rotationAngle': rotationAngle,
    };
  }

  factory ClipSpatialTransform.fromJson(Map<String, dynamic> json) {
    return ClipSpatialTransform(
      clipId: json['clipId'] as String? ?? '',
      xPos: sanitizePosition((json['xPos'] as num?)?.toDouble() ?? 0.0),
      yPos: sanitizePosition((json['yPos'] as num?)?.toDouble() ?? 0.0),
      scale: sanitizeScale((json['scale'] as num?)?.toDouble() ?? 1.0),
      rotationAngle: sanitizeRotation((json['rotationAngle'] as num?)?.toDouble() ?? 0.0),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClipSpatialTransform &&
          runtimeType == other.runtimeType &&
          clipId == other.clipId &&
          xPos == other.xPos &&
          yPos == other.yPos &&
          scale == other.scale &&
          rotationAngle == other.rotationAngle;

  @override
  int get hashCode =>
      clipId.hashCode ^
      xPos.hashCode ^
      yPos.hashCode ^
      scale.hashCode ^
      rotationAngle.hashCode;

  @override
  String toString() =>
      'ClipSpatialTransform(clipId: $clipId, x: $xPos, y: $yPos, scale: $scale, rad: $rotationAngle)';
}
