import 'package:mediapipe_vision/mediapipe_vision.dart';

Future<void> classifyHalves(VisionImage image) async {
  final classifier = await ImageClassifier.create(
    ImageClassifierOptions(model: VisionModels.imageClassifier, maxResults: 1),
  );
  try {
    final halves = {
      'Left': VisionRegionOfInterest(left: 0, top: 0, right: 0.5, bottom: 1),
      'Right': VisionRegionOfInterest(left: 0.5, top: 0, right: 1, bottom: 1),
    };
    for (final MapEntry(key: side, value: region) in halves.entries) {
      final result = await classifier.classify(image, regionOfInterest: region);
      final top = result.classifications.first.categories.first;
      final score = top.score.toStringAsFixed(2);
      print('$side half: ${top.categoryName} ($score)');
    }
  } finally {
    await classifier.dispose();
  }
}
