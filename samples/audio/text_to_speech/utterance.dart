import 'dart:typed_data';

import 'package:mediapipe_audio/mediapipe_audio.dart';

/// Speaks [text] in the first Phonon voice for [locale], or in freya when
/// none speaks it, and returns null if [stop] completes first.
Future<Float32List?> speakInLocale(
  String text,
  String locale, {
  Future<void>? stop,
}) async {
  final tts = await TextToSpeech.create(
    TextToSpeechOptions(model: AudioModels.phonon, defaultVoiceId: 'freya'),
  );
  stop?.then((_) => tts.cancel());
  try {
    final voices = await tts.listVoices();
    for (final voice in voices) {
      print('${voice.voiceId} (${voice.displayName}): ${voice.locale}');
    }
    final voice = voices.where((v) => v.locale == locale).firstOrNull;
    print('Speaking in ${voice?.voiceId ?? 'the default voice'}');
    final speech = await tts.synthesize(
      text,
      voiceId: voice?.voiceId,
      locale: voice?.locale,
    );
    return speech.samples;
  } on TaskException catch (error) {
    if (error.statusCode != 1) rethrow; // 1: Google's status for cancelled
    print('Stopped');
    return null;
  } finally {
    await tts.dispose();
  }
}
