import 'dart:ui' show Offset, Size;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/services.dart' show DeviceOrientation;

/// Camera geometry shared by every live demo.
///
/// Ported from the camera overlay helpers in `flutter_litert`, which were
/// worked out against real Android and iOS devices. The rules below are those
/// findings, not a fresh derivation, so they are kept in one place and every
/// live tile goes through them rather than each screen guessing again.

/// Clockwise rotation, in degrees, that stands a delivered camera frame
/// upright for the current device orientation.
///
/// - **iOS**: the plugin pre-rotates the preview but not the image stream, so a
///   frame arrives in sensor layout. Rotate only when the device is portrait
///   and the frame came in landscape-shaped.
/// - **Android**: the combined `(sensor +/- deviceRotation) % 360` formula; the
///   sign depends on which way the lens faces.
/// - **Everything else** (macOS, Linux, Windows, web): frames already arrive
///   upright, so no rotation.
///
/// The result is passed straight to MediaPipe as `rotationDegrees`, which is
/// also clockwise, and to [PreviewTransform] so the overlay lands on the same
/// pixels the preview is showing.
int uprightRotationDegrees({
  required int width,
  required int height,
  required int sensorOrientation,
  required bool isFrontCamera,
  required DeviceOrientation deviceOrientation,
}) {
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    final portrait =
        deviceOrientation == DeviceOrientation.portraitUp ||
        deviceOrientation == DeviceOrientation.portraitDown;
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

/// Whether the preview is mirrored while the frames handed to the task are not.
///
/// Android mirrors the front-facing preview but streams unmirrored buffers, and
/// Windows mirrors unconditionally, so on those the overlay has to be flipped
/// back to sit on the face the viewer can see. iOS and macOS mirror the preview
/// and the buffers together, so flipping there would put the landmarks on the wrong
/// side.
bool previewIsMirrored({required bool isFrontCamera}) =>
    (defaultTargetPlatform == TargetPlatform.android && isFrontCamera) ||
    defaultTargetPlatform == TargetPlatform.windows;

/// Aspect ratio of the box the preview occupies.
///
/// `CameraController.value.aspectRatio` describes the sensor, which is
/// landscape. `CameraPreview` inverts it when the device is portrait, so the
/// box around it has to be laid out the same way or the two disagree and the
/// preview is letterboxed inside its own parent.
double previewAspectRatio(
  double cameraAspectRatio,
  DeviceOrientation deviceOrientation,
) {
  final portrait =
      deviceOrientation == DeviceOrientation.portraitUp ||
      deviceOrientation == DeviceOrientation.portraitDown;
  if (cameraAspectRatio == 0) return 1;
  return portrait ? 1 / cameraAspectRatio : cameraAspectRatio;
}

/// Maps normalized landmark coordinates onto the preview box.
///
/// MediaPipe reports coordinates relative to the image it was given, which is
/// the frame as the camera delivered it, before any rotation. The preview shows
/// that frame stood upright and possibly mirrored, so a landmark has to make
/// the same trip before it can be drawn over it: rotate, mirror, scale to the
/// upright pixel size, then cover-fit into the widget.
class PreviewTransform {
  const PreviewTransform({
    required this.quarterTurns,
    required this.mirror,
    required this.uprightSize,
    required this.scale,
    required this.offsetX,
    required this.offsetY,
  });

  /// Cover-fits a [frameSize] frame, rotated by [rotationDegrees] clockwise,
  /// into a [viewSize] box.
  factory PreviewTransform.fit({
    required Size frameSize,
    required int rotationDegrees,
    required Size viewSize,
    required bool mirror,
  }) {
    final quarterTurns = (rotationDegrees ~/ 90) % 4;
    final upright = quarterTurns.isOdd
        ? Size(frameSize.height, frameSize.width)
        : frameSize;
    // Scale by the larger ratio so the frame covers the box, and centre the
    // axis that then overflows. When the box was laid out at
    // [previewAspectRatio] the two match and both offsets come out zero; the
    // cover fit keeps the overlay aligned when they do not.
    final double scale;
    var offsetX = 0.0;
    var offsetY = 0.0;
    if (upright.isEmpty || viewSize.isEmpty) {
      scale = 1;
    } else if (upright.width / upright.height >
        viewSize.width / viewSize.height) {
      scale = viewSize.height / upright.height;
      offsetX = (viewSize.width - upright.width * scale) / 2;
    } else {
      scale = viewSize.width / upright.width;
      offsetY = (viewSize.height - upright.height * scale) / 2;
    }
    return PreviewTransform(
      quarterTurns: quarterTurns,
      mirror: mirror,
      uprightSize: upright,
      scale: scale,
      offsetX: offsetX,
      offsetY: offsetY,
    );
  }

  /// Quarter turns clockwise taken to stand the frame upright.
  final int quarterTurns;

  /// Whether x is reflected, for a mirrored front-camera preview.
  final bool mirror;

  /// Frame size in pixels after rotation.
  final Size uprightSize;

  /// Uniform scale from upright pixels to the box.
  final double scale;

  /// Horizontal offset applied after scaling.
  final double offsetX;

  /// Vertical offset applied after scaling.
  final double offsetY;

  /// Maps a normalized point in the delivered frame to the preview box.
  Offset map(double x, double y) {
    final (rotatedX, rotatedY) = switch (quarterTurns) {
      1 => (1 - y, x),
      2 => (1 - x, 1 - y),
      3 => (y, 1 - x),
      _ => (x, y),
    };
    return mapUpright(rotatedX, rotatedY);
  }

  /// Maps a normalized point in the upright frame to the preview box. Image
  /// Segmenter masks come laid out upright (upstream-issues.md UP-017).
  Offset mapUpright(double x, double y) => Offset(
    (mirror ? 1 - x : x) * uprightSize.width * scale + offsetX,
    y * uprightSize.height * scale + offsetY,
  );

  @override
  bool operator ==(Object other) =>
      other is PreviewTransform &&
      other.quarterTurns == quarterTurns &&
      other.mirror == mirror &&
      other.uprightSize == uprightSize &&
      other.scale == scale &&
      other.offsetX == offsetX &&
      other.offsetY == offsetY;

  @override
  int get hashCode =>
      Object.hash(quarterTurns, mirror, uprightSize, scale, offsetX, offsetY);
}
