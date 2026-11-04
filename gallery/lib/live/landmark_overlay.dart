import 'package:flutter/material.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';

import '../gallery_theme.dart';
import 'camera_geometry.dart';

/// One set of landmarks and the official edges joining them, with an
/// optional `label` drawn beside the first landmark.
typedef LandmarkFigure = ({
  List<NormalizedLandmark> landmarks,
  List<(int, int)> edges,
  Color color,
  String? label,
});

/// Paints any landmark task's output.
///
/// Landmarks are normalized to the frame the camera delivered, so [transform]
/// rotates, mirrors and fits them onto the preview. Edge lists come from
/// `HandLandmarksConnections`, `PoseLandmarksConnections` and
/// `FaceLandmarksConnections`, generated from the official API, so
/// nothing here encodes a topology of its own.
class LandmarkOverlay extends CustomPainter {
  const LandmarkOverlay(
    this.figures, {
    required this.transform,
    required this.showEdges,
    required this.showPoints,
  });

  final List<LandmarkFigure> figures;
  final PreviewTransform transform;
  final bool showEdges;
  final bool showPoints;

  @override
  void paint(Canvas canvas, Size size) {
    for (final figure in figures) {
      final points = figure.landmarks;
      if (points.isEmpty) continue;
      Offset at(int index) => transform.map(points[index].x, points[index].y);
      if (showEdges) {
        final stroke = Paint()
          ..color = figure.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;
        for (final (start, end) in figure.edges) {
          if (start >= points.length || end >= points.length) continue;
          canvas.drawLine(at(start), at(end), stroke);
        }
      }
      if (showPoints) {
        final dot = Paint()..color = figure.color;
        for (var i = 0; i < points.length; i++) {
          canvas.drawCircle(at(i), 2.5, dot);
        }
      }
      if (figure.label case final label?) {
        final text = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              color: figure.color,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              shadows: const [Shadow(blurRadius: 3)],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        text.paint(canvas, at(0) + const Offset(8, 8));
        text.dispose();
      }
    }
  }

  @override
  bool shouldRepaint(LandmarkOverlay oldDelegate) =>
      oldDelegate.figures != figures ||
      oldDelegate.transform != transform ||
      oldDelegate.showEdges != showEdges ||
      oldDelegate.showPoints != showPoints;
}

/// Figures for one result, or an empty list when nothing was detected.
List<LandmarkFigure> figuresFor(Object? result) => switch (result) {
  final HandLandmarkerResult hands => [
    for (var i = 0; i < hands.handLandmarks.length; i++)
      _hand(hands.handLandmarks[i], i),
  ],
  // The top gesture is written at each hand's wrist.
  final GestureRecognizerResult gestures => [
    for (var i = 0; i < gestures.handLandmarks.length; i++)
      _hand(
        gestures.handLandmarks[i],
        i,
        label: gestures.gestures.elementAtOrNull(i)?.firstOrNull?.categoryName,
      ),
  ],
  final PoseLandmarkerResult poses => [
    for (final landmarks in poses.poseLandmarks) _pose(landmarks),
  ],
  // One person: body, both hands, and the face mesh as points.
  final HolisticLandmarkerResult person => [
    _pose(person.poseLandmarks),
    _hand(person.leftHandLandmarks, 0),
    _hand(person.rightHandLandmarks, 1),
    (
      landmarks: person.faceLandmarks,
      edges: FaceLandmarksConnections.contours,
      color: GalleryTheme.white,
      label: null,
    ),
  ],
  _ => const [],
};

LandmarkFigure _hand(
  List<NormalizedLandmark> landmarks,
  int i, {
  String? label,
}) => (
  landmarks: landmarks,
  edges: HandLandmarksConnections.all,
  color: i == 0 ? GalleryTheme.accentLight : GalleryTheme.white,
  label: label,
);

LandmarkFigure _pose(List<NormalizedLandmark> landmarks) => (
  landmarks: landmarks,
  edges: PoseLandmarksConnections.all,
  color: GalleryTheme.accentLight,
  label: null,
);
