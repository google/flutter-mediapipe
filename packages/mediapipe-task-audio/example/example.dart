import 'dart:io';

import 'package:mediapipe_audio/mediapipe_audio.dart';

/// Classifies a 16-bit PCM WAV clip from the command line with Google's pinned
/// YAMNet model: `dart run example/example.dart clip.wav`.
///
/// A Dart program has no app bundle, so this downloads the model once into
/// `.dart_tool/mediapipe_models/`, checks its SHA-256 and passes its path. A
/// Flutter app bundles the model instead, by listing `yamnet` under
/// `hooks.user_defines.mediapipe_audio.models` and running
/// `dart run mediapipe_core:bundle_models`, then passes
/// `model: AudioModels.yamnet`.
Future<void> main(List<String> arguments) async {
  final store = ModelStore(
    cacheDirectory: Directory('.dart_tool/mediapipe_models').absolute.path,
  );
  final model = await store.get(AudioModels.yamnet);
  final classifier = await AudioClassifier.create(
    AudioClassifierOptions(modelPath: model.path, maxResults: 3),
  );
  try {
    final clip = decodeWav(await File(arguments.single).readAsBytes());
    for (final chunk in await classifier.classify(clip)) {
      final labels = chunk.classifications.first.categories
          .map((c) => '${c.categoryName} ${c.score.toStringAsFixed(2)}')
          .join(', ');
      print('${chunk.timestampMilliseconds} ms: $labels');
    }
  } finally {
    await classifier.dispose();
  }
}
