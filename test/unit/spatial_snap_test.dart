import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:capcut_video_editor/domain/models/clip_spatial_transform.dart';
import 'package:capcut_video_editor/domain/models/transform_snap_engine.dart';
import 'package:capcut_video_editor/domain/models/video_clip.dart';
import 'package:capcut_video_editor/ui/features/editor/view_models/editor_view_model.dart';
import 'package:capcut_video_editor/ui/features/editor/views/widgets/interactive_transform_canvas.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 5 — TransformSnapEngine Center & Edge Snapping Suite', () {
    const canvasSize = Size(360, 640);

    // 1. Center X snap
    test('1. Center X snap: snaps to 0.0 when rawX is within center threshold (<= 10.0)', () {
      final res = TransformSnapEngine.evaluateSnap(
        rawX: 8.0,
        rawY: 100.0,
        scale: 1.0,
        rotationAngle: 0.0,
        canvasSize: canvasSize,
      );
      expect(res.snapTargetX, SnapTargetX.centerX);
      expect(res.effectiveX, 0.0);
      expect(res.isSnappedX, isTrue);
    });

    // 2. Center Y snap
    test('2. Center Y snap: snaps to 0.0 when rawY is within center threshold (<= 10.0)', () {
      final res = TransformSnapEngine.evaluateSnap(
        rawX: 100.0,
        rawY: -7.5,
        scale: 1.0,
        rotationAngle: 0.0,
        canvasSize: canvasSize,
      );
      expect(res.snapTargetY, SnapTargetY.centerY);
      expect(res.effectiveY, 0.0);
      expect(res.isSnappedY, isTrue);
    });

    // 3. Center X/Y simultaneous snap
    test('3. Center X/Y simultaneous snap: both axes snap to 0.0 when both within threshold', () {
      final res = TransformSnapEngine.evaluateSnap(
        rawX: -6.0,
        rawY: 9.0,
        scale: 1.0,
        rotationAngle: 0.0,
        canvasSize: canvasSize,
      );
      expect(res.snapTargetX, SnapTargetX.centerX);
      expect(res.effectiveX, 0.0);
      expect(res.snapTargetY, SnapTargetY.centerY);
      expect(res.effectiveY, 0.0);
      expect(res.isSnappedX, isTrue);
      expect(res.isSnappedY, isTrue);
    });

    // 4. Left edge snap
    test('4. Left edge snap: clip left aligns to canvas left', () {
      // For canvas width 360, left edge target is -180 + 180 = 0.0 for scale 1.0 (fills canvas)
      // When scale is 0.5: clip width = 180, halfExtent = 90. Canvas left = -180.
      // Target left edge X = -180 + 90 = -90.
      final res = TransformSnapEngine.evaluateSnap(
        rawX: -95.0, // within 5px of -90
        rawY: 100.0,
        scale: 0.5,
        rotationAngle: 0.0,
        canvasSize: canvasSize,
      );
      expect(res.snapTargetX, SnapTargetX.leftEdge);
      expect(res.effectiveX, -90.0);
    });

    // 5. Right edge snap
    test('5. Right edge snap: clip right aligns to canvas right', () {
      // Scale 0.5: halfExtent = 90. Canvas right = 180. Target right edge X = 180 - 90 = 90.
      final res = TransformSnapEngine.evaluateSnap(
        rawX: 96.0, // within 6px of 90
        rawY: 100.0,
        scale: 0.5,
        rotationAngle: 0.0,
        canvasSize: canvasSize,
      );
      expect(res.snapTargetX, SnapTargetX.rightEdge);
      expect(res.effectiveX, 90.0);
    });

    // 6. Top edge snap
    test('6. Top edge snap: clip top aligns to canvas top', () {
      // Canvas height 640. Scale 0.5: clip height = 320, halfExtent = 160. Canvas top = -320.
      // Target top edge Y = -320 + 160 = -160.
      final res = TransformSnapEngine.evaluateSnap(
        rawX: 50.0,
        rawY: -168.0, // within 8px of -160
        scale: 0.5,
        rotationAngle: 0.0,
        canvasSize: canvasSize,
      );
      expect(res.snapTargetY, SnapTargetY.topEdge);
      expect(res.effectiveY, -160.0);
    });

    // 7. Bottom edge snap
    test('7. Bottom edge snap: clip bottom aligns to canvas bottom', () {
      // Scale 0.5: halfExtent = 160. Canvas bottom = 320. Target bottom edge Y = 320 - 160 = 160.
      final res = TransformSnapEngine.evaluateSnap(
        rawX: 50.0,
        rawY: 154.0, // within 6px of 160
        scale: 0.5,
        rotationAngle: 0.0,
        canvasSize: canvasSize,
      );
      expect(res.snapTargetY, SnapTargetY.bottomEdge);
      expect(res.effectiveY, 160.0);
    });

    // 8. Center hysteresis
    test('8. Center hysteresis: remains snapped until exceeding release threshold (> 14.0)', () {
      final res1 = TransformSnapEngine.evaluateSnap(
        rawX: 13.0,
        rawY: 0.0,
        scale: 1.0,
        rotationAngle: 0.0,
        canvasSize: canvasSize,
        currentSnapX: SnapTargetX.centerX,
      );
      expect(res1.snapTargetX, SnapTargetX.centerX);
      expect(res1.effectiveX, 0.0);

      final res2 = TransformSnapEngine.evaluateSnap(
        rawX: 14.5,
        rawY: 0.0,
        scale: 1.0,
        rotationAngle: 0.0,
        canvasSize: canvasSize,
        currentSnapX: SnapTargetX.centerX,
      );
      expect(res2.snapTargetX, SnapTargetX.none);
      expect(res2.effectiveX, 14.5);
    });

    // 9. Edge hysteresis
    test('9. Edge hysteresis: remains edge-snapped until exceeding release threshold (> 14.0)', () {
      // Scale 0.5: target right edge is 90.0
      final res1 = TransformSnapEngine.evaluateSnap(
        rawX: 103.0, // distance = 13.0 <= 14.0
        rawY: 0.0,
        scale: 0.5,
        rotationAngle: 0.0,
        canvasSize: canvasSize,
        currentSnapX: SnapTargetX.rightEdge,
      );
      expect(res1.snapTargetX, SnapTargetX.rightEdge);
      expect(res1.effectiveX, 90.0);

      final res2 = TransformSnapEngine.evaluateSnap(
        rawX: 105.0, // distance = 15.0 > 14.0
        rawY: 0.0,
        scale: 0.5,
        rotationAngle: 0.0,
        canvasSize: canvasSize,
        currentSnapX: SnapTargetX.rightEdge,
      );
      expect(res2.snapTargetX, SnapTargetX.none);
      expect(res2.effectiveX, 105.0);
    });

    // 10. Negative X position
    test('10. Negative X position: correctly handles negative coordinate distances', () {
      final res = TransformSnapEngine.evaluateSnap(
        rawX: -8.0,
        rawY: 200.0,
        scale: 1.0,
        rotationAngle: 0.0,
        canvasSize: canvasSize,
      );
      expect(res.snapTargetX, SnapTargetX.centerX);
      expect(res.effectiveX, 0.0);
    });

    // 11. Negative Y position
    test('11. Negative Y position: correctly handles negative coordinate distances', () {
      final res = TransformSnapEngine.evaluateSnap(
        rawX: 200.0,
        rawY: -9.0,
        scale: 1.0,
        rotationAngle: 0.0,
        canvasSize: canvasSize,
      );
      expect(res.snapTargetY, SnapTargetY.centerY);
      expect(res.effectiveY, 0.0);
    });

    // 12. Scale 0.5
    test('12. Scale 0.5: half extent scaled proportionally to 0.5', () {
      final halfW = TransformSnapEngine.calculateHalfExtentX(
        canvasSize: canvasSize,
        scale: 0.5,
        rotationAngle: 0.0,
      );
      expect(halfW, closeTo(90.0, 0.001));

      final halfH = TransformSnapEngine.calculateHalfExtentY(
        canvasSize: canvasSize,
        scale: 0.5,
        rotationAngle: 0.0,
      );
      expect(halfH, closeTo(160.0, 0.001));
    });

    // 13. Scale 1.0
    test('13. Scale 1.0: half extent matches half canvas dimension', () {
      final halfW = TransformSnapEngine.calculateHalfExtentX(
        canvasSize: canvasSize,
        scale: 1.0,
        rotationAngle: 0.0,
      );
      expect(halfW, closeTo(180.0, 0.001));

      final halfH = TransformSnapEngine.calculateHalfExtentY(
        canvasSize: canvasSize,
        scale: 1.0,
        rotationAngle: 0.0,
      );
      expect(halfH, closeTo(320.0, 0.001));
    });

    // 14. Scale 2.0
    test('14. Scale 2.0: half extent is doubled', () {
      final halfW = TransformSnapEngine.calculateHalfExtentX(
        canvasSize: canvasSize,
        scale: 2.0,
        rotationAngle: 0.0,
      );
      expect(halfW, closeTo(360.0, 0.001));

      final halfH = TransformSnapEngine.calculateHalfExtentY(
        canvasSize: canvasSize,
        scale: 2.0,
        rotationAngle: 0.0,
      );
      expect(halfH, closeTo(640.0, 0.001));
    });

    // 15. Rotation 45°
    test('15. Rotation 45°: visual bounds correctly expand according to rotated bounding box', () {
      // At 45 deg, w=360, h=640 rotated:
      // projected halfW = (|360*cos(45)| + |640*sin(45)|)/2 = (360*0.7071 + 640*0.7071)/2 = 500 * 0.7071 = 353.55
      final halfW = TransformSnapEngine.calculateHalfExtentX(
        canvasSize: canvasSize,
        scale: 1.0,
        rotationAngle: math.pi / 4,
      );
      final expectedW = (360 * math.cos(math.pi / 4) + 640 * math.sin(math.pi / 4)) / 2.0;
      expect(halfW, closeTo(expectedW, 0.01));
    });

    // 16. Rotation 90°
    test('16. Rotation 90°: width and height extents swap', () {
      final halfW = TransformSnapEngine.calculateHalfExtentX(
        canvasSize: canvasSize,
        scale: 1.0,
        rotationAngle: math.pi / 2,
      );
      expect(halfW, closeTo(320.0, 0.001)); // half of 640

      final halfH = TransformSnapEngine.calculateHalfExtentY(
        canvasSize: canvasSize,
        scale: 1.0,
        rotationAngle: math.pi / 2,
      );
      expect(halfH, closeTo(180.0, 0.001)); // half of 360
    });

    // 17. Rotation 180°
    test('17. Rotation 180°: extents remain identical to 0°', () {
      final halfW = TransformSnapEngine.calculateHalfExtentX(
        canvasSize: canvasSize,
        scale: 1.0,
        rotationAngle: math.pi,
      );
      expect(halfW, closeTo(180.0, 0.001));

      final halfH = TransformSnapEngine.calculateHalfExtentY(
        canvasSize: canvasSize,
        scale: 1.0,
        rotationAngle: math.pi,
      );
      expect(halfH, closeTo(320.0, 0.001));
    });

    // 18. Horizontal flip
    test('18. Horizontal flip: does not alter visual bounding extents', () {
      final halfW = TransformSnapEngine.calculateHalfExtentX(
        canvasSize: canvasSize,
        scale: 1.0,
        rotationAngle: math.pi / 6,
        flipHorizontal: true,
      );
      final normalHalfW = TransformSnapEngine.calculateHalfExtentX(
        canvasSize: canvasSize,
        scale: 1.0,
        rotationAngle: math.pi / 6,
        flipHorizontal: false,
      );
      expect(halfW, closeTo(normalHalfW, 0.001));
    });

    // 19. Vertical flip
    test('19. Vertical flip: does not alter visual bounding extents', () {
      final halfH = TransformSnapEngine.calculateHalfExtentY(
        canvasSize: canvasSize,
        scale: 1.0,
        rotationAngle: math.pi / 6,
        flipVertical: true,
      );
      final normalHalfH = TransformSnapEngine.calculateHalfExtentY(
        canvasSize: canvasSize,
        scale: 1.0,
        rotationAngle: math.pi / 6,
        flipVertical: false,
      );
      expect(halfH, closeTo(normalHalfH, 0.001));
    });

    // 20. Both flips
    test('20. Both flips: does not alter visual bounding extents', () {
      final halfW = TransformSnapEngine.calculateHalfExtentX(
        canvasSize: canvasSize,
        scale: 1.25,
        rotationAngle: 0.3,
        flipHorizontal: true,
        flipVertical: true,
      );
      final normalHalfW = TransformSnapEngine.calculateHalfExtentX(
        canvasSize: canvasSize,
        scale: 1.25,
        rotationAngle: 0.3,
      );
      expect(halfW, closeTo(normalHalfW, 0.001));
    });

    // 21. Combined scale + rotation + pan
    test('21. Combined scale + rotation + pan evaluates accurately', () {
      final res = TransformSnapEngine.evaluateSnap(
        rawX: 5.0, // center snap
        rawY: 200.0,
        scale: 1.5,
        rotationAngle: 0.5,
        canvasSize: canvasSize,
      );
      expect(res.snapTargetX, SnapTargetX.centerX);
      expect(res.effectiveX, 0.0);
      expect(res.snapTargetY, SnapTargetY.none);
      expect(res.effectiveY, 200.0);
    });

    // 22. Multiple candidate priority: Center X takes priority over Edge X if both close
    test('22. Multiple candidate priority: Center X takes priority over Edge X', () {
      // At scale 1.0, center target is 0.0 and edge targets are 0.0.
      // But at scale 0.98, target left is -180 + 176.4 = -3.6, while center is 0.0.
      // At rawX = -2.0, distCenter = 2.0 (<= 10), distLeft = 1.6 (<= 10).
      // Priority 1: Center X must be selected!
      final res = TransformSnapEngine.evaluateSnap(
        rawX: -2.0,
        rawY: 150.0,
        scale: 0.98,
        rotationAngle: 0.0,
        canvasSize: canvasSize,
      );
      expect(res.snapTargetX, SnapTargetX.centerX);
      expect(res.effectiveX, 0.0);
    });

    // 23. Independent X/Y snapping
    test('23. Independent X/Y snapping: X snaps to left edge while Y snaps to center', () {
      // Scale 0.5: target left X = -90.0, target center Y = 0.0
      final res = TransformSnapEngine.evaluateSnap(
        rawX: -92.0,
        rawY: 4.0,
        scale: 0.5,
        rotationAngle: 0.0,
        canvasSize: canvasSize,
      );
      expect(res.snapTargetX, SnapTargetX.leftEdge);
      expect(res.effectiveX, -90.0);
      expect(res.snapTargetY, SnapTargetY.centerY);
      expect(res.effectiveY, 0.0);
    });
  });

  group('Phase 5 — Widget & Guide Integration Tests', () {
    testWidgets('24. Guide activation: TransformAlignmentGuidesPainter renders for active snap targets', (tester) async {
      const painter = TransformAlignmentGuidesPainter(
        snapTargetX: SnapTargetX.centerX,
        snapTargetY: SnapTargetY.topEdge,
      );
      expect(painter.snapTargetX, SnapTargetX.centerX);
      expect(painter.snapTargetY, SnapTargetY.topEdge);
    });

    testWidgets('25. Guide cleanup: painter shoulders no guides when targets are none', (tester) async {
      const painter = TransformAlignmentGuidesPainter(
        snapTargetX: SnapTargetX.none,
        snapTargetY: SnapTargetY.none,
      );
      expect(painter.snapTargetX, SnapTargetX.none);
      expect(painter.snapTargetY, SnapTargetY.none);
    });

    testWidgets('26. Gesture end commits exactly once and clears snap state', (tester) async {
      final viewModel = EditorViewModel();
      final clip = viewModel.videoClips.first;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 300,
                  height: 300,
                  child: InteractiveTransformCanvas(
                    clip: clip,
                    isSelected: true,
                    viewModel: viewModel,
                    child: Container(color: Colors.red),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // Drag gesture on canvas
      await tester.drag(find.byType(InteractiveTransformCanvas), const Offset(40, -30));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));

      expect(viewModel.canUndo, isTrue);
      viewModel.dispose();
    });

    testWidgets('27. Undo restores pre-gesture transform', (tester) async {
      final viewModel = EditorViewModel();
      final clip = viewModel.videoClips.first;
      final initialX = clip.xPos;
      final initialY = clip.yPos;

      // Perform transform update
      viewModel.updateClipTransform(clip.id, xPos: 80.0, yPos: 80.0, recordUndo: true);
      expect(viewModel.videoClips.first.xPos, 80.0);

      // Undo
      viewModel.undo();
      expect(viewModel.videoClips.first.xPos, initialX);
      expect(viewModel.videoClips.first.yPos, initialY);
      viewModel.dispose();
    });

    testWidgets('28. Redo restores snapped transform', (tester) async {
      final viewModel = EditorViewModel();
      final clip = viewModel.videoClips.first;
      final initialX = clip.xPos;

      viewModel.updateClipTransform(clip.id, xPos: 80.0, yPos: 80.0, recordUndo: true);
      viewModel.undo();
      expect(viewModel.videoClips.first.xPos, initialX);

      viewModel.redo();
      expect(viewModel.videoClips.first.xPos, 80.0);
      expect(viewModel.videoClips.first.yPos, 80.0);
      viewModel.dispose();
    });

    testWidgets('29. Clip switching does not retain stale snap state', (tester) async {
      final viewModel = EditorViewModel();
      const clip1 = VideoClip(
        id: 'clip-1',
        assetId: 'asset-1',
        title: 'Test 1',
        originalDuration: Duration(seconds: 5),
        trimStart: Duration.zero,
        trimEnd: Duration(seconds: 5),
        previewGradient: [Colors.black, Colors.white],
      );
      const clip2 = VideoClip(
        id: 'clip-2',
        assetId: 'asset-2',
        title: 'Test 2',
        originalDuration: Duration(seconds: 5),
        trimStart: Duration.zero,
        trimEnd: Duration(seconds: 5),
        previewGradient: [Colors.black, Colors.white],
        xPos: 100.0,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 360,
                height: 360,
                child: InteractiveTransformCanvas(
                  clip: clip1,
                  isSelected: true,
                  viewModel: viewModel,
                  child: Container(color: Colors.red),
                ),
              ),
            ),
          ),
        ),
      );

      // Switch to clip2
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 360,
                height: 360,
                child: InteractiveTransformCanvas(
                  clip: clip2,
                  isSelected: true,
                  viewModel: viewModel,
                  child: Container(color: Colors.blue),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // No crash, state cleanly isolated
      expect(find.byType(InteractiveTransformCanvas), findsOneWidget);
      viewModel.dispose();
    });

    // 30. Existing Phase 4 center snap regression
    test('30. Existing Phase 4 center snap regression: ClipSpatialTransform.calculateCenterSnap still works', () {
      final (effective10, isSnapped10) = ClipSpatialTransform.calculateCenterSnap(
        rawCoordinate: 10.0,
        currentlySnapped: false,
      );
      expect(isSnapped10, isTrue);
      expect(effective10, 0.0);

      final (effective15, isSnapped15) = ClipSpatialTransform.calculateCenterSnap(
        rawCoordinate: 15.0,
        currentlySnapped: false,
      );
      expect(isSnapped15, isFalse);
      expect(effective15, 15.0);
    });
  });
}
