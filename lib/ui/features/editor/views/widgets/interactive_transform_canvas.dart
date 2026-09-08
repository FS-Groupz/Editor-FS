import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:capcut_video_editor/domain/models/clip_spatial_transform.dart';
import 'package:capcut_video_editor/domain/models/video_clip.dart';
import 'package:capcut_video_editor/ui/features/editor/providers/spatial_transform_provider.dart';
import 'package:capcut_video_editor/ui/features/editor/view_models/editor_view_model.dart';

/// CapCut-like Interactive Free-Transform Canvas Widget.
///
/// Wraps a video/media clip visual in a high-performance interactive surface supporting:
/// - One-finger 1:1 pan (translation)
/// - Two-finger pinch-to-zoom (uniform scale)
/// - Two-finger rotation (continuous angle in radians)
/// - Simultaneous pan + scale + rotation
/// - Active cyan bounding box and control handle
/// - Selective Riverpod state isolation
/// - Single undo/redo snapshot commit on gesture completion
class InteractiveTransformCanvas extends StatelessWidget {
  final VideoClip clip;
  final bool isSelected;
  final EditorViewModel viewModel;
  final Widget child;

  const InteractiveTransformCanvas({
    super.key,
    required this.clip,
    required this.isSelected,
    required this.viewModel,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final hasScope = context.findAncestorWidgetOfExactType<ProviderScope>() != null;
    final content = _InteractiveTransformCanvasContent(
      clip: clip,
      isSelected: isSelected,
      viewModel: viewModel,
      child: child,
    );
    if (!hasScope) {
      return ProviderScope(child: content);
    }
    return content;
  }
}

class _InteractiveTransformCanvasContent extends ConsumerStatefulWidget {
  final VideoClip clip;
  final bool isSelected;
  final EditorViewModel viewModel;
  final Widget child;

  const _InteractiveTransformCanvasContent({
    required this.clip,
    required this.isSelected,
    required this.viewModel,
    required this.child,
  });

  @override
  ConsumerState<_InteractiveTransformCanvasContent> createState() => _InteractiveTransformCanvasContentState();
}

class _InteractiveTransformCanvasContentState extends ConsumerState<_InteractiveTransformCanvasContent> {
  // Gesture baseline state captured on onScaleStart
  double _startInitialX = 0.0;
  double _startInitialY = 0.0;
  double _startInitialScale = 1.0;
  double _startInitialRotation = 0.0;
  Offset _startFocalPoint = Offset.zero;
  bool _isInteracting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(spatialTransformMapProvider.notifier).registerClip(widget.clip);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _InteractiveTransformCanvasContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the clip's spatial attributes were updated externally (e.g. undo, redo, reset, project load)
    if (oldWidget.clip.id == widget.clip.id &&
        (oldWidget.clip.xPos != widget.clip.xPos ||
            oldWidget.clip.yPos != widget.clip.yPos ||
            oldWidget.clip.scale != widget.clip.scale ||
            oldWidget.clip.rotationAngle != widget.clip.rotationAngle)) {
      ref.read(spatialTransformMapProvider.notifier).updateTransform(
            widget.clip.id,
            xPos: widget.clip.xPos,
            yPos: widget.clip.yPos,
            scale: widget.clip.scale,
            rotationAngle: widget.clip.rotationAngle,
          );
    }
  }

  void _onScaleStart(ScaleStartDetails details) {
    if (!widget.isSelected) return;

    final current = ref.read(spatialTransformMapProvider.notifier).getTransform(widget.clip.id);
    _startInitialX = current.xPos;
    _startInitialY = current.yPos;
    _startInitialScale = current.scale;
    _startInitialRotation = current.rotationAngle;
    _startFocalPoint = details.localFocalPoint;
    _isInteracting = true;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (!_isInteracting) return;

    // 1. Translation delta in local canvas coordinate space (1:1 with finger)
    final focalDelta = details.localFocalPoint - _startFocalPoint;
    final newX = ClipSpatialTransform.sanitizePosition(
      _startInitialX + focalDelta.dx,
      fallback: _startInitialX,
    );
    final newY = ClipSpatialTransform.sanitizePosition(
      _startInitialY + focalDelta.dy,
      fallback: _startInitialY,
    );

    // 2. Uniform scale factor relative to baseline
    final newScale = ClipSpatialTransform.sanitizeScale(
      _startInitialScale * details.scale,
      fallback: _startInitialScale,
    );

    // 3. Continuous rotation angle in radians relative to baseline
    final newRotation = ClipSpatialTransform.sanitizeRotation(
      _startInitialRotation + details.rotation,
      fallback: _startInitialRotation,
    );

    // High-frequency atomic update into Riverpod without full-tree rebuilds
    ref.read(spatialTransformMapProvider.notifier).updateTransform(
          widget.clip.id,
          xPos: newX,
          yPos: newY,
          scale: newScale,
          rotationAngle: newRotation,
        );
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (!_isInteracting) return;
    _isInteracting = false;

    final finalTransform = ref.read(spatialTransformMapProvider.notifier).getTransform(widget.clip.id);

    // Only commit an undo snapshot if spatial transform actually changed
    final hasChanged = finalTransform.xPos != _startInitialX ||
        finalTransform.yPos != _startInitialY ||
        finalTransform.scale != _startInitialScale ||
        finalTransform.rotationAngle != _startInitialRotation;

    if (hasChanged) {
      widget.viewModel.updateClipTransform(
        widget.clip.id,
        xPos: finalTransform.xPos,
        yPos: finalTransform.yPos,
        scale: finalTransform.scale,
        rotationAngle: finalTransform.rotationAngle,
        recordUndo: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Selectively watch only this clip's spatial transform
    final watchedTransform = ref.watch(clipSpatialTransformProvider(widget.clip.id));

    // Seamless fallback to domain clip state if not yet registered in Riverpod map
    final effectiveTransform = (watchedTransform.xPos == 0.0 &&
            watchedTransform.yPos == 0.0 &&
            watchedTransform.scale == 1.0 &&
            watchedTransform.rotationAngle == 0.0 &&
            (widget.clip.xPos != 0.0 ||
                widget.clip.yPos != 0.0 ||
                widget.clip.scale != 1.0 ||
                widget.clip.rotationAngle != 0.0))
        ? ClipSpatialTransform.fromClip(widget.clip)
        : watchedTransform;

    final matrix = effectiveTransform.toMatrix4(
      legacyRotationDegrees: widget.clip.rotationDegrees,
      flipHorizontal: widget.clip.flipHorizontal,
      flipVertical: widget.clip.flipVertical,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onScaleStart: widget.isSelected ? _onScaleStart : null,
      onScaleUpdate: widget.isSelected ? _onScaleUpdate : null,
      onScaleEnd: widget.isSelected ? _onScaleEnd : null,
      onTap: () {
        if (!widget.isSelected) {
          final idx = widget.viewModel.videoClips.indexWhere((c) => c.id == widget.clip.id);
          if (idx != -1) widget.viewModel.selectClip(idx);
        }
      },
      child: Transform(
        alignment: Alignment.center,
        transform: matrix,
        child: Stack(
          clipBehavior: Clip.none,
          fit: StackFit.passthrough,
          children: [
            // 1. Media surface content
            widget.child,

            // 2. Active cyan bounding box
            if (widget.isSelected)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFF00E5FF),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),

            // 3. Small cyan control dot/handle
            if (widget.isSelected)
              Positioned(
                top: -6,
                right: -6,
                child: IgnorePointer(
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
