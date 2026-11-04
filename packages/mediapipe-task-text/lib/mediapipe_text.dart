/// Google's MediaPipe text tasks, with one API on Android, iOS, macOS,
/// Linux, Windows and the web: Text Classifier, Text Embedder (EmbeddingGemma
/// included), Language Detector, Proofreader and Summarizer.
///
/// Every task has `static create(options)`, Google's verbs (`classify`,
/// `embed`, `detect`, `proofread`, `summarize`), a `delegate` getter and
/// `dispose()`. What a platform's runtime cannot do throws
/// `RuntimeUnavailableException`, and each task's capability query reports
/// it in advance.
library;

export 'package:mediapipe_core/mediapipe_core.dart';

export 'models.dart' show TextModels;
export 'src/capabilities.dart';
export 'src/tasks/language_detector.dart';
export 'src/tasks/text_classifier.dart';
export 'src/tasks/text_embedder.dart';
export 'src/tasks/text_proofreader.dart';
export 'src/tasks/text_summarizer.dart';
export 'src/types/format_context.dart';
export 'src/types/options.dart';
export 'src/types/results.dart';
