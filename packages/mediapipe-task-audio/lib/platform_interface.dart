/// Where the browser plugin plugs Google's JavaScript runtime into the audio
/// tasks, and the hooks the repository's device tests read.
///
/// Applications should import `mediapipe_audio.dart` instead.
library;

export 'src/audio_task_backend.dart';
export 'src/speech_runners.dart';
export 'src/stream/results.dart' show debugGoogleStreamTimestamp;
