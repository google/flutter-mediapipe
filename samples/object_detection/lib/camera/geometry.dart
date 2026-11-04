import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/services.dart' show DeviceOrientation;

/// Clockwise rotation, in degrees, that stands a camera frame upright.
///
/// - iOS streams frames in sensor layout while the preview is rotated, so a
///   landscape frame on a portrait device turns by the sensor orientation.
/// - Android combines the sensor and device rotations; the sign depends on
///   which way the lens faces.
/// - macOS, Linux, Windows and browsers deliver frames upright.
///
/// MediaPipe takes the same clockwise `rotationDegrees` and still reports
/// boxes in the frame's own coordinates, so the overlay applies this turn too.
int uprightRotationDegrees({
  required int width,
  required int height,
  required int sensorOrientation,
  required bool isFrontCamera,
  required DeviceOrientation deviceOrientation,
}) {
  final portrait =
      deviceOrientation == DeviceOrientation.portraitUp ||
      deviceOrientation == DeviceOrientation.portraitDown;
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    if (!portrait || height >= width) return 0;
    return sensorOrientation == 90 || sensorOrientation == 270
        ? sensorOrientation
        : 0;
  }
  if (defaultTargetPlatform == TargetPlatform.android) {
    final deviceRotation = switch (deviceOrientation) {
      DeviceOrientation.portraitUp => 0,
      DeviceOrientation.landscapeLeft => 90,
      DeviceOrientation.portraitDown => 180,
      DeviceOrientation.landscapeRight => 270,
    };
    final total = isFrontCamera
        ? (sensorOrientation + deviceRotation) % 360
        : (sensorOrientation - deviceRotation + 360) % 360;
    return total == 90 || total == 180 || total == 270 ? total : 0;
  }
  return 0;
}

/// Whether the camera plugin's preview is mirrored while its frames are not:
/// Android's front camera, and every Windows camera. iOS and macOS mirror both.
bool previewIsMirrored({required bool isFrontCamera}) =>
    (defaultTargetPlatform == TargetPlatform.android && isFrontCamera) ||
    defaultTargetPlatform == TargetPlatform.windows;

/// The aspect ratio `CameraPreview` lays itself out at: the sensor's
/// landscape ratio, inverted while the device is portrait.
double previewAspectRatio(
  double cameraAspectRatio,
  DeviceOrientation deviceOrientation,
) {
  if (cameraAspectRatio == 0) return 1;
  final portrait =
      deviceOrientation == DeviceOrientation.portraitUp ||
      deviceOrientation == DeviceOrientation.portraitDown;
  return portrait ? 1 / cameraAspectRatio : cameraAspectRatio;
}

/// Maps points in a frame, as MediaPipe reports them, onto the widget that
/// shows the frame upright, possibly mirrored, and cover-fitted.
class PreviewTransform {
  const PreviewTransform._({
    required this.frameSize,
    required this.quarterTurns,
    required this.mirror,
    required this.uprightSize,
    required this.scale,
    required this.offset,
  });

  /// Cover-fits a [frameSize] frame, turned [rotationDegrees] clockwise, into
  /// a [viewSize] box. When the box has the upright frame's aspect ratio the
  /// fit is exact and nothing is cropped.
  factory PreviewTransform.fit({
    required Size frameSize,
    required int rotationDegrees,
    required Size viewSize,
    bool mirror = false,
  }) {
    final quarterTurns = (rotationDegrees ~/ 90) % 4;
    final upright = quarterTurns.isOdd ? frameSize.flipped : frameSize;
    var scale = 1.0;
    var offset = Offset.zero;
    if (!upright.isEmpty && !viewSize.isEmpty) {
      scale = upright.aspectRatio > viewSize.aspectRatio
          ? viewSize.height / upright.height
          : viewSize.width / upright.width;
      offset = Offset(
        (viewSize.width - upright.width * scale) / 2,
        (viewSize.height - upright.height * scale) / 2,
      );
    }
    return PreviewTransform._(
      frameSize: frameSize,
      quarterTurns: quarterTurns,
      mirror: mirror,
      uprightSize: upright,
      scale: scale,
      offset: offset,
    );
  }

  /// The frame's size in pixels, as delivered.
  final Size frameSize;

  /// Quarter turns clockwise that stand the frame upright.
  final int quarterTurns;

  /// Whether x is reflected, for a mirrored preview.
  final bool mirror;

  /// The frame's size after rotation.
  final Size uprightSize;

  /// Upright pixels to logical pixels.
  final double scale;

  /// Where the upright frame's top left corner lands in the box.
  final Offset offset;

  /// Maps a normalized point in the delivered frame onto the box.
  Offset map(double x, double y) {
    final (ux, uy) = switch (quarterTurns) {
      1 => (1 - y, x),
      2 => (1 - x, 1 - y),
      3 => (y, 1 - x),
      _ => (x, y),
    };
    return Offset(
      (mirror ? 1 - ux : ux) * uprightSize.width * scale + offset.dx,
      uy * uprightSize.height * scale + offset.dy,
    );
  }

  /// Maps a box in frame pixels onto the box shown on screen.
  Rect mapRect(int left, int top, int right, int bottom) => Rect.fromPoints(
    map(left / frameSize.width, top / frameSize.height),
    map(right / frameSize.width, bottom / frameSize.height),
  );
}
