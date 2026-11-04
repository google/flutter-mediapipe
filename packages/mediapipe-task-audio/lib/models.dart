/// The verified official models of the Audio Classifier, [AudioModels], which
/// `mediapipe_audio.dart` also exports. `bundle_models` reads them from this
/// library alone.
library;

import 'package:mediapipe_core/mediapipe_core.dart';

/// Verified official models accepted by audio task options.
abstract final class AudioModels {
  /// Google's YAMNet audio classifier, version 1, as MediaPipe Studio uses it.
  static const yamnet = DownloadAsset(
    url:
        'https://storage.googleapis.com/mediapipe-models/'
        'audio_classifier/yamnet/float32/1/yamnet.tflite',
    sha256: '4d8b4a53282dc83ef04e3e7dbc4fbc98082e34e44ed798e16c3a0cdd4c584faf',
  );

  /// Every model above by the name an app lists to bundle it, under
  /// `hooks.user_defines.mediapipe_audio.models` in pubspec.yaml.
  static const byName = <String, DownloadAsset>{'yamnet': yamnet};
}
