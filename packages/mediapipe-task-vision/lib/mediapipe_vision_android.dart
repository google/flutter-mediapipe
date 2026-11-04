/// Flutter's registration of the vision package's Android plugin. Not for
/// applications: import `mediapipe_vision.dart`.
library;

import 'package:flutter/services.dart';
import 'package:mediapipe_vision/platform_interface.dart';

const _channel = MethodChannel('mediapipe_vision/android');

/// Installs the GPU name reader. The tasks run on Google's MediaPipe vision
/// library through FFI, as on iOS and the desktop.
abstract final class MediaPipeVisionAndroid {
  /// Called by Flutter before the first public task is created.
  static void registerWith() {
    // The GPU's name lets a task declare a GPU family it fails on, such as
    // Image Segmenter on PowerVR (UP-023), before anything runs there.
    taskPlatformGpuReader = () => _channel.invokeMethod<String>('gpuRenderer');
  }
}
