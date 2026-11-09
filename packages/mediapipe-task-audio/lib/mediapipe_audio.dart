/// Google's MediaPipe audio tasks: Audio Classifier, with one API on Android,
/// iOS, macOS, Linux, Windows and the web, and Audio Transcriber and Text to
/// Speech on 64-bit Android, iOS, macOS, Linux, Windows and the web.
///
/// Each task has `static create(options)`, Google's verbs (`classify`,
/// `transcribe`, `synthesize`), a `delegate` getter and `dispose()`. What a
/// platform's runtime cannot do throws `RuntimeUnavailableException`, and
/// the capability query reports it in advance.
library;

export 'package:mediapipe_core/mediapipe_core.dart';

export 'models.dart' show AudioModels;
export 'src/audio_classifier.dart';
export 'src/audio_transcriber.dart';
export 'src/capabilities.dart';
export 'src/speech_types.dart';
export 'src/text_to_speech.dart';
export 'src/types.dart';
export 'src/wav.dart';
