/// Google's MediaPipe vision tasks, with one API on Android, iOS, macOS,
/// Linux, Windows and the web.
///
/// Every task has `static create(options)`, Google's verbs (`detect`,
/// `classify`, `embed`, `segment`, `recognize` and their `ForVideo`
/// variants), a `delegate` getter and `dispose()`. What a platform's runtime
/// cannot do throws `RuntimeUnavailableException`, and each task's capability
/// query reports it in advance.
library;

export 'package:mediapipe_core/mediapipe_core.dart';

export 'models.dart' show VisionModels;
export 'src/browser_overlay.dart';
export 'src/capabilities.dart';
export 'src/tasks/face_detector.dart';
export 'src/tasks/face_landmarker.dart';
export 'src/tasks/gesture_recognizer.dart';
export 'src/tasks/hand_landmarker.dart';
export 'src/tasks/holistic_landmarker.dart';
export 'src/tasks/image_classifier.dart';
export 'src/tasks/image_embedder.dart';
export 'src/tasks/image_segmenter.dart';
export 'src/tasks/interactive_segmenter.dart';
export 'src/tasks/object_detector.dart';
export 'src/tasks/pose_landmarker.dart';
export 'src/types/face_landmarks_connections.dart';
export 'src/types/landmarks_connections.dart';
export 'src/types/options.dart';
export 'src/types/results.dart';
export 'src/types/strokes.dart';
export 'src/types/vision_types.dart'
    hide
        checkConfidence,
        checkCount,
        isDeferredImage,
        ownNestedLists,
        producedImage,
        refuseDeferredImage;
