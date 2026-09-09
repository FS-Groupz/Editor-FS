import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:capcut_video_editor/domain/models/video_clip.dart';
import 'package:capcut_video_editor/ui/features/editor/providers/spatial_transform_provider.dart';
import 'package:capcut_video_editor/ui/features/editor/view_models/editor_view_model.dart';
import 'package:capcut_video_editor/ui/features/editor/views/widgets/interactive_transform_canvas.dart';

VideoClip _createClip({
  String id = 'clip-test',
  double xPos = 0.0,
  double yPos = 0.0,
  double scale = 1.0,
  double rotationAngle = 0.0,
}) {
  return VideoClip(
    id: id,
    assetId: 'asset-1',
    title: 'Test Clip',
    originalDuration: const Duration(seconds: 10),
    trimStart: Duration.zero,
    trimEnd: const Duration(seconds: 10),
    previewGradient: const [Colors.blue, Colors.purple],
    xPos: xPos,
    yPos: yPos,
    scale: scale,
    rotationAngle: rotationAngle,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Spatial Transform Lifecycle & Build-Phase Mutation Regression Suite', () {
    late EditorViewModel viewModel;

    setUp(() {
      viewModel = EditorViewModel();
    });

    tearDown(() {
      viewModel.dispose();
    });

    testWidgets('1. Pure initial state derivation: mounts with non-zero clip transform without build-time mutation', (tester) async {
      final clip = _createClip(
        id: 'clip-initial-test',
        xPos: 75.0,
        yPos: -45.0,
        scale: 2.2,
        rotationAngle: 0.785,
      );

      // Pump widget inside root ProviderScope (as in app.dart)
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
                    viewModel: viewModel,
                    child: Container(color: Colors.red),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // Verify no exceptions thrown during initial build
      expect(tester.takeException(), isNull);

      // Verify Matrix4 transform rendered with the exact initial values derived purely from clip
      final transformFinder = find.byType(Transform);
      expect(transformFinder, findsWidgets);

      final transformWidget = tester.widget<Transform>(transformFinder.first);
      expect(transformWidget.transform.storage[12], closeTo(75.0, 0.001)); // tx
      expect(transformWidget.transform.storage[13], closeTo(-45.0, 0.001)); // ty
      expect(transformWidget.transform.getMaxScaleOnAxis(), closeTo(2.2, 0.001));
    });

    testWidgets('2. Parent rebuild does NOT mutate provider during build or trigger assertions', (tester) async {
      final clip = _createClip(id: 'clip-rebuild-test', xPos: 20.0, yPos: 30.0);
      int parentBuildCount = 0;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  parentBuildCount++;
                  return Column(
                    children: [
                      ElevatedButton(
                        onPressed: () => setState(() {}),
                        child: const Text('Rebuild'),
                      ),
                      SizedBox(
                        width: 300,
                        height: 200,
                        child: InteractiveTransformCanvas(
                          clip: clip,
                          isSelected: true,
                          viewModel: viewModel,
                          child: Container(color: Colors.blue),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(parentBuildCount, equals(1));
      expect(tester.takeException(), isNull);

      // Trigger 5 consecutive parent rebuilds
      for (int i = 0; i < 5; i++) {
        await tester.tap(find.text('Rebuild'));
        await tester.pump();
        expect(tester.takeException(), isNull);
      }

      expect(parentBuildCount, equals(6));
    });

    testWidgets('3. External clip spatial update (Undo workflow) reflects cleanly without build-time error', (tester) async {
      final clip1 = _createClip(id: 'clip-undo', xPos: 100.0, yPos: 50.0, scale: 1.5);
      final clipRestored = _createClip(id: 'clip-undo', xPos: 0.0, yPos: 0.0, scale: 1.0);

      late StateSetter outerSetState;
      var activeClip = clip1;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  outerSetState = setState;
                  return SizedBox(
                    width: 300,
                    height: 200,
                    child: InteractiveTransformCanvas(
                      clip: activeClip,
                      isSelected: true,
                      viewModel: viewModel,
                      child: Container(color: Colors.green),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Verify initial state
      var transform = tester.widget<Transform>(find.byType(Transform).first);
      expect(transform.transform.storage[12], closeTo(100.0, 0.001));

      // Simulate Undo: activeClip updated with previous baseline values
      outerSetState(() {
        activeClip = clipRestored;
      });
      await tester.pump();

      // Verify NO "Tried to modify a provider while the widget tree was building" exception
      expect(tester.takeException(), isNull);

      // Verify updated matrix reflects the restored clip
      transform = tester.widget<Transform>(find.byType(Transform).first);
      expect(transform.transform.storage[12], closeTo(0.0, 0.001));
      expect(transform.transform.getMaxScaleOnAxis(), closeTo(1.0, 0.001));
    });

    testWidgets('4. External clip spatial update (Redo workflow) reflects cleanly without build-time error', (tester) async {
      final clipOriginal = _createClip(id: 'clip-redo', xPos: 0.0, yPos: 0.0, scale: 1.0);
      final clipRedone = _createClip(id: 'clip-redo', xPos: 80.0, yPos: -40.0, scale: 1.8, rotationAngle: 1.0);

      late StateSetter outerSetState;
      var activeClip = clipOriginal;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  outerSetState = setState;
                  return SizedBox(
                    width: 300,
                    height: 200,
                    child: InteractiveTransformCanvas(
                      clip: activeClip,
                      isSelected: true,
                      viewModel: viewModel,
                      child: Container(color: Colors.amber),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Simulate Redo
      outerSetState(() {
        activeClip = clipRedone;
      });
      await tester.pump();

      expect(tester.takeException(), isNull);

      final transform = tester.widget<Transform>(find.byType(Transform).first);
      expect(transform.transform.storage[12], closeTo(80.0, 0.001));
      expect(transform.transform.storage[13], closeTo(-40.0, 0.001));
      expect(transform.transform.getMaxScaleOnAxis(), closeTo(1.8, 0.001));
    });

    testWidgets('5. Clip switching in the same canvas does not trigger build-time mutation or stale state', (tester) async {
      final clipA = _createClip(id: 'clip-A', xPos: 50.0, yPos: 25.0, scale: 1.2);
      final clipB = _createClip(id: 'clip-B', xPos: -30.0, yPos: -60.0, scale: 0.8);

      late StateSetter outerSetState;
      var currentClip = clipA;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  outerSetState = setState;
                  return SizedBox(
                    width: 300,
                    height: 200,
                    child: InteractiveTransformCanvas(
                      clip: currentClip,
                      isSelected: true,
                      viewModel: viewModel,
                      child: Container(color: Colors.purple),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

      var transform = tester.widget<Transform>(find.byType(Transform).first);
      expect(transform.transform.storage[12], closeTo(50.0, 0.001));

      // Switch to clip B
      outerSetState(() {
        currentClip = clipB;
      });
      await tester.pump();

      expect(tester.takeException(), isNull);

      transform = tester.widget<Transform>(find.byType(Transform).first);
      expect(transform.transform.storage[12], closeTo(-30.0, 0.001));
      expect(transform.transform.storage[13], closeTo(-60.0, 0.001));
      expect(transform.transform.storage[0], closeTo(0.8, 0.001)); // X scale
      expect(transform.transform.storage[5], closeTo(0.8, 0.001)); // Y scale
    });

    testWidgets('6. Gesture pan/scale/rotate lifecycle executes smoothly and commits to ViewModel', (tester) async {
      if (viewModel.videoClips.isEmpty) {
        viewModel.addNewClip();
      }
      final targetClip = viewModel.videoClips.first;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 300,
                  height: 300,
                  child: InteractiveTransformCanvas(
                    clip: targetClip,
                    isSelected: true,
                    viewModel: viewModel,
                    child: Container(color: Colors.cyan),
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

      expect(tester.takeException(), isNull);
      // Verify ViewModel committed the transform (accounting for touch slop threshold)
      expect(viewModel.videoClips.first.xPos, greaterThan(15.0));
      expect(viewModel.videoClips.first.yPos, lessThan(-10.0));
      expect(viewModel.canUndo, isTrue);
    });

    testWidgets('7. Bounding box & control handle render cleanly when isSelected is toggled', (tester) async {
      final clip = _createClip(id: 'clip-selection-test');
      late StateSetter outerSetState;
      bool isSelected = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  outerSetState = setState;
                  return SizedBox(
                    width: 300,
                    height: 200,
                    child: InteractiveTransformCanvas(
                      clip: clip,
                      isSelected: isSelected,
                      viewModel: viewModel,
                      child: Container(color: Colors.teal),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Initially unselected: no bounding box or handle
      expect(find.byType(Container), findsWidgets);
      expect(tester.takeException(), isNull);

      // Select clip
      outerSetState(() {
        isSelected = true;
      });
      await tester.pump();

      expect(tester.takeException(), isNull);

      // Unselect clip
      outerSetState(() {
        isSelected = false;
      });
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('8. Rapid consecutive rebuilds (simulating timeline playback) do not trigger assertion failure', (tester) async {
      var clip = _createClip(id: 'clip-rapid');
      late StateSetter outerSetState;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  outerSetState = setState;
                  return SizedBox(
                    width: 300,
                    height: 200,
                    child: InteractiveTransformCanvas(
                      clip: clip,
                      isSelected: true,
                      viewModel: viewModel,
                      child: Container(color: Colors.orange),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Simulate 20 rapid frames during playback/scrubbing
      for (int i = 0; i < 20; i++) {
        outerSetState(() {
          clip = clip.copyWith(xPos: i * 2.0, yPos: -i * 1.5);
        });
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.takeException(), isNull);
      }
    });

    test('9. Provider state remains isolated per clip without leak or cross-talk', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final clipA = _createClip(id: 'clip-isolated-A', xPos: 10.0, scale: 1.1);
      final clipB = _createClip(id: 'clip-isolated-B', xPos: 90.0, scale: 2.0);

      // Derived pure state
      final transformA = container.read(clipSpatialTransformFromClipProvider(clipA));
      final transformB = container.read(clipSpatialTransformFromClipProvider(clipB));

      expect(transformA.clipId, equals('clip-isolated-A'));
      expect(transformA.xPos, equals(10.0));
      expect(transformA.scale, equals(1.1));

      expect(transformB.clipId, equals('clip-isolated-B'));
      expect(transformB.xPos, equals(90.0));
      expect(transformB.scale, equals(2.0));

      // Mutating transient map for clip A
      final notifier = container.read(spatialTransformMapProvider.notifier);
      notifier.updatePosition('clip-isolated-A', 55.0, 33.0);

      final updatedA = container.read(clipSpatialTransformFromClipProvider(clipA));
      final unaffectedB = container.read(clipSpatialTransformFromClipProvider(clipB));

      expect(updatedA.xPos, equals(55.0));
      expect(updatedA.yPos, equals(33.0));
      expect(unaffectedB.xPos, equals(90.0)); // Clip B untouched!

      // Clear transient map for clip A
      notifier.clearTransform('clip-isolated-A');
      final clearedA = container.read(clipSpatialTransformFromClipProvider(clipA));
      expect(clearedA.xPos, equals(10.0)); // Reverts to clipA domain state cleanly!
    });
  });
}
