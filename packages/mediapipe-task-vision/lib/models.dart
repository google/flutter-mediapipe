/// The verified official models of the vision tasks, [VisionModels], which
/// `mediapipe_vision.dart` also exports. `bundle_models` reads them from this
/// library alone.
library;

import 'package:mediapipe_core/mediapipe_core.dart';

/// Verified official models accepted by vision task options.
abstract final class VisionModels {
  /// Face Detector: Google's BlazeFace short-range float16 model, version 1.
  static const faceDetector = DownloadAsset(
    url:
        'https://storage.googleapis.com/mediapipe-models/face_detector/'
        'blaze_face_short_range/float16/1/blaze_face_short_range.tflite',
    sha256: 'b4578f35940bf5a1a655214a1cce5cab13eba73c1297cd78e1a04c2380b0152f',
  );

  /// Face Landmarker: Google's float16 bundle, version 1, holding the face
  /// detector, the 478-landmark model and the blendshape model.
  static const faceLandmarker = DownloadAsset(
    url:
        'https://storage.googleapis.com/mediapipe-models/face_landmarker/'
        'face_landmarker/float16/1/face_landmarker.task',
    sha256: '64184e229b263107bc2b804c6625db1341ff2bb731874b0bcc2fe6544e0bc9ff',
  );

  /// Object Detector: Google's EfficientDet-Lite0 float32 detector, version
  /// 1, with the 80 COCO classes. Float32 rather than int8 because Metal needs
  /// a float model; see tool/GPU_VALIDATION.md.
  static const objectDetector = DownloadAsset(
    url:
        'https://storage.googleapis.com/mediapipe-models/object_detector/'
        'efficientdet_lite0/float32/1/efficientdet_lite0.tflite',
    sha256: '40338edf5ec70d43e318b0a716a84d4564cd1802759a7a07170c7e43796dbf58',
  );

  /// Image Classifier: Google's ImageNet EfficientNet-Lite0 float32
  /// classifier, version 1.
  static const imageClassifier = DownloadAsset(
    url:
        'https://storage.googleapis.com/mediapipe-models/image_classifier/'
        'efficientnet_lite0/float32/1/efficientnet_lite0.tflite',
    sha256: '6c7ab0a6e5dcbf38a8c33b960996a55a3b4300b36a018c4545801de3a3c8bde0',
  );

  /// Image Embedder: Google's MobileNet-V3 small float32 embedder, version 1.
  static const imageEmbedder = DownloadAsset(
    url:
        'https://storage.googleapis.com/mediapipe-models/image_embedder/'
        'mobilenet_v3_small/float32/1/mobilenet_v3_small.tflite',
    sha256: 'bbbb4c51a55a53905af1daec995ca1aae355046f8839bb8c9f5ce9271394bc40',
  );

  /// Image Segmenter: Google's DeepLab-v3 float32 model, version 1.
  static const imageSegmenter = DownloadAsset(
    url:
        'https://storage.googleapis.com/mediapipe-models/image_segmenter/'
        'deeplab_v3/float32/1/deeplab_v3.tflite',
    sha256: 'ff36e24d40547fe9e645e2f4e8745d1876d6e38b332d39a82f0bf0f5d1d561b3',
  );

  /// Interactive Segmenter: Google's stateful MagicTouch int8 encoder and
  /// decoder bundle, version 1.
  static const interactiveSegmenter = DownloadAsset(
    url:
        'https://storage.googleapis.com/mediapipe-models/'
        'interactive_segmenter_v2/magic_touch/int8/1/'
        'interactive_segmentation.task',
    sha256: '38431bc66b883404e8397f74c3579404315b9b52b04a46c6346fe906a7309b03',
  );

  /// Hand Landmarker: Google's float16 task bundle, version 1.
  static const handLandmarker = DownloadAsset(
    url:
        'https://storage.googleapis.com/mediapipe-models/hand_landmarker/'
        'hand_landmarker/float16/1/hand_landmarker.task',
    sha256: 'fbc2a30080c3c557093b5ddfc334698132eb341044ccee322ccf8bcf3607cde1',
  );

  /// Gesture Recognizer: Google's float16 task bundle, version 1.
  static const gestureRecognizer = DownloadAsset(
    url:
        'https://storage.googleapis.com/mediapipe-models/gesture_recognizer/'
        'gesture_recognizer/float16/1/gesture_recognizer.task',
    sha256: '97952348cf6a6a4915c2ea1496b4b37ebabc50cbbf80571435643c455f2b0482',
  );

  /// Pose Landmarker: Google's Lite float16 task bundle, version 1.
  static const poseLandmarker = DownloadAsset(
    url:
        'https://storage.googleapis.com/mediapipe-models/pose_landmarker/'
        'pose_landmarker_lite/float16/1/pose_landmarker_lite.task',
    sha256: '59929e1d1ee95287735ddd833b19cf4ac46d29bc7afddbbf6753c459690d574a',
  );

  /// Holistic Landmarker: Google's float16 task bundle, version 1.
  static const holisticLandmarker = DownloadAsset(
    url:
        'https://storage.googleapis.com/mediapipe-models/holistic_landmarker/'
        'holistic_landmarker/float16/1/holistic_landmarker.task',
    sha256: 'e2dab61191e2dcd0a15f943d8e3ed1dce13c82dfa597b9dd39f562975a50c3f8',
  );

  /// Every model above by the name an app lists to bundle it, under
  /// `hooks.user_defines.mediapipe_vision.models` in pubspec.yaml.
  static const byName = <String, DownloadAsset>{
    'face_detector': faceDetector,
    'face_landmarker': faceLandmarker,
    'object_detector': objectDetector,
    'image_classifier': imageClassifier,
    'image_embedder': imageEmbedder,
    'image_segmenter': imageSegmenter,
    'interactive_segmenter': interactiveSegmenter,
    'hand_landmarker': handLandmarker,
    'gesture_recognizer': gestureRecognizer,
    'pose_landmarker': poseLandmarker,
    'holistic_landmarker': holisticLandmarker,
  };
}
