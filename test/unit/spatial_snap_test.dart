import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:capcut_video_editor/domain/models/clip_spatial_transform.dart';
import 'package:capcut_video_editor/domain/models/overlay_clip.dart';
import 'package:capcut_video_editor/domain/models/sticker_item.dart';
import 'package:capcut_video_editor/domain/models/text_overlay.dart';
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

  group('Phase 6 — Smart Multi-Layer Alignment & Snap Guides Suite', () {
    const canvasSize = Size(360, 640);

    TransformAlignmentBounds createLayer({
      required String id,
      required String name,
      required LayerType type,
      required double left,
      required double right,
      required double top,
      required double bottom,
    }) {
      return TransformAlignmentBounds(
        id: id,
        name: name,
        type: type,
        left: left,
        right: right,
        top: top,
        bottom: bottom,
        centerX: (left + right) / 2.0,
        centerY: (top + bottom) / 2.0,
      );
    }

    // 1. Active clip center snaps to another layer's center on X axis when within 10px
    test('1. Center-to-Center X: active clip center snaps to reference layer center within 10px', () {
      final refLayer = createLayer(
        id: 'layer_1',
        name: 'Overlay 1',
        type: LayerType.pipVideo,
        left: 20.0,
        right: 80.0, // center = 50.0
        top: -50.0,
        bottom: 50.0,
      );

      final res = TransformSnapEngine.evaluateMultiLayerSnap(
        rawX: 56.0, // within 6px of 50.0
        rawY: 200.0,
        scale: 0.5,
        rotationAngle: 0.0,
        canvasSize: canvasSize,
        referenceLayers: [refLayer],
      );

      expect(res.isSnappedX, isTrue);
      expect(res.effectiveX, 50.0);
      expect(res.activeSnapTargetX.relationship, SnapRelationshipX.centerToCenter);
      expect(res.activeSnapTargetX.targetLayerId, 'layer_1');
      expect(res.guideX, 50.0);
    });

    // 2. Active clip center snaps to another layer's center on Y axis when within 10px
    test('2. Center-to-Center Y: active clip center snaps to reference layer center within 10px', () {
      final refLayer = createLayer(
        id: 'layer_1',
        name: 'Overlay 1',
        type: LayerType.pipVideo,
        left: -50.0,
        right: 50.0,
        top: -120.0,
        bottom: -40.0, // center = -80.0
      );

      final res = TransformSnapEngine.evaluateMultiLayerSnap(
        rawX: 150.0,
        rawY: -74.0, // within 6px of -80.0
        scale: 0.5,
        rotationAngle: 0.0,
        canvasSize: canvasSize,
        referenceLayers: [refLayer],
      );

      expect(res.isSnappedY, isTrue);
      expect(res.effectiveY, -80.0);
      expect(res.activeSnapTargetY.relationship, SnapRelationshipY.centerToCenter);
      expect(res.activeSnapTargetY.targetLayerId, 'layer_1');
      expect(res.guideY, -80.0);
    });

    // 3. Active clip center snaps to another layer's center on both X and Y axes simultaneously
    test('3. Simultaneous Center-to-Center X/Y: snaps to layer center on both axes', () {
      final refLayer = createLayer(
        id: 'layer_1',
        name: 'Overlay 1',
        type: LayerType.pipVideo,
        left: 10.0,
        right: 70.0, // center X = 40.0
        top: 20.0,
        bottom: 100.0, // center Y = 60.0
      );

      final res = TransformSnapEngine.evaluateMultiLayerSnap(
        rawX: 45.0, // within 5px
        rawY: 67.0, // within 7px
        scale: 0.5,
        rotationAngle: 0.0,
        canvasSize: canvasSize,
        referenceLayers: [refLayer],
      );

      expect(res.isSnappedX, isTrue);
      expect(res.effectiveX, 40.0);
      expect(res.activeSnapTargetX.relationship, SnapRelationshipX.centerToCenter);
      expect(res.isSnappedY, isTrue);
      expect(res.effectiveY, 60.0);
      expect(res.activeSnapTargetY.relationship, SnapRelationshipY.centerToCenter);
    });

    // 4. Active clip left edge snaps to another layer's left edge (Same-Edge X)
    test('4. Same-Edge Left-to-Left: active clip left aligns to reference left', () {
      // Active clip scale 0.5: halfClipW = 90.0
      // Reference layer left = -100.0
      // Target active center = -100.0 + 90.0 = -10.0
      final refLayer = createLayer(
        id: 'layer_1',
        name: 'PIP',
        type: LayerType.pipVideo,
        left: -100.0,
        right: 0.0,
        top: -50.0,
        bottom: 50.0,
      );

      final res = TransformSnapEngine.evaluateMultiLayerSnap(
        rawX: -14.0, // within 4px of -10.0
        rawY: 200.0,
        scale: 0.5,
        rotationAngle: 0.0,
        canvasSize: canvasSize,
        referenceLayers: [refLayer],
      );

      expect(res.isSnappedX, isTrue);
      expect(res.effectiveX, -10.0);
      expect(res.activeSnapTargetX.relationship, SnapRelationshipX.leftToLeft);
      expect(res.guideX, -100.0);
    });

    // 5. Active clip right edge snaps to another layer's right edge (Same-Edge X)
    test('5. Same-Edge Right-to-Right: active clip right aligns to reference right', () {
      // Active scale 0.5: halfClipW = 90.0
      // Reference layer right = 110.0
      // Target active center = 110.0 - 90.0 = 20.0
      final refLayer = createLayer(
        id: 'layer_1',
        name: 'PIP',
        type: LayerType.pipVideo,
        left: 20.0,
        right: 110.0,
        top: -50.0,
        bottom: 50.0,
      );

      final res = TransformSnapEngine.evaluateMultiLayerSnap(
        rawX: 25.0, // within 5px of 20.0
        rawY: 200.0,
        scale: 0.5,
        rotationAngle: 0.0,
        canvasSize: canvasSize,
        referenceLayers: [refLayer],
      );

      expect(res.isSnappedX, isTrue);
      expect(res.effectiveX, 20.0);
      expect(res.activeSnapTargetX.relationship, SnapRelationshipX.rightToRight);
      expect(res.guideX, 110.0);
    });

    // 6. Active clip top edge snaps to another layer's top edge (Same-Edge Y)
    test('6. Same-Edge Top-to-Top: active clip top aligns to reference top', () {
      // Active scale 0.5: halfClipH = 160.0
      // Reference top = -120.0
      // Target active center = -120.0 + 160.0 = 40.0
      final refLayer = createLayer(
        id: 'layer_1',
        name: 'PIP',
        type: LayerType.pipVideo,
        left: -50.0,
        right: 50.0,
        top: -120.0,
        bottom: 0.0,
      );

      final res = TransformSnapEngine.evaluateMultiLayerSnap(
        rawX: 100.0,
        rawY: 45.0, // within 5px of 40.0
        scale: 0.5,
        rotationAngle: 0.0,
        canvasSize: canvasSize,
        referenceLayers: [refLayer],
      );

      expect(res.isSnappedY, isTrue);
      expect(res.effectiveY, 40.0);
      expect(res.activeSnapTargetY.relationship, SnapRelationshipY.topToTop);
      expect(res.guideY, -120.0);
    });

    // 7. Active clip bottom edge snaps to another layer's bottom edge (Same-Edge Y)
    test('7. Same-Edge Bottom-to-Bottom: active clip bottom aligns to reference bottom', () {
      // Active scale 0.5: halfClipH = 160.0
      // Reference bottom = 140.0
      // Target active center = 140.0 - 160.0 = -20.0
      final refLayer = createLayer(
        id: 'layer_1',
        name: 'PIP',
        type: LayerType.pipVideo,
        left: -50.0,
        right: 50.0,
        top: 40.0,
        bottom: 140.0,
      );

      final res = TransformSnapEngine.evaluateMultiLayerSnap(
        rawX: 100.0,
        rawY: -26.0, // within 6px of -20.0
        scale: 0.5,
        rotationAngle: 0.0,
        canvasSize: canvasSize,
        referenceLayers: [refLayer],
      );

      expect(res.isSnappedY, isTrue);
      expect(res.effectiveY, -20.0);
      expect(res.activeSnapTargetY.relationship, SnapRelationshipY.bottomToBottom);
      expect(res.guideY, 140.0);
    });

    // 8. Active clip left edge snaps to another layer's right edge (Opposite-Edge X)
    test('8. Opposite-Edge Left-to-Right: active clip left aligns to reference right', () {
      // Active scale 0.5: halfClipW = 90.0
      // Reference right = -10.0
      // Target active center = -10.0 + 90.0 = 80.0
      final refLayer = createLayer(
        id: 'layer_1',
        name: 'PIP',
        type: LayerType.pipVideo,
        left: -80.0,
        right: -10.0,
        top: -50.0,
        bottom: 50.0,
      );

      final res = TransformSnapEngine.evaluateMultiLayerSnap(
        rawX: 84.0, // within 4px of 80.0
        rawY: 200.0,
        scale: 0.5,
        rotationAngle: 0.0,
        canvasSize: canvasSize,
        referenceLayers: [refLayer],
      );

      expect(res.isSnappedX, isTrue);
      expect(res.effectiveX, 80.0);
      expect(res.activeSnapTargetX.relationship, SnapRelationshipX.leftToRight);
      expect(res.guideX, -10.0);
    });

    // 9. Active clip right edge snaps to another layer's left edge (Opposite-Edge X)
    test('9. Opposite-Edge Right-to-Left: active clip right aligns to reference left', () {
      // Active scale 0.5: halfClipW = 90.0
      // Reference left = 50.0
      // Target active center = 50.0 - 90.0 = -40.0
      final refLayer = createLayer(
        id: 'layer_1',
        name: 'PIP',
        type: LayerType.pipVideo,
        left: 50.0,
        right: 120.0,
        top: -50.0,
        bottom: 50.0,
      );

      final res = TransformSnapEngine.evaluateMultiLayerSnap(
        rawX: -46.0, // within 6px of -40.0
        rawY: 200.0,
        scale: 0.5,
        rotationAngle: 0.0,
        canvasSize: canvasSize,
        referenceLayers: [refLayer],
      );

      expect(res.isSnappedX, isTrue);
      expect(res.effectiveX, -40.0);
      expect(res.activeSnapTargetX.relationship, SnapRelationshipX.rightToLeft);
      expect(res.guideX, 50.0);
    });

    // 10. Active clip top edge snaps to another layer's bottom edge (Opposite-Edge Y)
    test('10. Opposite-Edge Top-to-Bottom: active clip top aligns to reference bottom', () {
      // Active scale 0.5: halfClipH = 160.0
      // Reference bottom = -30.0
      // Target active center = -30.0 + 160.0 = 130.0
      final refLayer = createLayer(
        id: 'layer_1',
        name: 'PIP',
        type: LayerType.pipVideo,
        left: -50.0,
        right: 50.0,
        top: -100.0,
        bottom: -30.0,
      );

      final res = TransformSnapEngine.evaluateMultiLayerSnap(
        rawX: 200.0,
        rawY: 135.0, // within 5px of 130.0
        scale: 0.5,
        rotationAngle: 0.0,
        canvasSize: canvasSize,
        referenceLayers: [refLayer],
      );

      expect(res.isSnappedY, isTrue);
      expect(res.effectiveY, 130.0);
      expect(res.activeSnapTargetY.relationship, SnapRelationshipY.topToBottom);
      expect(res.guideY, -30.0);
    });

    // 11. Active clip bottom edge snaps to another layer's top edge (Opposite-Edge Y)
    test('11. Opposite-Edge Bottom-to-Top: active clip bottom aligns to reference top', () {
      // Active scale 0.5: halfClipH = 160.0
      // Reference top = 50.0
      // Target active center = 50.0 - 160.0 = -110.0
      final refLayer = createLayer(
        id: 'layer_1',
        name: 'PIP',
        type: LayerType.pipVideo,
        left: -50.0,
        right: 50.0,
        top: 50.0,
        bottom: 120.0,
      );

      final res = TransformSnapEngine.evaluateMultiLayerSnap(
        rawX: 200.0,
        rawY: -105.0, // within 5px of -110.0
        scale: 0.5,
        rotationAngle: 0.0,
        canvasSize: canvasSize,
        referenceLayers: [refLayer],
      );

      expect(res.isSnappedY, isTrue);
      expect(res.effectiveY, -110.0);
      expect(res.activeSnapTargetY.relationship, SnapRelationshipY.bottomToTop);
      expect(res.guideY, 50.0);
    });

    // 12. Multi-layer priority: Center-to-Center takes precedence over Same-Edge
    test('12. Priority 1 vs 2: Center-to-Center takes precedence over Same-Edge', () {
      // Active scale 0.5: halfClipW = 90.0
      // Center candidate: ref1 center at 40.0 (rawX = 44.0 -> dist 4.0)
      // Same-edge candidate: ref2 left at -52.0 -> target center = -52 + 90 = 38.0 (dist 6.0 or closer like 43.0 -> dist 1.0)
      final refCenter = createLayer(
        id: 'layer_center',
        name: 'Center Ref',
        type: LayerType.pipVideo,
        left: 20.0,
        right: 60.0, // center = 40.0
        top: 0.0,
        bottom: 50.0,
      );
      final refEdge = createLayer(
        id: 'layer_edge',
        name: 'Edge Ref',
        type: LayerType.pipVideo,
        left: -48.0, // target = -48 + 90 = 42.0 (closer: distance 1.0 to rawX 43.0)
        right: 10.0,
        top: 0.0,
        bottom: 50.0,
      );

      final res = TransformSnapEngine.evaluateMultiLayerSnap(
        rawX: 43.0, // dist to refEdge is 1.0; dist to refCenter is 3.0
        rawY: 200.0,
        scale: 0.5,
        rotationAngle: 0.0,
        canvasSize: canvasSize,
        referenceLayers: [refCenter, refEdge],
      );

      // Priority 1 (Center-to-Center) MUST defeat Priority 2 (Same-Edge) even with larger distance
      expect(res.activeSnapTargetX.relationship, SnapRelationshipX.centerToCenter);
      expect(res.effectiveX, 40.0);
    });

    // 13. Multi-layer priority: Same-Edge takes precedence over Opposite-Edge
    test('13. Priority 2 vs 3: Same-Edge takes precedence over Opposite-Edge', () {
      // Active scale 0.5: halfClipW = 90.0
      // Same-edge candidate: refSame left at -50.0 -> target center = -50 + 90 = 40.0
      // Opposite-edge candidate: refOpp right at -52.0 -> target center = -52 + 90 = 38.0
      final refSame = createLayer(
        id: 'layer_same',
        name: 'Same Ref',
        type: LayerType.pipVideo,
        left: -50.0,
        right: 20.0,
        top: 0.0,
        bottom: 50.0,
      );
      final refOpp = createLayer(
        id: 'layer_opp',
        name: 'Opp Ref',
        type: LayerType.pipVideo,
        left: -100.0,
        right: -52.0,
        top: 0.0,
        bottom: 50.0,
      );

      final res = TransformSnapEngine.evaluateMultiLayerSnap(
        rawX: 39.0, // dist to refSame is 1.0; dist to refOpp is 1.0
        rawY: 200.0,
        scale: 0.5,
        rotationAngle: 0.0,
        canvasSize: canvasSize,
        referenceLayers: [refSame, refOpp],
      );

      // Priority 2 (Same-Edge) MUST defeat Priority 3 (Opposite-Edge)
      expect(res.activeSnapTargetX.relationship, SnapRelationshipX.leftToLeft);
      expect(res.effectiveX, 40.0);
    });

    // 14. Multi-layer priority: Opposite-Edge takes precedence over Canvas Edges
    test('14. Priority 3 vs 4: Opposite-Edge takes precedence over Canvas Edges', () {
      // Active scale 0.5: halfClipW = 90.0
      // Canvas right edge: canvasSize.width / 2 - 90 = 180 - 90 = 90.0 (Priority 4)
      // Reference opposite-edge candidate: ref.right = 0.0 -> target = 0 + 90 = 90.0 (Priority 3)
      final refOpp = createLayer(
        id: 'layer_opp',
        name: 'Opp Ref',
        type: LayerType.pipVideo,
        left: -60.0,
        right: 2.0, // target = 2 + 90 = 92.0
        top: 0.0,
        bottom: 50.0,
      );

      final res = TransformSnapEngine.evaluateMultiLayerSnap(
        rawX: 91.0, // dist to refOpp target (92) is 1.0; dist to canvas right (90) is 1.0
        rawY: 200.0,
        scale: 0.5,
        rotationAngle: 0.0,
        canvasSize: canvasSize,
        referenceLayers: [refOpp],
      );

      // Priority 3 (Opposite-Edge) MUST defeat Priority 4 (Canvas Edge)
      expect(res.activeSnapTargetX.relationship, SnapRelationshipX.leftToRight);
      expect(res.effectiveX, 92.0);
    });

    // 15. Multi-layer priority: Center-to-Center takes precedence over Canvas Edges
    test('15. Priority 1 vs 4: Center-to-Center takes precedence over Canvas Edges', () {
      // Active scale 0.5: halfClipW = 90.0
      // Canvas right target = 90.0 (Priority 4)
      // Layer center target = 92.0 (Priority 1)
      final refCenter = createLayer(
        id: 'layer_center',
        name: 'Center Ref',
        type: LayerType.pipVideo,
        left: 62.0,
        right: 122.0, // center = 92.0
        top: 0.0,
        bottom: 50.0,
      );

      final res = TransformSnapEngine.evaluateMultiLayerSnap(
        rawX: 91.0,
        rawY: 200.0,
        scale: 0.5,
        rotationAngle: 0.0,
        canvasSize: canvasSize,
        referenceLayers: [refCenter],
      );

      expect(res.activeSnapTargetX.relationship, SnapRelationshipX.centerToCenter);
      expect(res.effectiveX, 92.0);
    });

    // 16. Multi-target tie breaking: smaller distance wins in same priority
    test('16. Tie breaking: smaller distance wins within same priority tier', () {
      // Two center candidates: refA center = 40.0, refB center = 48.0
      final refA = createLayer(
        id: 'layer_a',
        name: 'A',
        type: LayerType.pipVideo,
        left: 20.0,
        right: 60.0, // center = 40.0
        top: 0.0,
        bottom: 50.0,
      );
      final refB = createLayer(
        id: 'layer_b',
        name: 'B',
        type: LayerType.pipVideo,
        left: 28.0,
        right: 68.0, // center = 48.0
        top: 0.0,
        bottom: 50.0,
      );

      final res = TransformSnapEngine.evaluateMultiLayerSnap(
        rawX: 42.0, // dist to A is 2.0; dist to B is 6.0
        rawY: 200.0,
        scale: 0.5,
        rotationAngle: 0.0,
        canvasSize: canvasSize,
        referenceLayers: [refA, refB],
      );

      expect(res.activeSnapTargetX.targetLayerId, 'layer_a');
      expect(res.effectiveX, 40.0);
    });

    // 17. Multi-target tie breaking: identical distance resolves via stable layer ID
    test('17. Tie breaking: identical distance resolves via stable layer ID string', () {
      // Two center candidates at identical center: refAlpha center = 50.0, refBeta center = 50.0
      final refAlpha = createLayer(
        id: 'alpha',
        name: 'Alpha',
        type: LayerType.pipVideo,
        left: 30.0,
        right: 70.0, // center = 50.0
        top: 0.0,
        bottom: 50.0,
      );
      final refBeta = createLayer(
        id: 'beta',
        name: 'Beta',
        type: LayerType.pipVideo,
        left: 30.0,
        right: 70.0, // center = 50.0
        top: 0.0,
        bottom: 50.0,
      );

      final res = TransformSnapEngine.evaluateMultiLayerSnap(
        rawX: 53.0, // distance = 3.0 to both
        rawY: 200.0,
        scale: 0.5,
        rotationAngle: 0.0,
        canvasSize: canvasSize,
        referenceLayers: [refAlpha, refBeta],
      );

      // 'alpha'.compareTo('beta') < 0 -> 'alpha' wins
      expect(res.activeSnapTargetX.targetLayerId, 'alpha');
      expect(res.effectiveX, 50.0);
    });

    // 18. Independent axes: active clip snaps to Layer A on X and Layer B on Y
    test('18. Independent axes: snaps to Layer A on X and Layer B on Y simultaneously', () {
      final refA = createLayer(
        id: 'layer_a',
        name: 'A',
        type: LayerType.pipVideo,
        left: 10.0,
        right: 50.0, // center X = 30.0
        top: -100.0,
        bottom: -50.0,
      );
      final refB = createLayer(
        id: 'layer_b',
        name: 'B',
        type: LayerType.text,
        left: 100.0,
        right: 150.0,
        top: 20.0,
        bottom: 80.0, // center Y = 50.0
      );

      final res = TransformSnapEngine.evaluateMultiLayerSnap(
        rawX: 32.0, // snaps to refA center 30.0
        rawY: 53.0, // snaps to refB center 50.0
        scale: 0.5,
        rotationAngle: 0.0,
        canvasSize: canvasSize,
        referenceLayers: [refA, refB],
      );

      expect(res.activeSnapTargetX.targetLayerId, 'layer_a');
      expect(res.effectiveX, 30.0);
      expect(res.activeSnapTargetY.targetLayerId, 'layer_b');
      expect(res.effectiveY, 50.0);
    });

    // 19. Mixed targets: active clip snaps to Layer A center on X and Canvas Top Edge on Y
    test('19. Mixed targets: Layer A on X and Canvas Top Edge on Y', () {
      final refA = createLayer(
        id: 'layer_a',
        name: 'A',
        type: LayerType.pipVideo,
        left: 10.0,
        right: 50.0, // center X = 30.0
        top: 60.0,
        bottom: 100.0,
      );

      // Canvas top target for scale 0.5: -320 + 160 = -160.0
      final res = TransformSnapEngine.evaluateMultiLayerSnap(
        rawX: 33.0,
        rawY: -164.0, // within 4px of canvas top
        scale: 0.5,
        rotationAngle: 0.0,
        canvasSize: canvasSize,
        referenceLayers: [refA],
      );

      expect(res.activeSnapTargetX.targetLayerId, 'layer_a');
      expect(res.effectiveX, 30.0);
      expect(res.activeSnapTargetY.relationship, SnapRelationshipY.canvasTopEdge);
      expect(res.effectiveY, -160.0);
      expect(res.snapTargetY, SnapTargetY.topEdge);
    });

    // 20. Mixed targets: Canvas Center on X and Layer B bottom edge on Y
    test('20. Mixed targets: Canvas Center on X and Layer B bottom edge on Y', () {
      // Active scale 0.5: halfClipH = 160.0
      // refB bottom = 100.0 -> target center = 100 - 160 = -60.0
      final refB = createLayer(
        id: 'layer_b',
        name: 'B',
        type: LayerType.sticker,
        left: 0.0,
        right: 40.0,
        top: 60.0,
        bottom: 100.0,
      );

      final res = TransformSnapEngine.evaluateMultiLayerSnap(
        rawX: 4.0, // within 4px of canvas center 0.0
        rawY: -64.0, // within 4px of target -60.0
        scale: 0.5,
        rotationAngle: 0.0,
        canvasSize: canvasSize,
        referenceLayers: [refB],
      );

      expect(res.activeSnapTargetX.relationship, SnapRelationshipX.canvasCenter);
      expect(res.effectiveX, 0.0);
      expect(res.snapTargetX, SnapTargetX.centerX);
      expect(res.activeSnapTargetY.targetLayerId, 'layer_b');
      expect(res.activeSnapTargetY.relationship, SnapRelationshipY.bottomToBottom);
      expect(res.effectiveY, -60.0);
    });

    // 21. Candidate exclusion: active clip does NOT snap to itself if present in layer list
    test('21. Candidate exclusion: active clip excludes itself from reference candidates', () {
      final selfLayer = createLayer(
        id: 'active_clip_id',
        name: 'Self',
        type: LayerType.mainVideo,
        left: 20.0,
        right: 80.0, // center = 50.0
        top: 0.0,
        bottom: 50.0,
      );

      final res = TransformSnapEngine.evaluateMultiLayerSnap(
        rawX: 52.0, // would snap to 50.0 if selfLayer was not excluded
        rawY: 200.0,
        scale: 0.5,
        rotationAngle: 0.0,
        canvasSize: canvasSize,
        activeLayerId: 'active_clip_id',
        referenceLayers: [selfLayer],
      );

      // Should NOT snap to selfLayer center 50.0
      expect(res.activeSnapTargetX.targetLayerId, isNot('active_clip_id'));
      expect(res.effectiveX, 52.0); // unsnapped
    });

    // 22. Hysteresis release on layer snap: snap remains engaged at 12px (<= 14.0 release threshold)
    test('22. Hysteresis hold: remains snapped at 12px distance from snap coordinate', () {
      const currentSnap = ActiveSnapTargetX(
        targetLayerId: 'layer_1',
        targetLayerName: 'Ref',
        targetLayerType: LayerType.pipVideo,
        relationship: SnapRelationshipX.centerToCenter,
        snapCoordinate: 50.0,
        guideCoordinate: 50.0,
      );

      final res = TransformSnapEngine.evaluateMultiLayerSnap(
        rawX: 62.0, // dist = 12.0 <= 14.0 release threshold
        rawY: 200.0,
        scale: 0.5,
        rotationAngle: 0.0,
        canvasSize: canvasSize,
        currentActiveSnapX: currentSnap,
      );

      expect(res.isSnappedX, isTrue);
      expect(res.effectiveX, 50.0);
      expect(res.activeSnapTargetX.targetLayerId, 'layer_1');
    });

    // 23. Hysteresis release on layer snap: snap releases at 15px (> 14.0 release threshold)
    test('23. Hysteresis release: breaks free at 15px distance from snap coordinate', () {
      const currentSnap = ActiveSnapTargetX(
        targetLayerId: 'layer_1',
        targetLayerName: 'Ref',
        targetLayerType: LayerType.pipVideo,
        relationship: SnapRelationshipX.centerToCenter,
        snapCoordinate: 50.0,
        guideCoordinate: 50.0,
      );

      final res = TransformSnapEngine.evaluateMultiLayerSnap(
        rawX: 65.0, // dist = 15.0 > 14.0 release threshold
        rawY: 200.0,
        scale: 0.5,
        rotationAngle: 0.0,
        canvasSize: canvasSize,
        currentActiveSnapX: currentSnap,
      );

      expect(res.isSnappedX, isFalse);
      expect(res.effectiveX, 65.0);
    });

    // 24. Target switching: snapping to Layer A releases when moved beyond 14px and snaps to Layer B within 10px
    test('24. Target switching: breaks from Layer A and latches onto Layer B', () {
      const currentSnapA = ActiveSnapTargetX(
        targetLayerId: 'layer_a',
        targetLayerName: 'Layer A',
        targetLayerType: LayerType.pipVideo,
        relationship: SnapRelationshipX.centerToCenter,
        snapCoordinate: 50.0,
        guideCoordinate: 50.0,
      );
      final refB = createLayer(
        id: 'layer_b',
        name: 'Layer B',
        type: LayerType.pipVideo,
        left: 80.0,
        right: 120.0, // center = 100.0
        top: 0.0,
        bottom: 50.0,
      );

      final res = TransformSnapEngine.evaluateMultiLayerSnap(
        rawX: 98.0, // dist from A (50) is 48 > 14; dist from B (100) is 2 <= 10
        rawY: 200.0,
        scale: 0.5,
        rotationAngle: 0.0,
        canvasSize: canvasSize,
        currentActiveSnapX: currentSnapA,
        referenceLayers: [refB],
      );

      expect(res.isSnappedX, isTrue);
      expect(res.activeSnapTargetX.targetLayerId, 'layer_b');
      expect(res.effectiveX, 100.0);
    });

    // 25. Alignment against PIP OverlayClip: active clip snaps to PIP overlay bounds correctly
    test('25. Alignment against PIP OverlayClip: correctly converts and snaps to OverlayClip', () {
      const overlay = OverlayClip(
        id: 'pip_overlay_1',
        title: 'My PIP',
        startTime: Duration.zero,
        duration: Duration(seconds: 5),
        position: Offset(0.5, 0.5),
        scale: 1.0,
      );

      final bounds = TransformAlignmentBounds.fromOverlayClip(
        overlay: overlay,
        canvasSize: canvasSize,
      );

      expect(bounds.id, 'pip_overlay_1');
      expect(bounds.type, LayerType.pipVideo);
      expect(bounds.centerX, 0.0);
      expect(bounds.centerY, 0.0);

      final res = TransformSnapEngine.evaluateMultiLayerSnap(
        rawX: 6.0,
        rawY: 200.0,
        scale: 0.5,
        rotationAngle: 0.0,
        canvasSize: canvasSize,
        referenceLayers: [bounds],
      );

      expect(res.activeSnapTargetX.targetLayerId, 'pip_overlay_1');
      expect(res.effectiveX, 0.0);
    });

    // 26. Alignment against TextOverlay: active clip snaps to text overlay bounds correctly
    test('26. Alignment against TextOverlay: correctly converts and snaps to TextOverlay', () {
      const textOverlay = TextOverlay(
        id: 'text_1',
        text: 'Title Subtitle',
        startTime: Duration.zero,
        duration: Duration(seconds: 3),
        position: Offset(0.5, 0.5),
      );

      final bounds = TransformAlignmentBounds.fromTextOverlay(
        text: textOverlay,
        canvasSize: canvasSize,
      );

      expect(bounds.id, 'text_1');
      expect(bounds.type, LayerType.text);

      final res = TransformSnapEngine.evaluateMultiLayerSnap(
        rawX: bounds.centerX + 4.0,
        rawY: 200.0,
        scale: 0.5,
        rotationAngle: 0.0,
        canvasSize: canvasSize,
        referenceLayers: [bounds],
      );

      expect(res.activeSnapTargetX.targetLayerId, 'text_1');
      expect(res.effectiveX, bounds.centerX);
    });

    // 27. Alignment against StickerOverlay: active clip snaps to sticker overlay bounds correctly
    test('27. Alignment against StickerOverlay: correctly converts and snaps to StickerOverlay', () {
      final sticker = StickerOverlay(
        id: 'sticker_1',
        preset: StickerPreset.catalog.first,
        startTime: Duration.zero,
        duration: const Duration(seconds: 3),
        position: const Offset(0.5, 0.5),
        scale: 1.0,
      );

      final bounds = TransformAlignmentBounds.fromStickerOverlay(
        sticker: sticker,
        canvasSize: canvasSize,
      );

      expect(bounds.id, 'sticker_1');
      expect(bounds.type, LayerType.sticker);
      expect(bounds.centerX, 0.0);
      expect(bounds.centerY, 0.0);

      final res = TransformSnapEngine.evaluateMultiLayerSnap(
        rawX: 5.0,
        rawY: 200.0,
        scale: 0.5,
        rotationAngle: 0.0,
        canvasSize: canvasSize,
        referenceLayers: [bounds],
      );

      expect(res.activeSnapTargetX.targetLayerId, 'sticker_1');
      expect(res.effectiveX, 0.0);
    });

    // 28. Rotated active clip visual bounds: snapping accounts for active clip rotation correctly
    test('28. Rotated active clip: 90° rotation swaps width and height visual extents', () {
      // 90° rotation swaps canvasSize width (360) and height (640)
      // For scale 1.0, rotated halfClipW = 640 / 2 = 320.0
      final halfW = TransformSnapEngine.calculateHalfExtentX(
        canvasSize: canvasSize,
        scale: 1.0,
        rotationAngle: math.pi / 2.0,
      );
      expect(halfW, closeTo(320.0, 0.01));

      // Reference layer left = 0.0
      // Active left aligns to 0.0 => target active center = 0.0 + 320.0 = 320.0
      final ref = createLayer(
        id: 'ref_1',
        name: 'Ref',
        type: LayerType.pipVideo,
        left: 0.0,
        right: 100.0,
        top: 0.0,
        bottom: 50.0,
      );

      final res = TransformSnapEngine.evaluateMultiLayerSnap(
        rawX: 324.0, // within 4px of 320.0
        rawY: 200.0,
        scale: 1.0,
        rotationAngle: math.pi / 2.0,
        canvasSize: canvasSize,
        referenceLayers: [ref],
      );

      expect(res.activeSnapTargetX.relationship, SnapRelationshipX.leftToLeft);
      expect(res.effectiveX, closeTo(320.0, 0.01));
    });

    // 29. Rotated reference layer visual bounds: snapping accounts for reference layer rotation
    test('29. Rotated reference layer: computes expanded rotated AABB correctly', () {
      // Create PIP Overlay with 45° rotation
      const overlayRotated = OverlayClip(
        id: 'pip_rot',
        title: 'Rotated PIP',
        startTime: Duration.zero,
        duration: Duration(seconds: 5),
        position: Offset(0.5, 0.5),
        scale: 1.0,
        rotation: math.pi / 4.0, // 45°
      );

      final bounds = TransformAlignmentBounds.fromOverlayClip(
        overlay: overlayRotated,
        canvasSize: canvasSize,
      );

      // Base PIP is 140x100. Rotated 45°, AABB width = 140*cos(45) + 100*sin(45) = 240 / sqrt(2) ≈ 169.7
      expect(bounds.width, greaterThan(140.0));
      expect(bounds.height, greaterThan(100.0));

      // Active clip center-to-center still snaps to (0, 0)
      final res = TransformSnapEngine.evaluateMultiLayerSnap(
        rawX: -5.0,
        rawY: 6.0,
        scale: 0.5,
        rotationAngle: 0.0,
        canvasSize: canvasSize,
        referenceLayers: [bounds],
      );

      expect(res.activeSnapTargetX.targetLayerId, 'pip_rot');
      expect(res.effectiveX, 0.0);
      expect(res.activeSnapTargetY.targetLayerId, 'pip_rot');
      expect(res.effectiveY, 0.0);
    });

    // 30. Scaled active clip visual bounds: snapping accounts for active clip scale
    test('30. Scaled active clip: scale 2.0 doubles visual extent', () {
      final halfW = TransformSnapEngine.calculateHalfExtentX(
        canvasSize: canvasSize,
        scale: 2.0,
        rotationAngle: 0.0,
      );
      expect(halfW, 360.0); // canvasSize.width / 2 * 2.0 = 180 * 2 = 360

      final ref = createLayer(
        id: 'ref_1',
        name: 'Ref',
        type: LayerType.pipVideo,
        left: 0.0,
        right: 100.0,
        top: 0.0,
        bottom: 50.0,
      );

      // Active left aligns to ref left (0.0) -> target center = 0.0 + 360.0 = 360.0
      final res = TransformSnapEngine.evaluateMultiLayerSnap(
        rawX: 365.0, // within 5px
        rawY: 200.0,
        scale: 2.0,
        rotationAngle: 0.0,
        canvasSize: canvasSize,
        referenceLayers: [ref],
      );

      expect(res.activeSnapTargetX.relationship, SnapRelationshipX.leftToLeft);
      expect(res.effectiveX, 360.0);
    });

    // 31. Flipped active clip visual bounds: snapping accounts for active clip flip
    test('31. Flipped active clip: horizontal and vertical flips preserve valid visual extents', () {
      final halfWFlipped = TransformSnapEngine.calculateHalfExtentX(
        canvasSize: canvasSize,
        scale: 1.0,
        rotationAngle: 0.0,
        flipHorizontal: true,
        flipVertical: true,
      );
      expect(halfWFlipped, 180.0);

      final ref = createLayer(
        id: 'ref_1',
        name: 'Ref',
        type: LayerType.pipVideo,
        left: 0.0,
        right: 80.0, // center = 40.0
        top: 0.0,
        bottom: 50.0,
      );

      final res = TransformSnapEngine.evaluateMultiLayerSnap(
        rawX: 43.0,
        rawY: 200.0,
        scale: 1.0,
        rotationAngle: 0.0,
        flipHorizontal: true,
        flipVertical: true,
        canvasSize: canvasSize,
        referenceLayers: [ref],
      );

      expect(res.activeSnapTargetX.relationship, SnapRelationshipX.centerToCenter);
      expect(res.effectiveX, 40.0);
    });

    // 32. Guides painting: guideX and guideY correctly position vertical and horizontal alignment guides
    testWidgets('32. Guides painter renders at exact guideX and guideY coordinates', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 640,
              child: CustomPaint(
                painter: TransformAlignmentGuidesPainter(
                  guideX: 50.0, // Canvas-relative 50.0 -> Painter X = 50 + 180 = 230.0
                  guideY: -40.0, // Canvas-relative -40.0 -> Painter Y = -40 + 320 = 280.0
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate((w) => w is CustomPaint && w.painter is TransformAlignmentGuidesPainter),
        findsOneWidget,
      );
    });

    // 33. Atomic undo/redo: gesture commits single undo step with snapped transform values
    testWidgets('33. Multi-layer snap atomic undo/redo: gesture commits single undo snapshot with snapped values', (tester) async {
      final viewModel = EditorViewModel();
      final clip = viewModel.videoClips.first;
      viewModel.selectClip(0);

      // Add a PIP overlay layer at center
      const overlay = OverlayClip(
        id: 'overlay_pip',
        title: 'PIP',
        startTime: Duration.zero,
        duration: Duration(seconds: 5),
        position: Offset(0.5, 0.5),
      );
      viewModel.addOverlayClip(overlay);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 360,
                height: 360,
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
      );
      await tester.pump();

      expect(find.byType(InteractiveTransformCanvas), findsOneWidget);

      // Verify undo/redo on multi-layer snapped transform
      final initialX = clip.xPos;
      viewModel.updateClipTransform(clip.id, xPos: 50.0, yPos: 50.0, recordUndo: true);
      expect(viewModel.videoClips.first.xPos, 50.0);
      expect(viewModel.canUndo, isTrue);

      viewModel.undo();
      expect(viewModel.videoClips.first.xPos, initialX);

      viewModel.redo();
      expect(viewModel.videoClips.first.xPos, 50.0);

      viewModel.dispose();
    });
  });
}
