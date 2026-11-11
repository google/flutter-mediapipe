import 'dart:typed_data';

import 'package:mediapipe_audio/mediapipe_audio.dart';

/// Prints what Parakeet hears in [blocks], 16 kHz mono audio, as it hears it.
Future<void> transcribeLive(Stream<Float32List> blocks) async {
  final transcriber = await AudioTranscriber.create(
    AudioTranscriberOptions(
      model: AudioModels.parakeetTdtV3,
      enableInterimResults: true,
    ),
  );
  void show(AudioTranscriberResult result) {
    for (final segment in result.segments) {
      print(
        '${segment.fromTimestampMilliseconds}-'
        '${segment.toTimestampMilliseconds} ms '
        '${segment.isFinal ? 'final' : 'interim'}: ${segment.transcript}',
      );
    }
  }

  try {
    await for (final block in blocks) {
      final audio = AudioData(samples: block, sampleRate: 16000);
      show(await transcriber.transcribe(audio, endOfStream: false));
    }
    show(await transcriber.finishStream());
  } finally {
    await transcriber.dispose();
  }
}
