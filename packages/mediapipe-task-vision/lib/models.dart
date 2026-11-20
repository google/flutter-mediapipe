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
        'https://huggingface.co/litert-community/'
        'MediaPipe-FaceDetector-BlazeFace-Short-Range/resolve/'
        '1ab2d0325e858c9aa0bbf89e85a759ec7e394f25/'
        'blaze_face_short_range.tflite',
    sha256: 'b4578f35940bf5a1a655214a1cce5cab13eba73c1297cd78e1a04c2380b0152f',
  );

  /// Face Landmarker: Google's float16 bundle, version 1, holding the face
  /// detector, the 478-landmark model and the blendshape model.
  static const faceLandmarker = DownloadAsset(
    url:
        'https://huggingface.co/litert-community/'
        'MediaPipe-FaceLandmarker/resolve/'
        'cfb66f449dc5cb9f8dada3d52174d4cdae1c9ef1/'
        'face_landmarker.task',
    sha256: '64184e229b263107bc2b804c6625db1341ff2bb731874b0bcc2fe6544e0bc9ff',
  );

  /// Object Detector: Google's EfficientDet-Lite0 float32 detector, version
  /// 1, with the 80 COCO classes. Float32 rather than int8 because Metal needs
  /// a float model; see tool/GPU_VALIDATION.md.
  static const objectDetector = DownloadAsset(
    url:
        'https://huggingface.co/litert-community/'
        'MediaPipe-ObjectDetector-EfficientDet-Lite0/resolve/'
        '2c3b3e2fc45b9fddf8ef8ad03a63ca874458add6/'
        'efficientdet_lite0_float32.tflite',
    sha256: '40338edf5ec70d43e318b0a716a84d4564cd1802759a7a07170c7e43796dbf58',
  );

  /// Image Classifier: Google's ImageNet EfficientNet-Lite0 float32
  /// classifier, version 1.
  static const imageClassifier = DownloadAsset(
    url:
        'https://huggingface.co/litert-community/'
        'MediaPipe-ImageClassifier-EfficientNet-Lite0/resolve/'
        'a41ac2f251fb8f9e1f0d8cc12eea427d1c379cbc/'
        'efficientnet_lite0_float32.tflite',
    sha256: '6c7ab0a6e5dcbf38a8c33b960996a55a3b4300b36a018c4545801de3a3c8bde0',
  );

  /// Image Embedder: Google's MobileNet-V3 small float32 embedder, version 1.
  static const imageEmbedder = DownloadAsset(
    url:
        'https://huggingface.co/litert-community/'
        'MediaPipe-ImageEmbedder-MobileNet-V3-Small/resolve/'
        '45a8f4237a3175e9d580be1e267b10681f323813/'
        'mobilenet_v3_small.tflite',
    sha256: 'bbbb4c51a55a53905af1daec995ca1aae355046f8839bb8c9f5ce9271394bc40',
  );

  /// Image Segmenter: Google's DeepLab-v3 float32 model, version 1.
  static const imageSegmenter = DownloadAsset(
    url:
        'https://huggingface.co/litert-community/'
        'MediaPipe-ImageSegmenter-DeepLab-V3/resolve/'
        '739202fd92e4a822ba439afe91bdf69254227d94/'
        'deeplab_v3.tflite',
    sha256: 'ff36e24d40547fe9e645e2f4e8745d1876d6e38b332d39a82f0bf0f5d1d561b3',
  );

  /// Interactive Segmenter: Google's stateful MagicTouch int8 encoder and
  /// decoder bundle, version 1.
  static const interactiveSegmenter = DownloadAsset(
    url:
        'https://huggingface.co/litert-community/'
        'MediaPipe-InteractiveSegmenter-MagicTouch/resolve/'
        '61de3ef0dcf18e1ad21636bb206439dff5cf516d/'
        'interactive_segmentation.task',
    sha256: '38431bc66b883404e8397f74c3579404315b9b52b04a46c6346fe906a7309b03',
  );

  /// Hand Landmarker: Google's float16 task bundle, version 1.
  static const handLandmarker = DownloadAsset(
    url:
        'https://huggingface.co/litert-community/'
        'MediaPipe-HandLandmarker-Full/resolve/'
        '74806d5014cdd5bd6ce94a80a0e4e93ae4cf2f9b/'
        'hand_landmarker.task',
    sha256: 'fbc2a30080c3c557093b5ddfc334698132eb341044ccee322ccf8bcf3607cde1',
  );

  /// Gesture Recognizer: Google's float16 task bundle, version 1.
  static const gestureRecognizer = DownloadAsset(
    url:
        'https://huggingface.co/litert-community/'
        'MediaPipe-GestureRecognizer/resolve/'
        'cdc67a52ca3c423d75bb32c5e636a94a2163cf73/'
        'gesture_recognizer.task',
    sha256: '97952348cf6a6a4915c2ea1496b4b37ebabc50cbbf80571435643c455f2b0482',
  );

  /// Pose Landmarker: Google's Lite float16 task bundle, version 1.
  static const poseLandmarker = DownloadAsset(
    url:
        'https://huggingface.co/litert-community/'
        'MediaPipe-PoseLandmarker-Lite/resolve/'
        '105f65fd3484e46a25fe517a3722932d4392083c/'
        'pose_landmarker_lite.task',
    sha256: '59929e1d1ee95287735ddd833b19cf4ac46d29bc7afddbbf6753c459690d574a',
  );

  /// Holistic Landmarker: Google's float16 task bundle, version 1.
  static const holisticLandmarker = DownloadAsset(
    url:
        'https://huggingface.co/litert-community/'
        'MediaPipe-HolisticLandmarker/resolve/'
        '4f2fac960e1bbb53343073a56ff524a1cfcc177e/'
        'holistic_landmarker.task',
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
