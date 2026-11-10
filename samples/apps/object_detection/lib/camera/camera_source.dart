import 'package:flutter/widgets.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';

import 'camera_source_native.dart'
    if (dart.library.js_interop) 'camera_source_web.dart';

/// A camera frame as the detector takes it.
typedef CameraFrame = ({
  /// Converted only if the detector runs it.
  VisionImage image,

  /// The frame's size in pixels, before rotation.
  Size size,

  /// Clockwise turn that stands the frame upright.
  int rotationDegrees,
});

/// The live camera: the `camera` plugin on Android, iOS, macOS, Linux and
/// Windows, and `getUserMedia` in browsers, where the plugin streams no
/// frames.
abstract class CameraSource extends ChangeNotifier {
  /// The camera for this platform.
  static CameraSource create() => createCameraSource();

  /// Opens the default camera and calls [onFrame] with each frame.
  Future<void> start(void Function(CameraFrame frame) onFrame);

  /// Whether a camera is open and streaming.
  bool get isRunning;

  /// Why the camera could not open, if it could not.
  String? get error;

  /// Whether another camera is available to [switchCamera] to.
  bool get canSwitch;

  /// Opens the next camera.
  Future<void> switchCamera();

  /// The aspect ratio of [buildPreview], width over height.
  double get aspectRatio;

  /// Whether the preview is mirrored while frames are not, so the overlay has
  /// to be mirrored too.
  bool get mirrorOverlay;

  /// The camera's own preview.
  Widget buildPreview();
}
