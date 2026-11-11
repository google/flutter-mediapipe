import 'dart:typed_data';

import 'package:mediapipe_audio/mediapipe_audio.dart';

/// Prints the top sound of each window of [blocks], 16 kHz mono audio.
Future<void> listen(Stream<Float32List> blocks) async {
  final classifier = await AudioClassifier.create(
    AudioClassifierOptions(
      model: AudioModels.yamnet,
      maxResults: 1,
      runningMode: AudioRunningMode.audioStream,
    ),
  );
  classifier.results.listen((window) {
    final top = window.classifications.first.categories.first;
    print('${window.timestampMilliseconds} ms: ${top.categoryName}');
  });
  var samples = 0;
  try {
    await for (final block in blocks) {
      classifier.classifyAsync(
        AudioData(samples: block, sampleRate: 16000),
        // Where the block starts, counted from the samples before it.
        timestampMilliseconds: samples * 1000 ~/ 16000,
      );
      samples += block.length;
    }
  } finally {
    // Classifies the audio short of a window, then closes `results`.
    await classifier.dispose();
  }
}
