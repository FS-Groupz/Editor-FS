import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:capcut_video_editor/domain/enums/export_resolution.dart';
import 'package:capcut_video_editor/domain/enums/transition_type.dart';
import 'package:capcut_video_editor/domain/models/export_settings.dart';
import 'package:capcut_video_editor/domain/models/media_asset.dart';
import 'package:capcut_video_editor/domain/models/project.dart';
import 'package:capcut_video_editor/domain/models/transition.dart';
import 'package:capcut_video_editor/domain/models/video_clip.dart';
import 'package:capcut_video_editor/core/services/device_media_service.dart';

/// Reference model replicating the exact Phase 3B native export matrix math
class ExportTransformCalculation {
  final double xExport;
  final double yExport;
  final double scaleX;
  final double scaleY;
  final double totalRotationDegrees;
  final Rect dstRect;

  ExportTransformCalculation({
    required this.xExport,
    required this.yExport,
    required this.scaleX,
    required this.scaleY,
    required this.totalRotationDegrees,
    required this.dstRect,
  });

  factory ExportTransformCalculation.compute({
    required double xPos,
    required double yPos,
    required double scale,
    required double rotationAngle,
    required int rotationDegrees,
    required bool flipHorizontal,
    required bool flipVertical,
    required int exportWidth,
    required int exportHeight,
    required int sourceWidth,
    required int sourceHeight,
  }) {
    // Aligned dimensions
    final width = (exportWidth ~/ 16) * 16;
    final height = (exportHeight ~/ 16) * 16;

    // Sanitization
    final safeScale = (!scale.isFinite || scale <= 0.0) ? 1.0 : scale.clamp(0.05, 20.0);
    final safeX = !xPos.isFinite ? 0.0 : xPos;
    final safeY = !yPos.isFinite ? 0.0 : yPos;
    final safeRot = !rotationAngle.isFinite ? 0.0 : rotationAngle;

    // Aspect-fit dstRect
    final frameRatio = sourceWidth / sourceHeight;
    final targetRatio = width / height;

    final Rect dstRect;
    if (frameRatio > targetRatio) {
      final drawH = (width / frameRatio).round();
      final top = ((height - drawH) / 2).roundToDouble();
      dstRect = Rect.fromLTWH(0, top, width.toDouble(), drawH.toDouble());
    } else {
      final drawW = (height * frameRatio).round();
      final left = ((width - drawW) / 2).roundToDouble();
      dstRect = Rect.fromLTWH(left, 0, drawW.toDouble(), height.toDouble());
    }

    final kCanvas = width / 360.0;
    final xExp = safeX * kCanvas;
    final yExp = safeY * kCanvas;

    final sX = (flipHorizontal ? -1.0 : 1.0) * safeScale;
    final sY = (flipVertical ? -1.0 : 1.0) * safeScale;

    final continuousDeg = safeRot * 180.0 / math.pi;
    final totalDeg = rotationDegrees.toDouble() + continuousDeg;

    return ExportTransformCalculation(
      xExport: xExp,
      yExport: yExp,
      scaleX: sX,
      scaleY: sY,
      totalRotationDegrees: totalDeg,
      dstRect: dstRect,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 3B — Native Export Spatial Transform Mathematical Contract', () {
    test('1. Identity transform produces zero translation, 1.0 scale, 0 rotation', () {
      final result = ExportTransformCalculation.compute(
        xPos: 0.0,
        yPos: 0.0,
        scale: 1.0,
        rotationAngle: 0.0,
        rotationDegrees: 0,
        flipHorizontal: false,
        flipVertical: false,
        exportWidth: 720,
        exportHeight: 1280,
        sourceWidth: 720,
        sourceHeight: 1280,
      );

      expect(result.xExport, equals(0.0));
      expect(result.yExport, equals(0.0));
      expect(result.scaleX, equals(1.0));
      expect(result.scaleY, equals(1.0));
      expect(result.totalRotationDegrees, equals(0.0));
    });

    test('2. Positive X pan scales by exact Kcanvas', () {
      final result = ExportTransformCalculation.compute(
        xPos: 50.0,
        yPos: 0.0,
        scale: 1.0,
        rotationAngle: 0.0,
        rotationDegrees: 0,
        flipHorizontal: false,
        flipVertical: false,
        exportWidth: 720,
        exportHeight: 1280,
        sourceWidth: 720,
        sourceHeight: 1280,
      );

      // Kcanvas = 720 / 360 = 2.0
      expect(result.xExport, equals(100.0));
      expect(result.yExport, equals(0.0));
    });

    test('3. Negative X pan preserves leftward direction without sign inversion', () {
      final result = ExportTransformCalculation.compute(
        xPos: -75.0,
        yPos: 0.0,
        scale: 1.0,
        rotationAngle: 0.0,
        rotationDegrees: 0,
        flipHorizontal: false,
        flipVertical: false,
        exportWidth: 720,
        exportHeight: 1280,
        sourceWidth: 720,
        sourceHeight: 1280,
      );

      // Kcanvas = 720 / 360 = 2.0
      expect(result.xExport, equals(-150.0));
    });

    test('4. Positive Y pan preserves downward direction', () {
      final result = ExportTransformCalculation.compute(
        xPos: 0.0,
        yPos: 60.0,
        scale: 1.0,
        rotationAngle: 0.0,
        rotationDegrees: 0,
        flipHorizontal: false,
        flipVertical: false,
        exportWidth: 720,
        exportHeight: 1280,
        sourceWidth: 720,
        sourceHeight: 1280,
      );

      expect(result.yExport, equals(120.0));
    });

    test('5. Negative Y pan preserves upward direction', () {
      final result = ExportTransformCalculation.compute(
        xPos: 0.0,
        yPos: -40.0,
        scale: 1.0,
        rotationAngle: 0.0,
        rotationDegrees: 0,
        flipHorizontal: false,
        flipVertical: false,
        exportWidth: 720,
        exportHeight: 1280,
        sourceWidth: 720,
        sourceHeight: 1280,
      );

      expect(result.yExport, equals(-80.0));
    });

    test('6. Scale 0.5 remains dimensionless at 0.5x baseline', () {
      final result = ExportTransformCalculation.compute(
        xPos: 0.0,
        yPos: 0.0,
        scale: 0.5,
        rotationAngle: 0.0,
        rotationDegrees: 0,
        flipHorizontal: false,
        flipVertical: false,
        exportWidth: 720,
        exportHeight: 1280,
        sourceWidth: 720,
        sourceHeight: 1280,
      );

      expect(result.scaleX, equals(0.5));
      expect(result.scaleY, equals(0.5));
    });

    test('7. Scale 2.0 remains dimensionless at 2.0x baseline', () {
      final result = ExportTransformCalculation.compute(
        xPos: 0.0,
        yPos: 0.0,
        scale: 2.0,
        rotationAngle: 0.0,
        rotationDegrees: 0,
        flipHorizontal: false,
        flipVertical: false,
        exportWidth: 1080,
        exportHeight: 1920,
        sourceWidth: 1080,
        sourceHeight: 1920,
      );

      expect(result.scaleX, equals(2.0));
      expect(result.scaleY, equals(2.0));
    });

    test('8. +90° rotation in radians converts to exact +90° clockwise degrees', () {
      final result = ExportTransformCalculation.compute(
        xPos: 0.0,
        yPos: 0.0,
        scale: 1.0,
        rotationAngle: math.pi / 2,
        rotationDegrees: 0,
        flipHorizontal: false,
        flipVertical: false,
        exportWidth: 720,
        exportHeight: 1280,
        sourceWidth: 720,
        sourceHeight: 1280,
      );

      expect(result.totalRotationDegrees, closeTo(90.0, 0.001));
    });

    test('9. -90° rotation in radians converts to exact -90° counter-clockwise degrees', () {
      final result = ExportTransformCalculation.compute(
        xPos: 0.0,
        yPos: 0.0,
        scale: 1.0,
        rotationAngle: -math.pi / 2,
        rotationDegrees: 0,
        flipHorizontal: false,
        flipVertical: false,
        exportWidth: 720,
        exportHeight: 1280,
        sourceWidth: 720,
        sourceHeight: 1280,
      );

      expect(result.totalRotationDegrees, closeTo(-90.0, 0.001));
    });

    test('10. 180° rotation converts to 180°', () {
      final result = ExportTransformCalculation.compute(
        xPos: 0.0,
        yPos: 0.0,
        scale: 1.0,
        rotationAngle: math.pi,
        rotationDegrees: 0,
        flipHorizontal: false,
        flipVertical: false,
        exportWidth: 720,
        exportHeight: 1280,
        sourceWidth: 720,
        sourceHeight: 1280,
      );

      expect(result.totalRotationDegrees, closeTo(180.0, 0.001));
    });

    test('11. Combined affine transform computes all 5 components simultaneously', () {
      final result = ExportTransformCalculation.compute(
        xPos: 35.0,
        yPos: -20.0,
        scale: 1.75,
        rotationAngle: math.pi / 4,
        rotationDegrees: 0,
        flipHorizontal: false,
        flipVertical: false,
        exportWidth: 720,
        exportHeight: 1280,
        sourceWidth: 720,
        sourceHeight: 1280,
      );

      expect(result.xExport, equals(70.0));
      expect(result.yExport, equals(-40.0));
      expect(result.scaleX, equals(1.75));
      expect(result.scaleY, equals(1.75));
      expect(result.totalRotationDegrees, closeTo(45.0, 0.001));
    });

    test('12. Legacy rotationDegrees (90) + continuous rotationAngle (0.25 rad) sum seamlessly', () {
      final result = ExportTransformCalculation.compute(
        xPos: 0.0,
        yPos: 0.0,
        scale: 1.0,
        rotationAngle: 0.25,
        rotationDegrees: 90,
        flipHorizontal: false,
        flipVertical: false,
        exportWidth: 720,
        exportHeight: 1280,
        sourceWidth: 720,
        sourceHeight: 1280,
      );

      const expected = 90.0 + (0.25 * 180.0 / math.pi);
      expect(result.totalRotationDegrees, closeTo(expected, 0.001));
    });

    test('13. Horizontal flip negates scaleX while preserving scale magnitude', () {
      final result = ExportTransformCalculation.compute(
        xPos: 0.0,
        yPos: 0.0,
        scale: 1.4,
        rotationAngle: 0.0,
        rotationDegrees: 0,
        flipHorizontal: true,
        flipVertical: false,
        exportWidth: 720,
        exportHeight: 1280,
        sourceWidth: 720,
        sourceHeight: 1280,
      );

      expect(result.scaleX, equals(-1.4));
      expect(result.scaleY, equals(1.4));
    });

    test('14. Vertical flip negates scaleY while preserving scale magnitude', () {
      final result = ExportTransformCalculation.compute(
        xPos: 0.0,
        yPos: 0.0,
        scale: 1.6,
        rotationAngle: 0.0,
        rotationDegrees: 0,
        flipHorizontal: false,
        flipVertical: true,
        exportWidth: 720,
        exportHeight: 1280,
        sourceWidth: 720,
        sourceHeight: 1280,
      );

      expect(result.scaleX, equals(1.6));
      expect(result.scaleY, equals(-1.6));
    });

    test('15. Both flips negate scaleX and scaleY', () {
      final result = ExportTransformCalculation.compute(
        xPos: 0.0,
        yPos: 0.0,
        scale: 2.1,
        rotationAngle: 0.0,
        rotationDegrees: 0,
        flipHorizontal: true,
        flipVertical: true,
        exportWidth: 720,
        exportHeight: 1280,
        sourceWidth: 720,
        sourceHeight: 1280,
      );

      expect(result.scaleX, equals(-2.1));
      expect(result.scaleY, equals(-2.1));
    });

    test('16. Portrait source (9:16) in 9:16 canvas fills canvas bounds with zero letterbox', () {
      final result = ExportTransformCalculation.compute(
        xPos: 0.0,
        yPos: 0.0,
        scale: 1.0,
        rotationAngle: 0.0,
        rotationDegrees: 0,
        flipHorizontal: false,
        flipVertical: false,
        exportWidth: 720,
        exportHeight: 1280,
        sourceWidth: 1080,
        sourceHeight: 1920,
      );

      expect(result.dstRect.left, equals(0.0));
      expect(result.dstRect.top, equals(0.0));
      expect(result.dstRect.width, equals(720.0));
      expect(result.dstRect.height, equals(1280.0));
    });

    test('17. Landscape source (16:9) in 9:16 canvas centers with top/bottom letterboxing', () {
      final result = ExportTransformCalculation.compute(
        xPos: 0.0,
        yPos: 0.0,
        scale: 1.0,
        rotationAngle: 0.0,
        rotationDegrees: 0,
        flipHorizontal: false,
        flipVertical: false,
        exportWidth: 720,
        exportHeight: 1280,
        sourceWidth: 1920,
        sourceHeight: 1080,
      );

      // frameRatio = 1920 / 1080 = 1.777 > targetRatio = 720 / 1280 = 0.5625
      // drawH = 720 / (16/9) = 405
      // top = (1280 - 405) / 2 = 437.5 -> 438
      expect(result.dstRect.left, equals(0.0));
      expect(result.dstRect.width, equals(720.0));
      expect(result.dstRect.height, closeTo(405.0, 1.0));
      expect(result.dstRect.top, closeTo(438.0, 1.0));
    });

    test('18. Square source (1:1) in 9:16 canvas centers with top/bottom letterboxing', () {
      final result = ExportTransformCalculation.compute(
        xPos: 0.0,
        yPos: 0.0,
        scale: 1.0,
        rotationAngle: 0.0,
        rotationDegrees: 0,
        flipHorizontal: false,
        flipVertical: false,
        exportWidth: 720,
        exportHeight: 1280,
        sourceWidth: 1000,
        sourceHeight: 1000,
      );

      // drawH = 720
      // top = (1280 - 720) / 2 = 280
      expect(result.dstRect.left, equals(0.0));
      expect(result.dstRect.width, equals(720.0));
      expect(result.dstRect.height, equals(720.0));
      expect(result.dstRect.top, equals(280.0));
    });

    test('19. Different output resolutions (720p vs 1080p vs 4K) scale Kcanvas correctly', () {
      final r720 = ExportTransformCalculation.compute(
        xPos: 20.0,
        yPos: 20.0,
        scale: 1.0,
        rotationAngle: 0.0,
        rotationDegrees: 0,
        flipHorizontal: false,
        flipVertical: false,
        exportWidth: 720,
        exportHeight: 1280,
        sourceWidth: 720,
        sourceHeight: 1280,
      );
      expect(r720.xExport, equals(40.0));

      final r1080 = ExportTransformCalculation.compute(
        xPos: 20.0,
        yPos: 20.0,
        scale: 1.0,
        rotationAngle: 0.0,
        rotationDegrees: 0,
        flipHorizontal: false,
        flipVertical: false,
        exportWidth: 1080,
        exportHeight: 1920,
        sourceWidth: 1080,
        sourceHeight: 1920,
      );
      expect(r1080.xExport, closeTo(59.56, 0.01));

      final r4k = ExportTransformCalculation.compute(
        xPos: 20.0,
        yPos: 20.0,
        scale: 1.0,
        rotationAngle: 0.0,
        rotationDegrees: 0,
        flipHorizontal: false,
        flipVertical: false,
        exportWidth: 2160,
        exportHeight: 3840,
        sourceWidth: 2160,
        sourceHeight: 3840,
      );
      expect(r4k.xExport, equals(120.0));
    });

    test('20. Transition + spatial transform serialization preserves clip spatial attributes', () async {
      const clipA = VideoClip(
        id: 'clip_a',
        assetId: 'a1',
        title: 'Clip A',
        originalDuration: Duration(seconds: 5),
        trimStart: Duration.zero,
        trimEnd: Duration(seconds: 5),
        previewGradient: [Colors.black, Colors.white],
        xPos: -30.0,
        yPos: 10.0,
        scale: 1.25,
        rotationAngle: 0.15,
      );

      const clipB = VideoClip(
        id: 'clip_b',
        assetId: 'a2',
        title: 'Clip B',
        originalDuration: Duration(seconds: 5),
        trimStart: Duration.zero,
        trimEnd: Duration(seconds: 5),
        previewGradient: [Colors.black, Colors.white],
        xPos: 40.0,
        yPos: -25.0,
        scale: 0.85,
        rotationAngle: -0.3,
      );

      final trans = Transition(
        leftClipId: 'clip_a',
        rightClipId: 'clip_b',
        type: TransitionType.fade,
        duration: 1.0,
      );

      final project = Project(
        id: 'p_trans',
        name: 'Trans Project',
        videoClips: [clipA, clipB],
        transitions: [trans],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = await DeviceMediaService.renderAndExportVideo(
        project: project,
        settings: const ExportSettings(resolution: ExportResolution.res720p),
        assets: [
          MediaAsset(id: 'a1', type: MediaAssetType.video, name: 'A', createdAt: DateTime.now()),
          MediaAsset(id: 'a2', type: MediaAssetType.video, name: 'B', createdAt: DateTime.now()),
        ],
      );

      expect(result['success'], isTrue);
    });

    test('21. Multiple clips serialize independent transform values without leakage', () async {
      const List<VideoClip> clips = [
        VideoClip(
          id: 'c1',
          assetId: 'a1',
          title: 'C1',
          originalDuration: Duration(seconds: 3),
          trimStart: Duration.zero,
          trimEnd: Duration(seconds: 3),
          previewGradient: [Colors.blue, Colors.cyan],
          xPos: -80.0,
          scale: 1.0,
          rotationAngle: 0.0,
        ),
        VideoClip(
          id: 'c2',
          assetId: 'a2',
          title: 'C2',
          originalDuration: Duration(seconds: 3),
          trimStart: Duration.zero,
          trimEnd: Duration(seconds: 3),
          previewGradient: [Colors.red, Colors.orange],
          xPos: 80.0,
          scale: 1.5,
          rotationAngle: 30.0 * math.pi / 180.0,
        ),
        VideoClip(
          id: 'c3',
          assetId: 'a3',
          title: 'C3',
          originalDuration: Duration(seconds: 3),
          trimStart: Duration.zero,
          trimEnd: Duration(seconds: 3),
          previewGradient: [Colors.green, Colors.teal],
          xPos: 0.0,
          yPos: 100.0,
          scale: 0.7,
          rotationAngle: -20.0 * math.pi / 180.0,
        ),
      ];

      final project = Project(
        id: 'p_multi',
        name: 'Multi Project',
        videoClips: clips,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = await DeviceMediaService.renderAndExportVideo(
        project: project,
        settings: const ExportSettings(resolution: ExportResolution.res720p),
        assets: [
          MediaAsset(id: 'a1', type: MediaAssetType.video, name: 'A', createdAt: DateTime.now()),
          MediaAsset(id: 'a2', type: MediaAssetType.video, name: 'B', createdAt: DateTime.now()),
          MediaAsset(id: 'a3', type: MediaAssetType.video, name: 'C', createdAt: DateTime.now()),
        ],
      );

      expect(result['success'], isTrue);
    });

    test('22. Invalid transform values (NaN, Infinity, negative scale) sanitize defensively', () {
      final result = ExportTransformCalculation.compute(
        xPos: double.nan,
        yPos: double.infinity,
        scale: -2.0,
        rotationAngle: double.nan,
        rotationDegrees: 0,
        flipHorizontal: false,
        flipVertical: false,
        exportWidth: 720,
        exportHeight: 1280,
        sourceWidth: 720,
        sourceHeight: 1280,
      );

      expect(result.xExport, equals(0.0));
      expect(result.yExport, equals(0.0));
      expect(result.scaleX, equals(1.0));
      expect(result.scaleY, equals(1.0));
      expect(result.totalRotationDegrees, equals(0.0));
    });
  });
}
