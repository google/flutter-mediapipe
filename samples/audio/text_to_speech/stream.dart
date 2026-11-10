import 'dart:typed_data';

import 'package:mediapipe_audio/mediapipe_audio.dart';

/// Speaks [text] with Phonon, handing each chunk to [play] as soon as it is
/// ready. Completing [stop], from a Stop button for example, cancels the
/// rest.
Future<void> speakAsReady(
  String text, {
  required void Function(Float32List samples, int sampleRateHz) play,
  Future<void>? stop,
}) async {
  final tts = await TextToSpeech.create(
    TextToSpeechOptions(model: AudioModels.phonon),
  );
  final chunks = tts.synthesizeStream(text, voiceId: 'freya').listen((chunk) {
    // Chunk 0 can start playing while the rest is synthesized.
    play(chunk.samples, chunk.sampleRateHz);
    for (final word in chunk.wordTimestamps) {
      // Times count from the stream's start, not the chunk's.
      final spoken = text.substring(word.start, word.end);
      final at = word.startSeconds.toStringAsFixed(2);
      print('chunk ${chunk.chunkIndex}: $spoken at $at s');
    }
  });
  try {
    await Future.any([
      chunks.asFuture<void>(),
      if (stop != null) stop.then((_) => chunks.cancel()),
    ]);
  } finally {
    await tts.dispose();
  }
}
