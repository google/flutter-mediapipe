import 'dart:io';

import 'package:mediapipe_vision/mediapipe_vision.dart';

/// Finds the faces in a photo from the command line with Google's pinned
/// BlazeFace model: `dart run example/example.dart photo.jpg`.
///
/// A Dart program has no app bundle, so this downloads the model once into
/// `.dart_tool/mediapipe_models/`, checks its SHA-256 and passes its path. A
/// Flutter app bundles the model instead, by listing `face_detector` under
/// `hooks.user_defines.mediapipe_vision.models` and running
/// `dart run mediapipe_core:bundle_models`, then passes
/// `model: VisionModels.faceDetector`.
Future<void> main(List<String> arguments) async {
  final store = ModelStore(
    cacheDirectory: Directory('.dart_tool/mediapipe_models').absolute.path,
  );
  final model = await store.get(VisionModels.faceDetector);
  final detector = await FaceDetector.create(
    FaceDetectorOptions(modelPath: model.path),
  );
  try {
    final result = await detector.detect(
      VisionImage.fromFile(arguments.single),
    );
    print(
      '${result.detections.length} face(s) in a '
      '${result.imageWidth} x ${result.imageHeight} image',
    );
    for (final face in result.detections) {
      final box = face.boundingBox;
      print(
        'score ${face.categories.first.score.toStringAsFixed(3)}, '
        'box (${box.left}, ${box.top}) ${box.width} x ${box.height}',
      );
    }
  } finally {
    await detector.dispose();
  }
}
