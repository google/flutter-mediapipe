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
        'https://huggingface.co/litert-community/'
        'MediaPipe-TextClassifier-MobileBERT/resolve/'
        'ed51b3985b8cfe3b16e0c70d0c706a0f04bc15d4/'
        'bert_classifier.tflite',
    sha256: '9b45012ab143d88d61e10ea501d6c8763f7202b86fa987711519d89bfa2a88b1',
  );

  /// Google's unmodified Universal Sentence Encoder, float32, version 1.
  static const universalSentenceEncoder = DownloadAsset(
    url:
        'https://huggingface.co/litert-community/'
        'MediaPipe-TextEmbedder-Universal-Sentence-Encoder/resolve/'
        '832fd94a3ddabfb9ed79abee611e95040c3c756a/'
        'universal_sentence_encoder.tflite',
    sha256: '89ad3c74175dd8caa398cc22b657296d94302d20c525c12b58b29420f7249749',
  );

  /// Google's unmodified language detector, float32, version 1.
  static const languageDetector = DownloadAsset(
    url:
        'https://huggingface.co/litert-community/'
        'MediaPipe-LanguageDetector/resolve/'
        '58112979e05eaf888cfd26e5924a4b9743bfd99f/'
        'language_detector.tflite',
    sha256: '7db4f23dfe1ad8966b050b419a865da451143fd43eb6b606a256aadeeb1e5417',
  );

  /// Google's unmodified EmbeddingGemma 300M task, mixed int4/int8, version 1.
  /// Maximum sequence length: 512 tokens, including prompt and special tokens.
  static const embeddingGemma = DownloadAsset(
    url:
        'https://huggingface.co/litert-community/'
        'MediaPipe-TextEmbedder-EmbeddingGemma-300M/resolve/'
        '93c96b51d328c85e4cbbfe3039d3cd9b98d8a55d/'
        'embedding_gemma.task',
    sha256: '913b7a1edc7c7c3d1da3979ec1d0648ed9e0a370f181bb59ab177ca4b97707ad',
  );

  /// Google's unmodified Proofread 200M mixed int4/int8 model, version 1.
  static const proofreader = DownloadAsset(
    url:
        'https://huggingface.co/litert-community/'
        'MediaPipe-TextProofreader-200M/resolve/'
        '7f5d1124f2adc535113f671268eca8c5b65df77e/'
        'proofread_quant_200m.litertlm',
    sha256: '2caa317d5a6f951af6e437edce3bb3a9fdedc85a7a8c2a8fcaec96318d7708cc',
  );

  /// Google's unmodified Summarization 200M mixed int4/int8 model, version 1.
  /// Supports both TLDR and key-points modes through the official task API.
  static const summarizer = DownloadAsset(
    url:
        'https://huggingface.co/litert-community/'
        'MediaPipe-TextSummarizer-200M/resolve/'
        'e59af6de5d4753422ce706280d0371fdc223b1ba/'
        'summarization_quant_200m_2modes.litertlm',
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
