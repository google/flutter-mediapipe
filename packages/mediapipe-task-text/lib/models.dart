/// The verified official models of the text tasks, [TextModels], which
/// `mediapipe_text.dart` also exports. `bundle_models` reads them from this
/// library alone.
library;

import 'package:mediapipe_core/mediapipe_core.dart';

/// Verified official models accepted by text task options.
abstract final class TextModels {
  /// Google's unmodified BERT sentiment classifier, float32, version 1.
  static const bertClassifier = DownloadAsset(
    url:
        'https://storage.googleapis.com/mediapipe-models/text_classifier/'
        'bert_classifier/float32/1/bert_classifier.tflite',
    sha256: '9b45012ab143d88d61e10ea501d6c8763f7202b86fa987711519d89bfa2a88b1',
  );

  /// Google's unmodified Universal Sentence Encoder, float32, version 1.
  static const universalSentenceEncoder = DownloadAsset(
    url:
        'https://storage.googleapis.com/mediapipe-models/text_embedder/'
        'universal_sentence_encoder/float32/1/universal_sentence_encoder.tflite',
    sha256: '89ad3c74175dd8caa398cc22b657296d94302d20c525c12b58b29420f7249749',
  );

  /// Google's unmodified language detector, float32, version 1.
  static const languageDetector = DownloadAsset(
    url:
        'https://storage.googleapis.com/mediapipe-models/language_detector/'
        'language_detector/float32/1/language_detector.tflite',
    sha256: '7db4f23dfe1ad8966b050b419a865da451143fd43eb6b606a256aadeeb1e5417',
  );

  /// Google's unmodified EmbeddingGemma 300M task, mixed int4/int8, version 1.
  /// Maximum sequence length: 512 tokens, including prompt and special tokens.
  static const embeddingGemma = DownloadAsset(
    url:
        'https://storage.googleapis.com/mediapipe-models/text_embedder/'
        'embedding_gemma/int4int8/1/embedding_gemma.task',
    sha256: '913b7a1edc7c7c3d1da3979ec1d0648ed9e0a370f181bb59ab177ca4b97707ad',
  );

  /// Google's unmodified Proofread 200M mixed int4/int8 model, version 1.
  static const proofreader = DownloadAsset(
    url:
        'https://storage.googleapis.com/mediapipe-models/text_proofreader/'
        '200m/1/proofread_quant_200m.litertlm',
    sha256: '2caa317d5a6f951af6e437edce3bb3a9fdedc85a7a8c2a8fcaec96318d7708cc',
  );

  /// Google's unmodified Summarization 200M mixed int4/int8 model, version 1.
  /// Supports both TLDR and key-points modes through the official task API.
  static const summarizer = DownloadAsset(
    url:
        'https://storage.googleapis.com/mediapipe-models/text_summarizer/'
        '200m/1/summarization_quant_200m_2modes.litertlm',
    sha256: '8b2d4ef09236adb9ead3127325526ba1aa5a59feb7c5de2d3f5958f27479de59',
  );

  /// Every model above by the name an app lists to bundle it, under
  /// `hooks.user_defines.mediapipe_text.models` in pubspec.yaml.
  static const byName = <String, DownloadAsset>{
    'bert_classifier': bertClassifier,
    'universal_sentence_encoder': universalSentenceEncoder,
    'language_detector': languageDetector,
    'embedding_gemma': embeddingGemma,
    'proofreader': proofreader,
    'summarizer': summarizer,
  };
}
