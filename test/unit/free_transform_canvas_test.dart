import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:capcut_video_editor/domain/models/clip_spatial_transform.dart';
import 'package:capcut_video_editor/domain/models/video_clip.dart';
import 'package:capcut_video_editor/ui/features/editor/providers/spatial_transform_provider.dart';
import 'package:capcut_video_editor/ui/features/editor/view_models/editor_view_model.dart';
import 'package:capcut_video_editor/ui/features/editor/views/widgets/interactive_transform_canvas.dart';

VideoClip createTestVideoClip({
  String id = 'clip-test-1',
  String assetId = 'asset-1',
  String title = 'Test Clip',
  double xPos = 0.0,
  double yPos = 0.0,
  double scale = 1.0,
  double rotationAngle = 0.0,
  int rotationDegrees = 0,
  bool flipHorizontal = false,
  bool flipVertical = false,
}) {
  return VideoClip(
    id: id,
    assetId: assetId,
    title: title,
    originalDuration: const Duration(seconds: 10),
    trimStart: Duration.zero,
    trimEnd: const Duration(seconds: 10),
    previewGradient: const [Colors.blue, Colors.purple],
    xPos: xPos,
    yPos: yPos,
    scale: scale,
    rotationAngle: rotationAngle,
    rotationDegrees: rotationDegrees,
    flipHorizontal: flipHorizontal,
    flipVertical: flipVertical,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 2 — Matrix4 Spatial Transform Math & Composition', () {
    test('1. Matrix4 generation from defaults (identity translation, 0 rotation, 1.0 scale)', () {
      const transform = ClipSpatialTransform(clipId: 'c1');
      final matrix = transform.toMatrix4();

      expect(matrix.storage[12], equals(0.0)); // tx
      expect(matrix.storage[13], equals(0.0)); // ty
      expect(matrix.storage[14], equals(0.0)); // tz
      expect(matrix.storage[0], equals(1.0)); // m00
      expect(matrix.storage[5], equals(1.0)); // m11
      expect(matrix.storage[10], equals(1.0)); // m22
      expect(matrix.storage[15], equals(1.0)); // m33
    });

    test('2. Matrix4 with translation (xPos, yPos)', () {
      const transform = ClipSpatialTransform(clipId: 'c1', xPos: 45.5, yPos: -82.0);
      final matrix = transform.toMatrix4();

      expect(matrix.storage[12], closeTo(45.5, 0.001));
      expect(matrix.storage[13], closeTo(-82.0, 0.001));
      expect(matrix.storage[14], equals(0.0));
    });

    test('3. Matrix4 with scale (scale)', () {
      const transform = ClipSpatialTransform(clipId: 'c1', scale: 2.75);
      final matrix = transform.toMatrix4();

      expect(matrix.getMaxScaleOnAxis(), closeTo(2.75, 0.001));
    });

    test('4. Matrix4 with continuous rotation (rotationAngle)', () {
      const angle = math.pi / 3; // 60 degrees
      const transform = ClipSpatialTransform(clipId: 'c1', rotationAngle: angle);
      final matrix = transform.toMatrix4();

      expect(matrix.storage[0], closeTo(math.cos(angle), 0.001));
      expect(matrix.storage[1], closeTo(math.sin(angle), 0.001));
      expect(matrix.storage[4], closeTo(-math.sin(angle), 0.001));
      expect(matrix.storage[5], closeTo(math.cos(angle), 0.001));
    });

    test('5. Matrix4 composition with legacy rotationDegrees (90, 180, 270) + continuous rotationAngle', () {
      const continuous = 0.25; // radians
      for (final deg in [90, 180, 270]) {
        const transform = ClipSpatialTransform(clipId: 'c1', rotationAngle: continuous);
        final matrix = transform.toMatrix4(legacyRotationDegrees: deg);

        final expectedAngle = (deg * math.pi / 180.0) + continuous;
        expect(matrix.storage[0], closeTo(math.cos(expectedAngle), 0.001));
        expect(matrix.storage[1], closeTo(math.sin(expectedAngle), 0.001));
      }
    });

    test('6. Matrix4 composition with horizontal and vertical flip', () {
      const transform = ClipSpatialTransform(clipId: 'c1', scale: 1.5);
      final flippedH = transform.toMatrix4(flipHorizontal: true);
      expect(flippedH.storage[0], closeTo(-1.5, 0.001));
      expect(flippedH.storage[5], closeTo(1.5, 0.001));

      final flippedV = transform.toMatrix4(flipVertical: true);
      expect(flippedV.storage[0], closeTo(1.5, 0.001));
      expect(flippedV.storage[5], closeTo(-1.5, 0.001));

      final flippedBoth = transform.toMatrix4(flipHorizontal: true, flipVertical: true);
      expect(flippedBoth.storage[0], closeTo(-1.5, 0.001));
      expect(flippedBoth.storage[5], closeTo(-1.5, 0.001));
    });
  });

  group('Phase 2 — Riverpod Spatial State & Clamping', () {
    test('7. 1-finger pan gesture correctly calculates delta from baseline and updates Riverpod map', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(spatialTransformMapProvider.notifier);
      final clip = createTestVideoClip(id: 'clip-pan', xPos: 10.0, yPos: 20.0);
      notifier.registerClip(clip);

      // Simulate pan update (+15.0 x, -8.0 y)
      notifier.updateTransform('clip-pan', xPos: 10.0 + 15.0, yPos: 20.0 - 8.0);
      final current = notifier.getTransform('clip-pan');
      expect(current.xPos, equals(25.0));
      expect(current.yPos, equals(12.0));
    });

    test('8. 2-finger pinch gesture correctly multiplies baseline scale and updates Riverpod map', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(spatialTransformMapProvider.notifier);
      final clip = createTestVideoClip(id: 'clip-pinch', scale: 1.2);
      notifier.registerClip(clip);

      // Baseline 1.2 * gesture factor 1.5 = 1.8
      notifier.updateTransform('clip-pinch', scale: 1.2 * 1.5);
      final current = notifier.getTransform('clip-pinch');
      expect(current.scale, closeTo(1.8, 0.001));
    });

    test('9. 2-finger rotation gesture correctly adds delta to baseline rotation and updates Riverpod map', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(spatialTransformMapProvider.notifier);
      final clip = createTestVideoClip(id: 'clip-rot', rotationAngle: 0.2);
      notifier.registerClip(clip);

      // Baseline 0.2 + delta 0.45 = 0.65
      notifier.updateTransform('clip-rot', rotationAngle: 0.2 + 0.45);
      final current = notifier.getTransform('clip-rot');
      expect(current.rotationAngle, closeTo(0.65, 0.001));
    });

    test('10. Combined pan + pinch + rotation updates all 4 components simultaneously without cumulative drift', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(spatialTransformMapProvider.notifier);
      final clip = createTestVideoClip(id: 'clip-combined', xPos: 0.0, yPos: 0.0, scale: 1.0, rotationAngle: 0.0);
      notifier.registerClip(clip);

      notifier.updateTransform(
        'clip-combined',
        xPos: 32.0,
        yPos: -18.5,
        scale: 1.45,
        rotationAngle: 0.785,
      );

      final current = notifier.getTransform('clip-combined');
      expect(current.xPos, equals(32.0));
      expect(current.yPos, equals(-18.5));
      expect(current.scale, equals(1.45));
      expect(current.rotationAngle, equals(0.785));
    });

    test('11. Scale clamping at minScale (0.05) and maxScale (20.0)', () {
      expect(ClipSpatialTransform.sanitizeScale(0.001), equals(0.05));
      expect(ClipSpatialTransform.sanitizeScale(100.0), equals(20.0));
      expect(ClipSpatialTransform.sanitizeScale(0.05), equals(0.05));
      expect(ClipSpatialTransform.sanitizeScale(20.0), equals(20.0));
    });

    test('12. NaN and Infinity inputs to position, scale, rotation are sanitized to safe fallbacks', () {
      expect(ClipSpatialTransform.sanitizePosition(double.nan, fallback: 42.0), equals(42.0));
      expect(ClipSpatialTransform.sanitizePosition(double.infinity, fallback: 10.0), equals(10.0));
      expect(ClipSpatialTransform.sanitizeScale(double.nan, fallback: 1.5), equals(1.5));
      expect(ClipSpatialTransform.sanitizeScale(double.negativeInfinity, fallback: 2.0), equals(2.0));
      expect(ClipSpatialTransform.sanitizeRotation(double.nan, fallback: 0.5), equals(0.5));
      expect(ClipSpatialTransform.sanitizeRotation(double.infinity, fallback: 1.1), equals(1.1));
    });
  });

  group('Phase 2 — Undo / Redo & ViewModel Integration', () {
    test('13. Gesture in-flight: Riverpod state updates continuously, but NO undo snapshot is added', () {
      final vm = EditorViewModel();
      final clip = vm.videoClips.first;
      final initialUndoCount = vm.canUndo ? 1 : 0;

      // In-flight high-frequency update with recordUndo: false
      vm.updateClipTransform(
        clip.id,
        xPos: 15.0,
        yPos: 25.0,
        scale: 1.3,
        rotationAngle: 0.4,
        recordUndo: false,
      );

      expect(vm.videoClips.first.xPos, equals(15.0));
      expect(vm.canUndo ? 1 : 0, equals(initialUndoCount));
    });

    test('14. Gesture completion (onScaleEnd): exactly ONE undo snapshot is committed with final transform state', () {
      final vm = EditorViewModel();
      final clip = vm.videoClips.first;
      expect(vm.canUndo, isFalse);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(spatialTransformMapProvider.notifier);
      notifier.registerClip(clip);

      // 1. Simulate in-flight updates during gesture: only Riverpod map updates, ViewModel untouched
      for (int i = 1; i <= 5; i++) {
        notifier.updateTransform(
          clip.id,
          xPos: i * 5.0,
          yPos: i * 5.0,
          scale: 1.0 + (i * 0.1),
          rotationAngle: i * 0.05,
        );
      }
      expect(vm.canUndo, isFalse);
      expect(vm.videoClips.first.xPos, equals(0.0)); // VM still at baseline

      // 2. Gesture ends (onScaleEnd): single snapshot committed with final values
      final finalTransform = notifier.getTransform(clip.id);
      vm.updateClipTransform(
        clip.id,
        xPos: finalTransform.xPos,
        yPos: finalTransform.yPos,
        scale: finalTransform.scale,
        rotationAngle: finalTransform.rotationAngle,
        recordUndo: true,
      );

      expect(vm.canUndo, isTrue);
      expect(vm.videoClips.first.xPos, equals(25.0));

      // 3. Undo restores baseline (0.0, 1.0)
      vm.undo();
      expect(vm.videoClips.first.xPos, equals(0.0));
      expect(vm.videoClips.first.scale, equals(1.0));

      // 4. Redo restores transformed state (25.0, 1.5)
      vm.redo();
      expect(vm.videoClips.first.xPos, equals(25.0));
      expect(vm.videoClips.first.scale, equals(1.5));
    });

    test('15. Reset transform: resets xPos=0, yPos=0, scale=1.0, rotationAngle=0.0 and commits undo snapshot', () {
      final vm = EditorViewModel();
      final clip = vm.videoClips.first;

      vm.updateClipTransform(clip.id, xPos: 50.0, yPos: 50.0, scale: 2.0, rotationAngle: 1.0, recordUndo: true);
      expect(vm.videoClips.first.xPos, equals(50.0));

      vm.resetClipTransform(clip.id);
      expect(vm.videoClips.first.xPos, equals(0.0));
      expect(vm.videoClips.first.yPos, equals(0.0));
      expect(vm.videoClips.first.scale, equals(1.0));
      expect(vm.videoClips.first.rotationAngle, equals(0.0));

      // Undo brings back 50.0
      vm.undo();
      expect(vm.videoClips.first.xPos, equals(50.0));
    });
  });

  group('Phase 2 — UI Bounding Box & Control Dot Rendering', () {
    testWidgets('16. Bounding box widget is visible (thin cyan border) when isSelected == true', (tester) async {
      final vm = EditorViewModel();
      final clip = vm.videoClips.first;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 300,
                  height: 200,
                  child: InteractiveTransformCanvas(
                    clip: clip,
                    isSelected: true,
                    viewModel: vm,
                    child: Container(color: Colors.red),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find Container with cyan border (#00E5FF)
      final cyanBorderFinder = find.byWidgetPredicate((widget) {
        if (widget is Container && widget.decoration is BoxDecoration) {
          final box = widget.decoration as BoxDecoration;
          if (box.border != null) {
            return box.border!.top.color == const Color(0xFF00E5FF);
          }
        }
        return false;
      });

      expect(cyanBorderFinder, findsOneWidget);
    });

    testWidgets('17. Bounding box widget is NOT visible when isSelected == false', (tester) async {
      final vm = EditorViewModel();
      final clip = vm.videoClips.first;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 300,
                  height: 200,
                  child: InteractiveTransformCanvas(
                    clip: clip,
                    isSelected: false,
                    viewModel: vm,
                    child: Container(color: Colors.red),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cyanBorderFinder = find.byWidgetPredicate((widget) {
        if (widget is Container && widget.decoration is BoxDecoration) {
          final box = widget.decoration as BoxDecoration;
          if (box.border != null) {
            return box.border!.top.color == const Color(0xFF00E5FF);
          }
        }
        return false;
      });

      expect(cyanBorderFinder, findsNothing);
    });

    testWidgets('18. Control dot/handle is visible when isSelected == true, not visible when isSelected == false', (tester) async {
      final vm = EditorViewModel();
      final clip = vm.videoClips.first;

      // When isSelected == true: control dot (12x12 circle) is rendered
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 300,
                  height: 200,
                  child: InteractiveTransformCanvas(
                    clip: clip,
                    isSelected: true,
                    viewModel: vm,
                    child: Container(color: Colors.red),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final controlDotFinder = find.byWidgetPredicate((widget) {
        if (widget is Container && widget.decoration is BoxDecoration) {
          final box = widget.decoration as BoxDecoration;
          return box.shape == BoxShape.circle && box.color == const Color(0xFF00E5FF);
        }
        return false;
      });

      expect(controlDotFinder, findsOneWidget);

      // When isSelected == false: control dot is not rendered
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 300,
                  height: 200,
                  child: InteractiveTransformCanvas(
                    clip: clip,
                    isSelected: false,
                    viewModel: vm,
                    child: Container(color: Colors.red),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(controlDotFinder, findsNothing);
    });
  });
}
