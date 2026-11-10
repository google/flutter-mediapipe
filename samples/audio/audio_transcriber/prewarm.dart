import 'package:mediapipe_audio/mediapipe_audio.dart';

/// Prints Parakeet's transcript of each of [clips], which share one rate,
/// warming the task up first.
Future<void> transcribeAll(List<AudioData> clips) async {
  final transcriber = await AudioTranscriber.create(
    AudioTranscriberOptions(
      model: AudioModels.parakeetTdtV3,
      sampleRateHz: clips.first.sampleRate.round(),
    ),
  );
  try {
    await transcriber.prewarm();
    for (final clip in clips) {
      print((await transcriber.transcribe(clip)).text);
    }
  } finally {
    await transcriber.dispose();
  }
}
