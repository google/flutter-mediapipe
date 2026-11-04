import 'dart:typed_data';
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';

import '../gallery_theme.dart';
import 'camera_geometry.dart';

/// Paints the facial landmarks and their connections over the preview.
///
/// Landmarks arrive normalized to the frame the camera delivered, which is not
/// what the preview shows on a phone, so [transform] does the rotating,
/// mirroring and fitting. No cropping or landmark smoothing.
class FaceOverlay extends CustomPainter {
  FaceOverlay(
    this.result, {
    required this.transform,
    required this.showConnections,
    required this.showPoints,
  });

  final FaceLandmarkerResult? result;
  final PreviewTransform transform;
  final bool showConnections;
  final bool showPoints;

  @override
  void paint(Canvas canvas, Size size) {
    final result = this.result;
    if (result == null) return;
    final connections = Paint()
      ..color = GalleryTheme.accentLight.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    final contour = Paint()
      ..color = GalleryTheme.accentLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final iris = Paint()
      ..color = GalleryTheme.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    final point = Paint()..color = GalleryTheme.white;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (final face in result.faceLandmarks) {
      final positions = [
        for (final landmark in face) transform.map(landmark.x, landmark.y),
      ];
      // One draw call per group: segment endpoints as x0, y0, x1, y1, ...
      void edges(List<(int, int)> connections, Paint paint) {
        final points = Float32List(connections.length * 4);
        var length = 0;
        for (final (start, end) in connections) {
          if (start >= positions.length || end >= positions.length) continue;
          points[length++] = positions[start].dx;
          points[length++] = positions[start].dy;
          points[length++] = positions[end].dx;
          points[length++] = positions[end].dy;
        }
        canvas.drawRawPoints(
          PointMode.lines,
          Float32List.sublistView(points, 0, length),
          paint,
        );
      }

      if (showConnections) {
        edges(FaceLandmarksConnections.tessellation, connections);
        edges(FaceLandmarksConnections.contours, contour);
        edges(FaceLandmarksConnections.leftIris, iris);
        edges(FaceLandmarksConnections.rightIris, iris);
      }
      if (showPoints) {
        for (final position in positions) {
          canvas.drawCircle(position, 1.4, point);
        }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(FaceOverlay oldDelegate) =>
      oldDelegate.result != result ||
      oldDelegate.transform != transform ||
      oldDelegate.showConnections != showConnections ||
      oldDelegate.showPoints != showPoints;
}
