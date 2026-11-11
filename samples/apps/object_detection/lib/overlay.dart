import 'package:flutter/material.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';

import 'camera/geometry.dart';

/// The label Google's samples draw on a box: the category and its score.
String detectionLabel(Detection detection) {
  final category = detection.categories.firstOrNull;
  if (category == null) return '';
  final name = category.displayName ?? category.categoryName ?? '';
  return '$name ${category.score.toStringAsFixed(2)}';
}

/// Draws each detection's box and label over the picture it came from.
///
/// [transform] maps the frame the detector saw onto the widget showing it.
class DetectionPainter extends CustomPainter {
  DetectionPainter(this.result, this.transform);

  final ObjectDetectorResult result;
  final PreviewTransform transform;

  static const _color = Color(0xFF0F9D58);

  @override
  void paint(Canvas canvas, Size size) {
    final box = Paint()
      ..color = _color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    for (final detection in result.detections) {
      final b = detection.boundingBox;
      final rect = transform.mapRect(b.left, b.top, b.right, b.bottom);
      canvas.drawRect(rect, box);
      final label = TextPainter(
        text: TextSpan(
          text: detectionLabel(detection),
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final background = Rect.fromLTWH(
        rect.left,
        rect.top,
        label.width + 8,
        label.height + 4,
      );
      canvas.drawRect(background, Paint()..color = _color);
      label.paint(canvas, background.topLeft + const Offset(4, 2));
      label.dispose();
    }
  }

  @override
  bool shouldRepaint(DetectionPainter oldDelegate) => true;
}

/// [child] with [result]'s boxes drawn over it. [child] shows the frame
/// turned [rotationDegrees] clockwise and fills the box this lays out at the
/// upright frame's aspect ratio.
class DetectionView extends StatelessWidget {
  const DetectionView({
    super.key,
    required this.frameSize,
    required this.child,
    this.result,
    this.rotationDegrees = 0,
    this.mirror = false,
    this.aspectRatio,
  });

  final Size frameSize;
  final Widget child;
  final ObjectDetectorResult? result;
  final int rotationDegrees;
  final bool mirror;

  /// Overrides the box's aspect ratio, for a preview that lays itself out.
  final double? aspectRatio;

  @override
  Widget build(BuildContext context) {
    final upright = (rotationDegrees ~/ 90).isOdd
        ? frameSize.flipped
        : frameSize;
    return Center(
      child: AspectRatio(
        aspectRatio: aspectRatio ?? upright.aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            child,
            if (result case final result?)
              LayoutBuilder(
                builder: (context, constraints) => CustomPaint(
                  painter: DetectionPainter(
                    result,
                    PreviewTransform.fit(
                      frameSize: frameSize,
                      rotationDegrees: rotationDegrees,
                      viewSize: constraints.biggest,
                      mirror: mirror,
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
