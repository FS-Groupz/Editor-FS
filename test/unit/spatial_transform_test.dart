import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:capcut_video_editor/domain/models/clip_spatial_transform.dart';
import 'package:capcut_video_editor/domain/models/video_clip.dart';
import 'package:capcut_video_editor/ui/features/editor/providers/spatial_transform_provider.dart';
import 'package:capcut_video_editor/ui/features/editor/view_models/editor_view_model.dart';

VideoClip createTestClip({
  String id = 'test-clip',
  String assetId = 'test-asset',
  String title = 'Test Clip',
  Duration originalDuration = const Duration(seconds: 10),
  Duration trimStart = Duration.zero,
  Duration trimEnd = const Duration(seconds: 10),
  List<Color> previewGradient = const [Colors.blue, Colors.purple],
  double speed = 1.0,
  double volume = 1.0,
  int rotationDegrees = 0,
  bool flipHorizontal = false,
  bool flipVertical = false,
  double opacity = 1.0,
  bool isReversed = false,
  bool isFrozen = false,
  double xPos = 0.0,
  double yPos = 0.0,
  double scale = 1.0,
  double rotationAngle = 0.0,
}) {
  return VideoClip(
    id: id,
    assetId: assetId,
    title: title,
    originalDuration: originalDuration,
    trimStart: trimStart,
    trimEnd: trimEnd,
    previewGradient: previewGradient,
    speed: speed,
    volume: volume,
    rotationDegrees: rotationDegrees,
    flipHorizontal: flipHorizontal,
    flipVertical: flipVertical,
    opacity: opacity,
    isReversed: isReversed,
    isFrozen: isFrozen,
    xPos: xPos,
    yPos: yPos,
    scale: scale,
    rotationAngle: rotationAngle,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MediaClip / VideoClip Spatial Domain Model', () {
    test('1. Default spatial transform values are xPos=0.0, yPos=0.0, scale=1.0, rotationAngle=0.0', () {
      final clip = createTestClip(id: 'clip-1', assetId: 'asset-1');

      expect(clip.xPos, equals(0.0));
      expect(clip.yPos, equals(0.0));
      expect(clip.scale, equals(1.0));
      expect(clip.rotationAngle, equals(0.0));

      // Test MediaClip typedef alias compatibility
      final MediaClip mediaClip = clip;
      expect(mediaClip.xPos, equals(0.0));
      expect(mediaClip.scale, equals(1.0));

      final transform = ClipSpatialTransform.fromClip(clip);
      expect(transform.clipId, equals('clip-1'));
      expect(transform.xPos, equals(0.0));
      expect(transform.yPos, equals(0.0));
      expect(transform.scale, equals(1.0));
      expect(transform.rotationAngle, equals(0.0));
    });

    test('2. Scale clamping and validation prevents non-positive, NaN, and Infinity', () {
      expect(ClipSpatialTransform.sanitizeScale(1.5), equals(1.5));
      expect(ClipSpatialTransform.sanitizeScale(0.0), equals(1.0));
      expect(ClipSpatialTransform.sanitizeScale(-2.0), equals(1.0));
      expect(ClipSpatialTransform.sanitizeScale(double.nan), equals(1.0));
      expect(ClipSpatialTransform.sanitizeScale(double.infinity), equals(1.0));
      expect(ClipSpatialTransform.sanitizeScale(double.negativeInfinity), equals(1.0));

      // Clamping limits [0.05, 20.0]
      expect(ClipSpatialTransform.sanitizeScale(0.01), equals(ClipSpatialTransform.minScale));
      expect(ClipSpatialTransform.sanitizeScale(50.0), equals(ClipSpatialTransform.maxScale));

      // With custom fallback
      expect(ClipSpatialTransform.sanitizeScale(-1.0, fallback: 2.5), equals(2.5));
      expect(ClipSpatialTransform.sanitizeScale(double.nan, fallback: 1.8), equals(1.8));
    });

    test('3. Position and rotation sanitizers reject NaN and non-finite values', () {
      expect(ClipSpatialTransform.sanitizePosition(100.0), equals(100.0));
      expect(ClipSpatialTransform.sanitizePosition(double.nan, fallback: 15.0), equals(15.0));
      expect(ClipSpatialTransform.sanitizePosition(double.infinity, fallback: 20.0), equals(20.0));

      expect(ClipSpatialTransform.sanitizeRotation(math.pi / 2), closeTo(1.57079, 0.001));
      expect(ClipSpatialTransform.sanitizeRotation(double.nan, fallback: 0.5), equals(0.5));
      expect(ClipSpatialTransform.sanitizeRotation(double.infinity, fallback: 1.0), equals(1.0));
    });

    test('4. copyWith and applyTo cleanly propagate spatial values', () {
      const transform = ClipSpatialTransform(clipId: 'c1');
      final updated = transform.copyWith(
        xPos: 45.0,
        yPos: -30.0,
        scale: 2.0,
        rotationAngle: 0.785,
      );

      expect(updated.xPos, equals(45.0));
      expect(updated.yPos, equals(-30.0));
      expect(updated.scale, equals(2.0));
      expect(updated.rotationAngle, equals(0.785));

      final originalClip = createTestClip(id: 'c1', assetId: 'a1');
      final transformedClip = updated.applyTo(originalClip);
      expect(transformedClip.xPos, equals(45.0));
      expect(transformedClip.yPos, equals(-30.0));
      expect(transformedClip.scale, equals(2.0));
      expect(transformedClip.rotationAngle, equals(0.785));
    });

    test('5. Existing VideoClip properties are preserved when spatial properties change', () {
      final clip = createTestClip(
        id: 'c-test',
        assetId: 'a-test',
        originalDuration: const Duration(seconds: 10),
        trimStart: const Duration(seconds: 1),
        trimEnd: const Duration(seconds: 9),
        speed: 1.5,
        volume: 0.8,
        rotationDegrees: 90,
        flipHorizontal: true,
        flipVertical: false,
        opacity: 0.75,
        isReversed: true,
        isFrozen: false,
      );

      final modified = clip.copyWith(
        xPos: 120.0,
        yPos: -80.0,
        scale: 1.4,
        rotationAngle: 0.35,
      );

      expect(modified.id, equals('c-test'));
      expect(modified.assetId, equals('a-test'));
      expect(modified.originalDuration, equals(const Duration(seconds: 10)));
      expect(modified.trimStart, equals(const Duration(seconds: 1)));
      expect(modified.trimEnd, equals(const Duration(seconds: 9)));
      expect(modified.speed, equals(1.5));
      expect(modified.volume, equals(0.8));
      expect(modified.rotationDegrees, equals(90));
      expect(modified.flipHorizontal, isTrue);
      expect(modified.flipVertical, isFalse);
      expect(modified.opacity, equals(0.75));
      expect(modified.isReversed, isTrue);
      expect(modified.isFrozen, isFalse);
      expect(modified.xPos, equals(120.0));
      expect(modified.yPos, equals(-80.0));
      expect(modified.scale, equals(1.4));
      expect(modified.rotationAngle, equals(0.35));
    });

    test('6. JSON serialization includes spatial transform attributes', () {
      final clip = createTestClip(
        id: 'c-json',
        assetId: 'a-json',
        xPos: 35.5,
        yPos: -42.0,
        scale: 1.75,
        rotationAngle: 1.25,
      );

      final json = clip.toJson();
      expect(json['xPos'], equals(35.5));
      expect(json['yPos'], equals(-42.0));
      expect(json['scale'], equals(1.75));
      expect(json['rotationAngle'], equals(1.25));

      final deserialized = VideoClip.fromJson(json);
      expect(deserialized.xPos, equals(35.5));
      expect(deserialized.yPos, equals(-42.0));
      expect(deserialized.scale, equals(1.75));
      expect(deserialized.rotationAngle, equals(1.25));
    });

    test('7. Backward compatibility: old JSON without spatial fields defaults safely', () {
      final legacyJson = {
        'id': 'legacy-clip',
        'assetId': 'legacy-asset',
        'title': 'Legacy Video',
        'originalDurationMs': 4000,
        'trimStartMs': 0,
        'trimEndMs': 4000,
        'speed': 1.0,
        'volume': 1.0,
        'rotationDegrees': 0,
        'previewGradient': [0xFF123456, 0xFF654321],
      };

      final clip = VideoClip.fromJson(legacyJson);
      expect(clip.xPos, equals(0.0));
      expect(clip.yPos, equals(0.0));
      expect(clip.scale, equals(1.0));
      expect(clip.rotationAngle, equals(0.0));

      final transformFromJson = ClipSpatialTransform.fromJson({});
      expect(transformFromJson.clipId, isEmpty);
      expect(transformFromJson.xPos, equals(0.0));
      expect(transformFromJson.yPos, equals(0.0));
      expect(transformFromJson.scale, equals(1.0));
      expect(transformFromJson.rotationAngle, equals(0.0));
    });
  });

  group('EditorViewModel Spatial Transformations', () {
    late EditorViewModel viewModel;

    setUp(() {
      viewModel = EditorViewModel();
    });

    tearDown(() {
      viewModel.dispose();
    });

    test('8. updateClipPosition updates coordinates and records undo snapshot', () {
      expect(viewModel.videoClips.isNotEmpty, isTrue);
      final targetClipId = viewModel.videoClips.first.id;

      viewModel.updateClipPosition(targetClipId, 50.0, -25.0);

      final updatedClip = viewModel.videoClips.first;
      expect(updatedClip.xPos, equals(50.0));
      expect(updatedClip.yPos, equals(-25.0));
      expect(viewModel.canUndo, isTrue);

      // Undo restores original position
      viewModel.undo();
      expect(viewModel.videoClips.first.xPos, equals(0.0));
      expect(viewModel.videoClips.first.yPos, equals(0.0));
      expect(viewModel.canRedo, isTrue);

      // Redo re-applies the updated position
      viewModel.redo();
      expect(viewModel.videoClips.first.xPos, equals(50.0));
      expect(viewModel.videoClips.first.yPos, equals(-25.0));
    });

    test('9. updateClipScale validates and clamps scale with undo support', () {
      final targetClipId = viewModel.videoClips.first.id;

      viewModel.updateClipScale(targetClipId, 2.5);
      expect(viewModel.videoClips.first.scale, equals(2.5));

      // Clamping upper boundary
      viewModel.updateClipScale(targetClipId, 100.0);
      expect(viewModel.videoClips.first.scale, equals(20.0));

      // Clamping lower boundary
      viewModel.updateClipScale(targetClipId, -5.0);
      expect(viewModel.videoClips.first.scale, equals(20.0)); // Invalid non-positive ignored/retained fallback
    });

    test('10. updateClipRotation updates angle in radians', () {
      final targetClipId = viewModel.videoClips.first.id;

      viewModel.updateClipRotation(targetClipId, 1.5708);
      expect(viewModel.videoClips.first.rotationAngle, closeTo(1.5708, 0.0001));

      // Reset
      viewModel.resetClipTransform(targetClipId);
      expect(viewModel.videoClips.first.rotationAngle, equals(0.0));
      expect(viewModel.videoClips.first.xPos, equals(0.0));
      expect(viewModel.videoClips.first.scale, equals(1.0));
    });

    test('11. updateClipTransform atomically modifies all transform properties', () {
      final targetClipId = viewModel.videoClips.first.id;

      viewModel.updateClipTransform(
        targetClipId,
        xPos: 15.0,
        yPos: 30.0,
        scale: 1.8,
        rotationAngle: 0.5,
      );

      final clip = viewModel.videoClips.first;
      expect(clip.xPos, equals(15.0));
      expect(clip.yPos, equals(30.0));
      expect(clip.scale, equals(1.8));
      expect(clip.rotationAngle, equals(0.5));
    });

    test('12. Selected clip convenience methods delegate correctly', () {
      viewModel.selectClip(0);
      expect(viewModel.selectedClip, isNotNull);

      viewModel.updateSelectedClipPosition(12.0, 24.0);
      expect(viewModel.selectedClip!.xPos, equals(12.0));
      expect(viewModel.selectedClip!.yPos, equals(24.0));

      viewModel.updateSelectedClipScale(1.3);
      expect(viewModel.selectedClip!.scale, equals(1.3));

      viewModel.updateSelectedClipRotation(0.7);
      expect(viewModel.selectedClip!.rotationAngle, equals(0.7));

      viewModel.resetSelectedClipTransform();
      expect(viewModel.selectedClip!.xPos, equals(0.0));
      expect(viewModel.selectedClip!.scale, equals(1.0));
    });

    test('13. recordUndo=false does not push snapshot during high-frequency dragging', () {
      final targetClipId = viewModel.videoClips.first.id;
      final initialCanUndo = viewModel.canUndo;

      // Simulate dragging frames with recordUndo = false
      viewModel.updateClipPosition(targetClipId, 5.0, 5.0, recordUndo: false);
      viewModel.updateClipPosition(targetClipId, 10.0, 10.0, recordUndo: false);
      viewModel.updateClipPosition(targetClipId, 15.0, 15.0, recordUndo: false);

      expect(viewModel.videoClips.first.xPos, equals(15.0));
      expect(viewModel.canUndo, equals(initialCanUndo));

      // On gesture end, commit final position with recordUndo = true
      viewModel.updateClipPosition(targetClipId, 20.0, 20.0, recordUndo: true);
      expect(viewModel.videoClips.first.xPos, equals(20.0));
      expect(viewModel.canUndo, isTrue);
    });

    test('14. Clip isolation: modifying clip A does not modify clip B', () {
      if (viewModel.videoClips.length < 2) {
        viewModel.addNewClip();
      }
      expect(viewModel.videoClips.length, greaterThanOrEqualTo(2));

      final clipAId = viewModel.videoClips[0].id;

      viewModel.updateClipPosition(clipAId, 100.0, 200.0);
      viewModel.updateClipScale(clipAId, 3.0);
      viewModel.updateClipRotation(clipAId, 1.2);

      final clipA = viewModel.videoClips[0];
      final clipB = viewModel.videoClips[1];

      expect(clipA.xPos, equals(100.0));
      expect(clipA.scale, equals(3.0));
      expect(clipA.rotationAngle, equals(1.2));

      // Clip B remains untouched
      expect(clipB.xPos, equals(0.0));
      expect(clipB.yPos, equals(0.0));
      expect(clipB.scale, equals(1.0));
      expect(clipB.rotationAngle, equals(0.0));
    });
  });

  group('Riverpod Spatial State Management', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('15. SpatialTransformMapNotifier updates and resets individual clip transforms', () {
      final notifier = container.read(spatialTransformMapProvider.notifier);

      notifier.updatePosition('clip-1', 40.0, -60.0);
      notifier.updateScale('clip-1', 1.6);
      notifier.updateRotation('clip-1', 0.85);

      final transform = notifier.getTransform('clip-1');
      expect(transform.clipId, equals('clip-1'));
      expect(transform.xPos, equals(40.0));
      expect(transform.yPos, equals(-60.0));
      expect(transform.scale, equals(1.6));
      expect(transform.rotationAngle, equals(0.85));

      // Reset
      notifier.reset('clip-1');
      final resetTransform = notifier.getTransform('clip-1');
      expect(resetTransform.xPos, equals(0.0));
      expect(resetTransform.yPos, equals(0.0));
      expect(resetTransform.scale, equals(1.0));
      expect(resetTransform.rotationAngle, equals(0.0));
    });

    test('16. syncFromClips synchronizes domain clips with Riverpod map', () {
      final clips = [
        createTestClip(id: 'c1', assetId: 'a1', xPos: 10.0, scale: 1.2),
        createTestClip(id: 'c2', assetId: 'a2', yPos: -20.0, rotationAngle: 0.4),
      ];

      final notifier = container.read(spatialTransformMapProvider.notifier);
      notifier.syncFromClips(clips);

      final t1 = notifier.getTransform('c1');
      final t2 = notifier.getTransform('c2');

      expect(t1.xPos, equals(10.0));
      expect(t1.scale, equals(1.2));
      expect(t2.yPos, equals(-20.0));
      expect(t2.rotationAngle, equals(0.4));
    });

    test('17. ClipSpatialTransformController mutates per-clip state', () {
      final controller = container.read(clipSpatialTransformControllerProvider('clip-ctrl'));

      controller.updatePosition(33.0, 66.0);
      controller.updateScale(1.4);
      controller.updateRotation(1.1);

      expect(controller.current.xPos, equals(33.0));
      expect(controller.current.yPos, equals(66.0));
      expect(controller.current.scale, equals(1.4));
      expect(controller.current.rotationAngle, equals(1.1));

      controller.reset();
      expect(controller.current.xPos, equals(0.0));
      expect(controller.current.scale, equals(1.0));
    });

    test('18. Selective watching isolation: mutating clip A does NOT notify clip B listeners', () async {
      int clip1NotifyCount = 0;
      int clip2NotifyCount = 0;

      // Subscribe listeners to specific clips
      container.listen<ClipSpatialTransform>(
        clipSpatialTransformProvider('clip-1'),
        (previous, next) {
          clip1NotifyCount++;
        },
        fireImmediately: false,
      );

      container.listen<ClipSpatialTransform>(
        clipSpatialTransformProvider('clip-2'),
        (previous, next) {
          clip2NotifyCount++;
        },
        fireImmediately: false,
      );

      // Mutate only clip-1
      final notifier = container.read(spatialTransformMapProvider.notifier);
      notifier.updatePosition('clip-1', 25.0, 50.0);
      await container.pump();

      // Verify that ONLY clip-1 listener was notified
      expect(clip1NotifyCount, equals(1));
      expect(clip2NotifyCount, equals(0));

      // Mutate clip-1 again with scale
      notifier.updateScale('clip-1', 1.8);
      await container.pump();
      expect(clip1NotifyCount, equals(2));
      expect(clip2NotifyCount, equals(0));

      // Mutate clip-2 now
      notifier.updatePosition('clip-2', -15.0, -30.0);
      await container.pump();
      expect(clip1NotifyCount, equals(2));
      expect(clip2NotifyCount, equals(1));
    });
  });
}
