import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:capcut_video_editor/domain/models/clip_spatial_transform.dart';

/// Configuration for spatial transform auto-snapping thresholds and hysteresis.
class TransformSnapConfig {
  /// Distance threshold in logical pixels below which clip center auto-snaps to canvas center
  static const double centerSnapThreshold = 10.0;

  /// Distance threshold in logical pixels above which clip center breaks free from center snap
  static const double centerReleaseThreshold = 14.0;

  /// Distance threshold in logical pixels below which clip edge auto-snaps to canvas edge
  static const double edgeSnapThreshold = 10.0;

  /// Distance threshold in logical pixels above which clip edge breaks free from edge snap
  static const double edgeReleaseThreshold = 14.0;
}

/// Supported alignment targets for the horizontal (X) axis.
enum SnapTargetX {
  none,
  centerX,
  leftEdge,
  rightEdge,
}

/// Supported alignment targets for the vertical (Y) axis.
enum SnapTargetY {
  none,
  centerY,
  topEdge,
  bottomEdge,
}

/// The visual axis-aligned bounding box (AABB) of the transformed media clip
/// in canvas-relative space (where (0,0) is canvas center).
class TransformedVisualBounds {
  final double left;
  final double right;
  final double top;
  final double bottom;
  final double centerX;
  final double centerY;

  const TransformedVisualBounds({
    required this.left,
    required this.right,
    required this.top,
    required this.bottom,
    required this.centerX,
    required this.centerY,
  });

  double get width => right - left;
  double get height => bottom - top;

  /// Computes the visual bounding geometry of a clip of dimensions [canvasSize]
  /// transformed by [transform], [legacyRotationDegrees], and flip options.
  ///
  /// The bounds are relative to canvas center (0,0).
  /// Note: The base unrotated clip fills the canvas (-w/2, -h/2) to (w/2, h/2).
  factory TransformedVisualBounds.fromTransform({
    required Size canvasSize,
    required ClipSpatialTransform transform,
    int legacyRotationDegrees = 0,
    bool flipHorizontal = false,
    bool flipVertical = false,
  }) {
    final halfW = canvasSize.width / 2.0;
    final halfH = canvasSize.height / 2.0;

    // Four unrotated corners relative to clip center
    final p0 = Offset(-halfW, -halfH);
    final p1 = Offset(halfW, -halfH);
    final p2 = Offset(halfW, halfH);
    final p3 = Offset(-halfW, halfH);

    final totalRotation = (legacyRotationDegrees * math.pi / 180.0) + transform.rotationAngle;
    final scaleX = (flipHorizontal ? -1.0 : 1.0) * transform.scale;
    final scaleY = (flipVertical ? -1.0 : 1.0) * transform.scale;

    final cosA = math.cos(totalRotation);
    final sinA = math.sin(totalRotation);

    Offset transformCorner(Offset p) {
      // 1. Scale & Flip
      final sx = p.dx * scaleX;
      final sy = p.dy * scaleY;
      // 2. Rotate around center (0,0)
      final rx = sx * cosA - sy * sinA;
      final ry = sx * sinA + sy * cosA;
      // 3. Translate by (xPos, yPos)
      return Offset(rx + transform.xPos, ry + transform.yPos);
    }

    final t0 = transformCorner(p0);
    final t1 = transformCorner(p1);
    final t2 = transformCorner(p2);
    final t3 = transformCorner(p3);

    final left = math.min(math.min(t0.dx, t1.dx), math.min(t2.dx, t3.dx));
    final right = math.max(math.max(t0.dx, t1.dx), math.max(t2.dx, t3.dx));
    final top = math.min(math.min(t0.dy, t1.dy), math.min(t2.dy, t3.dy));
    final bottom = math.max(math.max(t0.dy, t1.dy), math.max(t2.dy, t3.dy));

    return TransformedVisualBounds(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      centerX: transform.xPos,
      centerY: transform.yPos,
    );
  }
}

/// Result of evaluating multi-target snapping on both axes.
class SnapEvaluationResult {
  final double effectiveX;
  final double effectiveY;
  final SnapTargetX snapTargetX;
  final SnapTargetY snapTargetY;

  const SnapEvaluationResult({
    required this.effectiveX,
    required this.effectiveY,
    required this.snapTargetX,
    required this.snapTargetY,
  });

  bool get isSnappedX => snapTargetX != SnapTargetX.none;
  bool get isSnappedY => snapTargetY != SnapTargetY.none;
}

/// Pure deterministic snap engine for advanced center & edge alignment.
class TransformSnapEngine {
  /// Evaluates snapping for both X and Y axes independently, respecting priorities,
  /// rotated bounding geometry, and hysteresis.
  static SnapEvaluationResult evaluateSnap({
    required double rawX,
    required double rawY,
    required double scale,
    required double rotationAngle,
    required Size canvasSize,
    int legacyRotationDegrees = 0,
    bool flipHorizontal = false,
    bool flipVertical = false,
    SnapTargetX currentSnapX = SnapTargetX.none,
    SnapTargetY currentSnapY = SnapTargetY.none,
  }) {
    // 1. Evaluate X-axis
    final (effectiveX, newSnapX) = _evaluateAxisX(
      rawX: rawX,
      scale: scale,
      rotationAngle: rotationAngle,
      canvasSize: canvasSize,
      legacyRotationDegrees: legacyRotationDegrees,
      flipHorizontal: flipHorizontal,
      flipVertical: flipVertical,
      currentSnap: currentSnapX,
    );

    // 2. Evaluate Y-axis
    final (effectiveY, newSnapY) = _evaluateAxisY(
      rawY: rawY,
      scale: scale,
      rotationAngle: rotationAngle,
      canvasSize: canvasSize,
      legacyRotationDegrees: legacyRotationDegrees,
      flipHorizontal: flipHorizontal,
      flipVertical: flipVertical,
      currentSnap: currentSnapY,
    );

    return SnapEvaluationResult(
      effectiveX: effectiveX,
      effectiveY: effectiveY,
      snapTargetX: newSnapX,
      snapTargetY: newSnapY,
    );
  }

  /// Calculates visual half-extent on the X-axis for the given scale, rotation, and flips.
  /// (bounds.right - bounds.left) / 2
  static double calculateHalfExtentX({
    required Size canvasSize,
    required double scale,
    required double rotationAngle,
    int legacyRotationDegrees = 0,
    bool flipHorizontal = false,
    bool flipVertical = false,
  }) {
    final bounds = TransformedVisualBounds.fromTransform(
      canvasSize: canvasSize,
      transform: ClipSpatialTransform(
        clipId: '',
        xPos: 0.0,
        yPos: 0.0,
        scale: scale,
        rotationAngle: rotationAngle,
      ),
      legacyRotationDegrees: legacyRotationDegrees,
      flipHorizontal: flipHorizontal,
      flipVertical: flipVertical,
    );
    return (bounds.right - bounds.left) / 2.0;
  }

  /// Calculates visual half-extent on the Y-axis for the given scale, rotation, and flips.
  /// (bounds.bottom - bounds.top) / 2
  static double calculateHalfExtentY({
    required Size canvasSize,
    required double scale,
    required double rotationAngle,
    int legacyRotationDegrees = 0,
    bool flipHorizontal = false,
    bool flipVertical = false,
  }) {
    final bounds = TransformedVisualBounds.fromTransform(
      canvasSize: canvasSize,
      transform: ClipSpatialTransform(
        clipId: '',
        xPos: 0.0,
        yPos: 0.0,
        scale: scale,
        rotationAngle: rotationAngle,
      ),
      legacyRotationDegrees: legacyRotationDegrees,
      flipHorizontal: flipHorizontal,
      flipVertical: flipVertical,
    );
    return (bounds.bottom - bounds.top) / 2.0;
  }

  static (double, SnapTargetX) _evaluateAxisX({
    required double rawX,
    required double scale,
    required double rotationAngle,
    required Size canvasSize,
    required int legacyRotationDegrees,
    required bool flipHorizontal,
    required bool flipVertical,
    required SnapTargetX currentSnap,
  }) {
    final halfCanvasW = canvasSize.width / 2.0;
    final halfClipW = calculateHalfExtentX(
      canvasSize: canvasSize,
      scale: scale,
      rotationAngle: rotationAngle,
      legacyRotationDegrees: legacyRotationDegrees,
      flipHorizontal: flipHorizontal,
      flipVertical: flipVertical,
    );

    // Target X coordinates in canvas-relative space (center is 0.0):
    // 1. Center: x = 0.0
    const targetCenterX = 0.0;
    // 2. Left edge aligned: clip.left == -halfCanvasW => rawX - halfClipW == -halfCanvasW => rawX = -halfCanvasW + halfClipW
    final targetLeftEdgeX = -halfCanvasW + halfClipW;
    // 3. Right edge aligned: clip.right == halfCanvasW => rawX + halfClipW == halfClipW => rawX = halfCanvasW - halfClipW
    final targetRightEdgeX = halfCanvasW - halfClipW;

    // A. If currently snapped to a target, test hysteresis release against that specific target
    if (currentSnap == SnapTargetX.centerX) {
      final dist = (rawX - targetCenterX).abs();
      if (dist <= TransformSnapConfig.centerReleaseThreshold) {
        return (targetCenterX, SnapTargetX.centerX);
      }
    } else if (currentSnap == SnapTargetX.leftEdge) {
      final dist = (rawX - targetLeftEdgeX).abs();
      if (dist <= TransformSnapConfig.edgeReleaseThreshold) {
        return (targetLeftEdgeX, SnapTargetX.leftEdge);
      }
    } else if (currentSnap == SnapTargetX.rightEdge) {
      final dist = (rawX - targetRightEdgeX).abs();
      if (dist <= TransformSnapConfig.edgeReleaseThreshold) {
        return (targetRightEdgeX, SnapTargetX.rightEdge);
      }
    }

    // B. Not currently snapped or exceeded release threshold -> Evaluate new snap candidates
    // Priority 1: Center X
    final distCenter = (rawX - targetCenterX).abs();
    if (distCenter <= TransformSnapConfig.centerSnapThreshold) {
      return (targetCenterX, SnapTargetX.centerX);
    }

    // Priority 2: Canvas Edges
    final distLeft = (rawX - targetLeftEdgeX).abs();
    final distRight = (rawX - targetRightEdgeX).abs();

    final canSnapLeft = distLeft <= TransformSnapConfig.edgeSnapThreshold;
    final canSnapRight = distRight <= TransformSnapConfig.edgeSnapThreshold;

    if (canSnapLeft && canSnapRight) {
      if (distLeft <= distRight) {
        return (targetLeftEdgeX, SnapTargetX.leftEdge);
      } else {
        return (targetRightEdgeX, SnapTargetX.rightEdge);
      }
    } else if (canSnapLeft) {
      return (targetLeftEdgeX, SnapTargetX.leftEdge);
    } else if (canSnapRight) {
      return (targetRightEdgeX, SnapTargetX.rightEdge);
    }

    // No snap active
    return (rawX, SnapTargetX.none);
  }

  static (double, SnapTargetY) _evaluateAxisY({
    required double rawY,
    required double scale,
    required double rotationAngle,
    required Size canvasSize,
    required int legacyRotationDegrees,
    required bool flipHorizontal,
    required bool flipVertical,
    required SnapTargetY currentSnap,
  }) {
    final halfCanvasH = canvasSize.height / 2.0;
    final halfClipH = calculateHalfExtentY(
      canvasSize: canvasSize,
      scale: scale,
      rotationAngle: rotationAngle,
      legacyRotationDegrees: legacyRotationDegrees,
      flipHorizontal: flipHorizontal,
      flipVertical: flipVertical,
    );

    // Target Y coordinates in canvas-relative space (center is 0.0):
    // 1. Center: y = 0.0
    const targetCenterY = 0.0;
    // 2. Top edge aligned: clip.top == -halfCanvasH => rawY - halfClipH == -halfCanvasH => rawY = -halfCanvasH + halfClipH
    final targetTopEdgeY = -halfCanvasH + halfClipH;
    // 3. Bottom edge aligned: clip.bottom == halfCanvasH => rawY + halfClipH == halfCanvasH => rawY = halfCanvasH - halfClipH
    final targetBottomEdgeY = halfCanvasH - halfClipH;

    // A. If currently snapped to a target, test hysteresis release against that specific target
    if (currentSnap == SnapTargetY.centerY) {
      final dist = (rawY - targetCenterY).abs();
      if (dist <= TransformSnapConfig.centerReleaseThreshold) {
        return (targetCenterY, SnapTargetY.centerY);
      }
    } else if (currentSnap == SnapTargetY.topEdge) {
      final dist = (rawY - targetTopEdgeY).abs();
      if (dist <= TransformSnapConfig.edgeReleaseThreshold) {
        return (targetTopEdgeY, SnapTargetY.topEdge);
      }
    } else if (currentSnap == SnapTargetY.bottomEdge) {
      final dist = (rawY - targetBottomEdgeY).abs();
      if (dist <= TransformSnapConfig.edgeReleaseThreshold) {
        return (targetBottomEdgeY, SnapTargetY.bottomEdge);
      }
    }

    // B. Not currently snapped or exceeded release threshold -> Evaluate new snap candidates
    // Priority 1: Center Y
    final distCenter = (rawY - targetCenterY).abs();
    if (distCenter <= TransformSnapConfig.centerSnapThreshold) {
      return (targetCenterY, SnapTargetY.centerY);
    }

    // Priority 2: Canvas Edges
    final distTop = (rawY - targetTopEdgeY).abs();
    final distBottom = (rawY - targetBottomEdgeY).abs();

    final canSnapTop = distTop <= TransformSnapConfig.edgeSnapThreshold;
    final canSnapBottom = distBottom <= TransformSnapConfig.edgeSnapThreshold;

    if (canSnapTop && canSnapBottom) {
      if (distTop <= distBottom) {
        return (targetTopEdgeY, SnapTargetY.topEdge);
      } else {
        return (targetBottomEdgeY, SnapTargetY.bottomEdge);
      }
    } else if (canSnapTop) {
      return (targetTopEdgeY, SnapTargetY.topEdge);
    } else if (canSnapBottom) {
      return (targetBottomEdgeY, SnapTargetY.bottomEdge);
    }

    // No snap active
    return (rawY, SnapTargetY.none);
  }
}
