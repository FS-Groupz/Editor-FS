import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:capcut_video_editor/domain/models/clip_spatial_transform.dart';
import 'package:capcut_video_editor/domain/models/video_clip.dart';

/// Global registry Notifier holding spatial transforms for all clips in the project.
///
/// Manages high-frequency spatial transformations and coordinates per-clip state
/// updates without triggering unnecessary rebuilds across unrelated components.
class SpatialTransformMapNotifier extends Notifier<Map<String, ClipSpatialTransform>> {
  @override
  Map<String, ClipSpatialTransform> build() {
    return const {};
  }

  /// Initializes or registers a clip's spatial state if not already present.
  void registerClip(VideoClip clip) {
    if (!state.containsKey(clip.id)) {
      state = {
        ...state,
        clip.id: ClipSpatialTransform.fromClip(clip),
      };
    }
  }

  /// Synchronizes the map from the authoritative list of video clips.
  void syncFromClips(List<VideoClip> clips) {
    final newMap = <String, ClipSpatialTransform>{};
    for (final clip in clips) {
      newMap[clip.id] = state[clip.id] ?? ClipSpatialTransform.fromClip(clip);
    }
    state = newMap;
  }

  /// Retrieves spatial transform for a given clip ID, with optional fallback or canonical defaults.
  ClipSpatialTransform getTransform(String clipId, [ClipSpatialTransform? fallback]) {
    return state[clipId] ?? fallback ?? ClipSpatialTransform(clipId: clipId);
  }

  /// Updates horizontal (xPos) and vertical (yPos) position of the specified clip.
  void updatePosition(String clipId, double xPos, double yPos) {
    final current = getTransform(clipId);
    final newX = ClipSpatialTransform.sanitizePosition(xPos, fallback: current.xPos);
    final newY = ClipSpatialTransform.sanitizePosition(yPos, fallback: current.yPos);
    if (current.xPos == newX && current.yPos == newY) return;

    final updated = current.copyWith(xPos: newX, yPos: newY);
    state = {...state, clipId: updated};
  }

  /// Updates scale of the specified clip, validated against non-positive, NaN, and Infinity.
  void updateScale(String clipId, double scale) {
    final current = getTransform(clipId);
    final sanitized = ClipSpatialTransform.sanitizeScale(scale, fallback: current.scale);
    if (current.scale == sanitized) return;

    final updated = current.copyWith(scale: sanitized);
    state = {...state, clipId: updated};
  }

  /// Updates continuous spatial rotation angle in radians of the specified clip.
  void updateRotation(String clipId, double rotationAngle) {
    final current = getTransform(clipId);
    final sanitized = ClipSpatialTransform.sanitizeRotation(rotationAngle, fallback: current.rotationAngle);
    if (current.rotationAngle == sanitized) return;

    final updated = current.copyWith(rotationAngle: sanitized);
    state = {...state, clipId: updated};
  }

  /// Atomically updates position, scale, and rotation of the specified clip in a single mutation.
  void updateTransform(
    String clipId, {
    double? xPos,
    double? yPos,
    double? scale,
    double? rotationAngle,
  }) {
    final current = getTransform(clipId);
    final newX = xPos != null ? ClipSpatialTransform.sanitizePosition(xPos, fallback: current.xPos) : current.xPos;
    final newY = yPos != null ? ClipSpatialTransform.sanitizePosition(yPos, fallback: current.yPos) : current.yPos;
    final newScale = scale != null ? ClipSpatialTransform.sanitizeScale(scale, fallback: current.scale) : current.scale;
    final newRotation = rotationAngle != null ? ClipSpatialTransform.sanitizeRotation(rotationAngle, fallback: current.rotationAngle) : current.rotationAngle;

    if (current.xPos == newX &&
        current.yPos == newY &&
        current.scale == newScale &&
        current.rotationAngle == newRotation) {
      return;
    }

    final updated = ClipSpatialTransform(
      clipId: clipId,
      xPos: newX,
      yPos: newY,
      scale: newScale,
      rotationAngle: newRotation,
    );
    state = {...state, clipId: updated};
  }

  /// Resets specified clip's transform to canonical defaults.
  void resetTransform(String clipId) {
    state = {...state, clipId: ClipSpatialTransform(clipId: clipId)};
  }

  /// Alias for resetTransform matching requirements.
  void reset(String clipId) => resetTransform(clipId);

  /// Clears the transient transform for a specific clip ID from the map.
  void clearTransform(String clipId) {
    if (state.containsKey(clipId)) {
      final updated = Map<String, ClipSpatialTransform>.from(state)..remove(clipId);
      state = updated;
    }
  }

  /// Clears all transient transforms from the map.
  void clearAll() {
    if (state.isNotEmpty) {
      state = const {};
    }
  }
}

// ============================================================================
// Riverpod Providers for Spatial State Management
// ============================================================================

/// Master provider managing spatial transforms for all clips.
final spatialTransformMapProvider =
    NotifierProvider<SpatialTransformMapNotifier, Map<String, ClipSpatialTransform>>(
  SpatialTransformMapNotifier.new,
);

/// Isolated family provider for watching a single clip's spatial transform by ID.
///
/// Uses `.select` internally so that a widget watching a specific `clipId` ONLY
/// rebuilds when that exact clip's transform is mutated. High-frequency pan/scale
/// gestures on one clip will NOT trigger rebuilds for any other clip.
final clipSpatialTransformProvider =
    Provider.family<ClipSpatialTransform, String>((ref, clipId) {
  return ref.watch(spatialTransformMapProvider.select(
    (map) => map[clipId] ?? ClipSpatialTransform(clipId: clipId),
  ));
});

/// Isolated family provider for watching a clip's spatial transform derived purely from domain state.
///
/// Pure derivation flow:
/// VideoClip spatial state -> initial provider state -> widget reads provider state.
///
/// If a transient transform exists in [spatialTransformMapProvider] (during interactive pan/pinch/rotate gestures),
/// it returns that high-frequency transform. Otherwise, it derives directly and purely from [clip]
/// without any build-time mutations, side-effects, or race conditions.
final clipSpatialTransformFromClipProvider =
    Provider.family<ClipSpatialTransform, VideoClip>((ref, clip) {
  final transient = ref.watch(spatialTransformMapProvider.select(
    (map) => map[clip.id],
  ));
  return transient ?? ClipSpatialTransform.fromClip(clip);
});

/// Per-clip spatial transform controller providing targeted mutation methods for a specific clip.
class ClipSpatialTransformController {
  final Ref ref;
  final String clipId;

  ClipSpatialTransformController(this.ref, this.clipId);

  ClipSpatialTransform get current =>
      ref.read(spatialTransformMapProvider.notifier).getTransform(clipId);

  void updatePosition(double xPos, double yPos) {
    ref.read(spatialTransformMapProvider.notifier).updatePosition(clipId, xPos, yPos);
  }

  void updateScale(double scale) {
    ref.read(spatialTransformMapProvider.notifier).updateScale(clipId, scale);
  }

  void updateRotation(double rotationAngle) {
    ref.read(spatialTransformMapProvider.notifier).updateRotation(clipId, rotationAngle);
  }

  void updateTransform({
    double? xPos,
    double? yPos,
    double? scale,
    double? rotationAngle,
  }) {
    ref.read(spatialTransformMapProvider.notifier).updateTransform(
          clipId,
          xPos: xPos,
          yPos: yPos,
          scale: scale,
          rotationAngle: rotationAngle,
        );
  }

  void reset() {
    ref.read(spatialTransformMapProvider.notifier).reset(clipId);
  }
}

/// Dedicated provider family exposing a controller for an individual clip.
final clipSpatialTransformControllerProvider =
    Provider.family<ClipSpatialTransformController, String>((ref, clipId) {
  return ClipSpatialTransformController(ref, clipId);
});
