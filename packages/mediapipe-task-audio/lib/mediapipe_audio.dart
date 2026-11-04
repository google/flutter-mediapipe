/// Google's MediaPipe Audio Classifier, with one API on Android, iOS, macOS,
/// Linux, Windows and the web.
///
/// The task has `static create(options)`, Google's verb `classify`, a
/// `delegate` getter and `dispose()`. What a platform's runtime cannot do
/// throws `RuntimeUnavailableException`, and the capability query reports
/// it in advance.
library;

export 'package:mediapipe_core/mediapipe_core.dart';

export 'models.dart' show AudioModels;
export 'src/audio_classifier.dart';
export 'src/capabilities.dart';
export 'src/types.dart';
export 'src/wav.dart';
