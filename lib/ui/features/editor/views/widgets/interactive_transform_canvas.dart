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

  // Snapping state flags for active gesture
  bool _isSnappedX = false;
  bool _isSnappedY = false;

  @override
  void didUpdateWidget(covariant _InteractiveTransformCanvasContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the active clip identity changed while interacting, reset interaction flag
    if (oldWidget.clip.id != widget.clip.id && _isInteracting) {
      _isInteracting = false;
      _isSnappedX = false;
      _isSnappedY = false;
    }
  }

  void _onScaleStart(ScaleStartDetails details) {
    if (!widget.isSelected) return;

    final current = ref.read(spatialTransformMapProvider.notifier).getTransform(
          widget.clip.id,
          ClipSpatialTransform.fromClip(widget.clip),
        );
    _startInitialX = current.xPos;
    _startInitialY = current.yPos;
    _startInitialScale = current.scale;
    _startInitialRotation = current.rotationAngle;
    _startFocalPoint = details.localFocalPoint;
    _isInteracting = true;

    // Initialize snap state based on current baseline proximity to center
    _isSnappedX = _startInitialX.abs() <= ClipSpatialTransform.centerSnapThreshold;
    _isSnappedY = _startInitialY.abs() <= ClipSpatialTransform.centerSnapThreshold;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (!_isInteracting) return;

    // 1. Translation delta in local canvas coordinate space (1:1 with finger)
    final focalDelta = details.localFocalPoint - _startFocalPoint;
    final rawX = ClipSpatialTransform.sanitizePosition(
      _startInitialX + focalDelta.dx,
      fallback: _startInitialX,
    );
    final rawY = ClipSpatialTransform.sanitizePosition(
      _startInitialY + focalDelta.dy,
      fallback: _startInitialY,
    );

    // Apply auto-snap with hysteresis independently for X and Y axes
    final (snappedX, newSnappedX) = ClipSpatialTransform.calculateCenterSnap(
      rawCoordinate: rawX,
      currentlySnapped: _isSnappedX,
    );
    final (snappedY, newSnappedY) = ClipSpatialTransform.calculateCenterSnap(
      rawCoordinate: rawY,
      currentlySnapped: _isSnappedY,
    );

    if (_isSnappedX != newSnappedX || _isSnappedY != newSnappedY) {
      setState(() {
        _isSnappedX = newSnappedX;
        _isSnappedY = newSnappedY;
      });
    }

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
          xPos: snappedX,
          yPos: snappedY,
          scale: newScale,
          rotationAngle: newRotation,
        );
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (!_isInteracting) return;
    _isInteracting = false;

    if (_isSnappedX || _isSnappedY) {
      setState(() {
        _isSnappedX = false;
        _isSnappedY = false;
      });
    }

    final finalTransform = ref.read(spatialTransformMapProvider.notifier).getTransform(
          widget.clip.id,
          ClipSpatialTransform.fromClip(widget.clip),
        );

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

    // Clean up transient entry so domain VideoClip in ViewModel remains authoritative single source of truth
    ref.read(spatialTransformMapProvider.notifier).clearTransform(widget.clip.id);
  }

  @override
  Widget build(BuildContext context) {
    // Pure derivation: VideoClip spatial state -> initial provider state -> widget reads provider state
    final effectiveTransform = ref.watch(clipSpatialTransformFromClipProvider(widget.clip));

    final matrix = effectiveTransform.toMatrix4(
      legacyRotationDegrees: widget.clip.rotationDegrees,
      flipHorizontal: widget.clip.flipHorizontal,
      flipVertical: widget.clip.flipVertical,
    );

    return Stack(
      fit: StackFit.passthrough,
      children: [
        // 1. Gesture detector + Transformed media clip
        GestureDetector(
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
                // 1a. Media surface content
                widget.child,

                // 1b. Active cyan bounding box
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

                // 1c. Small cyan control dot/handle
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
        ),

        // 2. Un-transformed Center Alignment Guides (Only displayed during active gesture snapping)
        if (_isInteracting && (_isSnappedX || _isSnappedY))
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _CenterAlignmentGuidesPainter(
                  showVerticalGuide: _isSnappedX,
                  showHorizontalGuide: _isSnappedY,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Custom painter for thin, subtle cyan center alignment guides.
/// Spans the entire canvas without undergoing the media clip's affine transform.
class _CenterAlignmentGuidesPainter extends CustomPainter {
  final bool showVerticalGuide;
  final bool showHorizontalGuide;

  const _CenterAlignmentGuidesPainter({
    required this.showVerticalGuide,
    required this.showHorizontalGuide,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2.0;
    final centerY = size.height / 2.0;

    final glowPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.35)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final corePaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    if (showVerticalGuide) {
      // Vertical guide line across full canvas height at x = width / 2
      canvas.drawLine(Offset(centerX, 0), Offset(centerX, size.height), glowPaint);
      canvas.drawLine(Offset(centerX, 0), Offset(centerX, size.height), corePaint);
    }

    if (showHorizontalGuide) {
      // Horizontal guide line across full canvas width at y = height / 2
      canvas.drawLine(Offset(0, centerY), Offset(size.width, centerY), glowPaint);
      canvas.drawLine(Offset(0, centerY), Offset(size.width, centerY), corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CenterAlignmentGuidesPainter oldDelegate) {
    return oldDelegate.showVerticalGuide != showVerticalGuide ||
        oldDelegate.showHorizontalGuide != showHorizontalGuide;
  }
}
