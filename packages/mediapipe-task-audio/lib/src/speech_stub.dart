/// Browsers have no native runtime: this package's web plugin installs Google's
/// browser runtime in its place.
library;

import 'package:mediapipe_core/mediapipe_core.dart';

import 'audio_task_backend.dart';
import 'speech_runners.dart';
import 'speech_types.dart';

/// Google's Audio Transcriber through the web plugin.
Future<AudioTranscriberRunner> openNativeAudioTranscriber(
  AudioTranscriberOptions options,
) async => switch (audioTranscriberOpener) {
  final open? => await open(options),
  null => throw _noPlugin('Audio Transcriber'),
};

/// Google's Text to Speech through the web plugin.
Future<TextToSpeechRunner> openNativeTextToSpeech(
  TextToSpeechOptions options,
) async => switch (textToSpeechOpener) {
  final open? => await open(options),
  null => throw _noPlugin('Text to Speech'),
};

RuntimeUnavailableException _noPlugin(String task) =>
    RuntimeUnavailableException(
      "$task's browser runtime is not registered.",
      fix: 'Run it in a Flutter web build, which registers the audio plugin.',
    );
