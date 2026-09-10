import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:capcut_video_editor/domain/models/clip_spatial_transform.dart';
import 'package:capcut_video_editor/domain/models/video_clip.dart';

void main() {
  group('ClipSpatialTransform Center Snapping & Hysteresis Unit Tests', () {
    test('Snaps to 0.0 when distance is within snap threshold (<= 10.0)', () {
      final (effective10, isSnapped10) = ClipSpatialTransform.calculateCenterSnap(
        rawCoordinate: 10.0,
        currentlySnapped: false,
      );
      expect(isSnapped10, isTrue);
      expect(effective10, 0.0);

      final (effective5, isSnapped5) = ClipSpatialTransform.calculateCenterSnap(
        rawCoordinate: 5.5,
        currentlySnapped: false,
      );
      expect(isSnapped5, isTrue);
      expect(effective5, 0.0);

      final (effective0, isSnapped0) = ClipSpatialTransform.calculateCenterSnap(
        rawCoordinate: 0.0,
        currentlySnapped: false,
      );
      expect(isSnapped0, isTrue);
      expect(effective0, 0.0);

      final (effectiveNeg7, isSnappedNeg7) = ClipSpatialTransform.calculateCenterSnap(
        rawCoordinate: -7.2,
        currentlySnapped: false,
      );
      expect(isSnappedNeg7, isTrue);
      expect(effectiveNeg7, 0.0);
    });

    test('Does NOT snap when distance exceeds snap threshold (> 10.0)', () {
      final (effective11, isSnapped11) = ClipSpatialTransform.calculateCenterSnap(
        rawCoordinate: 10.01,
        currentlySnapped: false,
      );
      expect(isSnapped11, isFalse);
      expect(effective11, 10.01);

      final (effective25, isSnapped25) = ClipSpatialTransform.calculateCenterSnap(
        rawCoordinate: 25.0,
        currentlySnapped: false,
      );
      expect(isSnapped25, isFalse);
      expect(effective25, 25.0);

      final (effectiveNeg12, isSnappedNeg12) = ClipSpatialTransform.calculateCenterSnap(
        rawCoordinate: -12.0,
        currentlySnapped: false,
      );
      expect(isSnappedNeg12, isFalse);
      expect(effectiveNeg12, -12.0);
    });

    test('Hysteresis: stays snapped until coordinate exceeds release threshold (> 14.0)', () {
      final (effective12, isSnapped12) = ClipSpatialTransform.calculateCenterSnap(
        rawCoordinate: 12.0,
        currentlySnapped: true,
      );
      expect(isSnapped12, isTrue);
      expect(effective12, 0.0);

      final (effective14, isSnapped14) = ClipSpatialTransform.calculateCenterSnap(
        rawCoordinate: 14.0,
        currentlySnapped: true,
      );
      expect(isSnapped14, isTrue);
      expect(effective14, 0.0);

      final (effectiveNeg13, isSnappedNeg13) = ClipSpatialTransform.calculateCenterSnap(
        rawCoordinate: -13.8,
        currentlySnapped: true,
      );
      expect(isSnappedNeg13, isTrue);
      expect(effectiveNeg13, 0.0);
    });

    test('Hysteresis: releases and returns raw coordinate when exceeding release threshold (> 14.0)', () {
      final (effective15, isSnapped15) = ClipSpatialTransform.calculateCenterSnap(
        rawCoordinate: 14.01,
        currentlySnapped: true,
      );
      expect(isSnapped15, isFalse);
      expect(effective15, 14.01);

      final (effectiveNeg20, isSnappedNeg20) = ClipSpatialTransform.calculateCenterSnap(
        rawCoordinate: -20.0,
        currentlySnapped: true,
      );
      expect(isSnappedNeg20, isFalse);
      expect(effectiveNeg20, -20.0);
    });

    test('Independent X and Y axes snapping', () {
      const rawX = 5.0;
      const rawY = 45.0;

      final (effectiveX, isSnappedX) = ClipSpatialTransform.calculateCenterSnap(
        rawCoordinate: rawX,
        currentlySnapped: false,
      );
      final (effectiveY, isSnappedY) = ClipSpatialTransform.calculateCenterSnap(
        rawCoordinate: rawY,
        currentlySnapped: false,
      );

      expect(isSnappedX, isTrue);
      expect(effectiveX, 0.0);
      expect(isSnappedY, isFalse);
      expect(effectiveY, 45.0);
    });

    test('Preserves scale and rotation while snapping xPos and yPos', () {
      const clip = VideoClip(
        id: 'test_clip_1',
        assetId: 'asset_1',
        title: 'Clip 1',
        originalDuration: Duration(seconds: 5),
        trimStart: Duration.zero,
        trimEnd: Duration(seconds: 5),
        previewGradient: [Colors.black, Colors.white],
        xPos: 8.0,
        yPos: 6.0,
        scale: 1.85,
        rotationAngle: 0.785,
      );

      final initial = ClipSpatialTransform.fromClip(clip);
      final (snappedX, _) = ClipSpatialTransform.calculateCenterSnap(
        rawCoordinate: initial.xPos,
        currentlySnapped: false,
      );
      final (snappedY, _) = ClipSpatialTransform.calculateCenterSnap(
        rawCoordinate: initial.yPos,
        currentlySnapped: false,
      );

      final updated = initial.copyWith(
        xPos: snappedX,
        yPos: snappedY,
      );

      expect(updated.xPos, 0.0);
      expect(updated.yPos, 0.0);
      expect(updated.scale, 1.85);
      expect(updated.rotationAngle, 0.785);
    });
  });
}
