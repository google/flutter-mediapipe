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

Future<Float32List> speak(String text) async {
  final tts = await TextToSpeech.create(
    TextToSpeechOptions(model: AudioModels.phonon),
  );
  try {
    final speech = await tts.synthesize(text, voiceId: 'freya');
    for (final word in speech.wordTimestamps) {
      print('${word.word} at ${word.startSeconds} s');
    }
    return speech.samples; // mono, at speech.sampleRateHz (24 kHz)
  } finally {
    await tts.dispose();
  }
}
