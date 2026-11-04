import 'package:flutter/material.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';

import '../gallery_theme.dart';
import 'camera_geometry.dart';

/// One labelled box in the analysed frame's pixels, with optional keypoints
/// normalized to that frame.
typedef DetectionFigure = ({Rect box, String label, List<Offset> keypoints});

/// Paints detector boxes, or a classifier's top classes.
///
/// Boxes come in the frame's pixels, so they are normalized by the frame size
/// and then mapped by [transform], exactly as landmarks are.
class DetectionOverlay extends CustomPainter {
  const DetectionOverlay(
    this.figures, {
    required this.frameSize,
    required this.transform,
    required this.showBoxes,
    required this.showPoints,
    this.classes = const [],
  });

  final List<DetectionFigure> figures;
  final Size frameSize;
  final PreviewTransform transform;
  final bool showBoxes;
  final bool showPoints;

  /// A classifier's top classes, listed in the preview's corner.
  final List<String> classes;

  static const _color = GalleryTheme.accentLight;

  @override
  void paint(Canvas canvas, Size size) {
    Offset at(double x, double y) =>
        transform.map(x / frameSize.width, y / frameSize.height);
    for (final figure in figures) {
      final box = Rect.fromPoints(
        at(figure.box.left, figure.box.top),
        at(figure.box.right, figure.box.bottom),
      );
      if (showBoxes) {
        canvas.drawRect(
          box,
          Paint()
            ..color = _color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
        _text(canvas, figure.label, box.topLeft + const Offset(4, 4));
      }
      if (showPoints) {
        final dot = Paint()..color = _color;
        for (final point in figure.keypoints) {
          canvas.drawCircle(transform.map(point.dx, point.dy), 3, dot);
        }
      }
    }
    for (final (i, label) in classes.indexed) {
      _text(canvas, label, Offset(12, 12 + i * 22.0));
    }
  }

  void _text(Canvas canvas, String text, Offset at) {
    if (text.isEmpty) return;
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: _color,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          shadows: [Shadow(blurRadius: 3)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at);
    painter.dispose();
  }

  @override
  bool shouldRepaint(DetectionOverlay oldDelegate) =>
      oldDelegate.figures != figures ||
      oldDelegate.classes != classes ||
      oldDelegate.transform != transform ||
      oldDelegate.showBoxes != showBoxes ||
      oldDelegate.showPoints != showPoints;
}

/// The overlay for a detector or classifier result, or null for other results.
DetectionOverlay? detectionOverlayFor(
  Object? result,
  PreviewTransform transform, {
  required bool boxes,
  required bool points,
}) {
  String score(double value) => '${(value * 100).round()}%';
  return switch (result) {
    FaceDetectorResult(
      :final detections,
      :final imageWidth,
      :final imageHeight,
    ) =>
      DetectionOverlay(
        [
          for (final d in detections)
            (
              box: Rect.fromLTRB(
                d.boundingBox.left.toDouble(),
                d.boundingBox.top.toDouble(),
                d.boundingBox.right.toDouble(),
                d.boundingBox.bottom.toDouble(),
              ),
              label: 'face ${score(d.categories.first.score)}',
              keypoints: [for (final k in d.keypoints) Offset(k.x, k.y)],
            ),
        ],
        frameSize: Size(imageWidth.toDouble(), imageHeight.toDouble()),
        transform: transform,
        showBoxes: boxes,
        showPoints: points,
      ),
    ObjectDetectorResult(
      :final detections,
      :final imageWidth,
      :final imageHeight,
    ) =>
      DetectionOverlay(
        [
          for (final d in detections)
            (
              box: Rect.fromLTRB(
                d.boundingBox.left.toDouble(),
                d.boundingBox.top.toDouble(),
                d.boundingBox.right.toDouble(),
                d.boundingBox.bottom.toDouble(),
              ),
              label:
                  '${d.categories.first.categoryName ?? '?'} '
                  '${score(d.categories.first.score)}',
              keypoints: const <Offset>[],
            ),
        ],
        frameSize: Size(imageWidth.toDouble(), imageHeight.toDouble()),
        transform: transform,
        showBoxes: boxes,
        showPoints: points,
      ),
    ImageClassifierResult(:final classifications) => DetectionOverlay(
      const [],
      frameSize: const Size(1, 1),
      transform: transform,
      showBoxes: boxes,
      showPoints: points,
      classes: [
        for (final c in classifications.firstOrNull?.categories ?? const [])
          '${c.displayName ?? c.categoryName ?? '?'} ${score(c.score)}',
      ],
    ),
    _ => null,
  };
}
