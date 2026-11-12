import 'dart:typed_data';

import 'package:mediapipe_audio/mediapipe_audio.dart';

Future<String> transcribeClip(Uint8List wavBytes) async {
  final clip = decodeWav(wavBytes);
  final transcriber = await AudioTranscriber.create(
    AudioTranscriberOptions(
      model: AudioModels.parakeetTdtV3,
      sampleRateHz: clip.sampleRate.round(),
    ),
  );
  try {
    return (await transcriber.transcribe(clip)).text;
  } finally {
    await transcriber.dispose();
  }
}
