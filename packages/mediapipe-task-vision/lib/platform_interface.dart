/// Where the browser plugin plugs Google's JavaScript runtime into the vision
/// task classes: the backend interfaces and factories, and the decoder its
/// results go through. The Android plugin installs only the GPU name reader.
///
/// Applications should import `mediapipe_vision.dart` instead.
library;

export 'package:mediapipe_core/platform_interface.dart'
    show taskPlatformGpuReader;

export 'src/results/decoders.dart';
export 'src/results/landmark_codec.dart';
export 'src/vision_task_backend.dart';
