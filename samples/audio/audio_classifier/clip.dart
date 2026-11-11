import 'dart:typed_data';

import 'package:mediapipe_audio/mediapipe_audio.dart';

Future<void> classifyClip(Uint8List wavBytes) async {
  final classifier = await AudioClassifier.create(
    AudioClassifierOptions(model: AudioModels.yamnet, maxResults: 3),
  );
  try {
    final clip = decodeWav(wavBytes);
    for (final chunk in await classifier.classify(clip)) {
      final top = chunk.classifications.first.categories.first;
      print('${chunk.timestampMilliseconds} ms: ${top.categoryName}');
    }
  } finally {
    await classifier.dispose();
  }
}
