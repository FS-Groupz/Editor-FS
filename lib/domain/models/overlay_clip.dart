import 'package:flutter/material.dart';
import 'package:capcut_video_editor/domain/models/keyframe.dart';
import 'package:capcut_video_editor/domain/models/video_mask.dart';

/// Represents a secondary Picture-in-Picture (PIP) overlay clip layer on top of main video
class OverlayClip {
  final String id;
  final String title;
  final Duration startTime;
  final Duration duration;
  final Offset position; // Relative (0.0 to 1.0) on canvas
  final double scale; // 0.2 to 1.5
  final double opacity; // 0.0 to 1.0
  final double rotation; // In radians
  final List<Color> previewGradient;
  final IconData previewIcon;
  final List<VideoKeyframe> keyframes;
  final VideoMask? mask;
  final BlendMode blendMode;

  const OverlayClip({
    required this.id,
    required this.title,
    required this.startTime,
    required this.duration,
    this.position = const Offset(0.7, 0.25),
    this.scale = 0.45,
    this.opacity = 1.0,
    this.rotation = 0.0,
    this.previewGradient = const [Color(0xFF8A2387), Color(0xFFE94057)],
    this.previewIcon = Icons.layers_rounded,
    this.keyframes = const [],
    this.mask,
    this.blendMode = BlendMode.srcOver,
  });

  double get startTimeInSeconds => startTime.inMilliseconds / 1000.0;
  double get durationInSeconds => duration.inMilliseconds / 1000.0;

  OverlayClip copyWith({
    String? id,
    String? title,
    Duration? startTime,
    Duration? duration,
    Offset? position,
    double? scale,
    double? opacity,
    double? rotation,
    List<Color>? previewGradient,
    IconData? previewIcon,
    List<VideoKeyframe>? keyframes,
    VideoMask? mask,
    bool clearMask = false,
    BlendMode? blendMode,
  }) {
    return OverlayClip(
      id: id ?? this.id,
      title: title ?? this.title,
      startTime: startTime ?? this.startTime,
      duration: duration ?? this.duration,
      position: position ?? this.position,
      scale: scale ?? this.scale,
      opacity: opacity ?? this.opacity,
      rotation: rotation ?? this.rotation,
      previewGradient: previewGradient ?? this.previewGradient,
      previewIcon: previewIcon ?? this.previewIcon,
      keyframes: keyframes ?? this.keyframes,
      mask: clearMask ? null : (mask ?? this.mask),
      blendMode: blendMode ?? this.blendMode,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'startTimeMs': startTime.inMilliseconds,
      'durationMs': duration.inMilliseconds,
      'posX': position.dx,
      'posY': position.dy,
      'scale': scale,
      'opacity': opacity,
      'rotation': rotation,
      if (keyframes.isNotEmpty) 'keyframes': keyframes.map((k) => k.toJson()).toList(),
      if (mask != null) 'mask': mask!.toJson(),
      'blendMode': blendMode.index,
    };
  }

  factory OverlayClip.fromJson(Map<String, dynamic> json) {
    return OverlayClip(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Overlay',
      startTime: Duration(milliseconds: (json['startTimeMs'] as num?)?.toInt() ?? 0),
      duration: Duration(milliseconds: (json['durationMs'] as num?)?.toInt() ?? 3000),
      position: Offset(
        (json['posX'] as num?)?.toDouble() ?? 0.7,
        (json['posY'] as num?)?.toDouble() ?? 0.25,
      ),
      scale: (json['scale'] as num?)?.toDouble() ?? 0.45,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
      keyframes: (json['keyframes'] as List<dynamic>?)
              ?.map((k) => VideoKeyframe.fromJson(k as Map<String, dynamic>))
              .toList() ??
          const [],
      mask: json['mask'] != null ? VideoMask.fromJson(json['mask'] as Map<String, dynamic>) : null,
      blendMode: json['blendMode'] != null
          ? BlendMode.values[(json['blendMode'] as num).toInt().clamp(0, BlendMode.values.length - 1)]
          : BlendMode.srcOver,
    );
  }
}
