import 'package:mediapipe_text/mediapipe_text.dart';

Future<void> detectLanguage(String text) async {
  final detector = await LanguageDetector.create(
    LanguageDetectorOptions(model: TextModels.languageDetector),
  );
  try {
    final result = await detector.detect(text);
    for (final prediction in result.predictions.take(3)) {
      print('${prediction.languageCode}: ${prediction.probability}');
    }
  } finally {
    await detector.dispose();
  }
}
