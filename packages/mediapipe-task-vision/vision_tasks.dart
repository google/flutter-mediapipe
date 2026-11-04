/// Every task name accepted by `hooks.user_defines.mediapipe_vision.tasks`.
///
/// Every task runs on Google's MediaPipe vision library, which this
/// package's hook bundles, or in browsers on Google's JavaScript runtime.
const visionTasks = {
  'face_detector',
  'face_landmarker',
  'gesture_recognizer',
  'hand_landmarker',
  'holistic_landmarker',
  'image_classifier',
  'image_embedder',
  'image_segmenter',
  'interactive_segmenter',
  'object_detector',
  'pose_landmarker',
};

/// The vision tasks validated on Google's vision library, by build target.
/// The library exports every task; only these have earned a claim there.
const visionRuntimeTasks = <String, Set<String>>{
  'macos/arm64': visionTasks,
  'ios/arm64': visionTasks,
  'ios-simulator/arm64': visionTasks,
  'linux/x64': visionTasks,
  'android/arm64': visionTasks,
  'android/x64': visionTasks,
  // Flutter's release builds include 32-bit ARM, so the hook accepts every
  // task there, though no capability claims it.
  'android/arm': visionTasks,
  // Google's Windows library exports the stateful Interactive Segmenter but
  // runs a stroke in about 25 seconds (upstream-issues.md UP-048).
  'windows/x64': {
    'face_detector',
    'face_landmarker',
    'gesture_recognizer',
    'hand_landmarker',
    'holistic_landmarker',
    'image_classifier',
    'image_embedder',
    'image_segmenter',
    'object_detector',
    'pose_landmarker',
  },
};
