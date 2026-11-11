import 'package:mediapipe_vision/mediapipe_vision.dart';

Future<void> recognizeGestures(VisionImage image) async {
  final recognizer = await GestureRecognizer.create(
    GestureRecognizerOptions(model: VisionModels.gestureRecognizer),
  );
  try {
    final result = await recognizer.recognize(image);
    for (final gestures in result.gestures) {
      final top = gestures.first;
      print('${top.categoryName} (${top.score.toStringAsFixed(2)})');
    }
  } finally {
    await recognizer.dispose();
  }
}
