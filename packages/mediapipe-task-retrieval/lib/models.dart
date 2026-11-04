/// The verified official models of the retrieval tasks, [RetrievalModels],
/// which `mediapipe_retrieval.dart` also exports. `bundle_models` reads them
/// from this library alone.
library;

import 'package:mediapipe_core/mediapipe_core.dart';

/// Verified official models accepted by `UniversalEmbedderOptions`.
///
/// Google's EmbeddingGemma 2 models with a vision encoder, as its Universal
/// Embedder guide lists them, from Google's LiteRT community on Hugging Face,
/// Apache 2.0, pinned to their revisions. Both embed into 768 dimensions.
/// Google's engine refuses the text-only EmbeddingGemma 2 (270M) for this
/// task: "tf_lite_vision_encoder not found in the model".
abstract final class RetrievalModels {
  /// EmbeddingGemma 2, text and images, 440M parameters: 388 MB. The model
  /// the gallery runs.
  static const embeddingGemma2TextVision = DownloadAsset(
    url:
        'https://huggingface.co/litert-community/'
        'embeddinggemma-2-text-vision-440m-litert-lm/resolve/'
        'e301f74d5551b0c2641bd5cb4652a76239d5c5f8/'
        'embeddinggemma-2-text-vision-440m.litertlm',
    sha256: '92dcbea108899e5d6e30d919b0744f90d9967e80c67a4ab5503ac16d54f62eb0',
  );

  /// EmbeddingGemma 2, text, images and audio, 740M parameters: 485 MB.
  static const embeddingGemma2 = DownloadAsset(
    url:
        'https://huggingface.co/litert-community/'
        'embeddinggemma-2-740m-litert-lm/resolve/'
        '24d962e906c7d332c6428e71c9676855024569e2/'
        'embeddinggemma-2-740m.litertlm',
    sha256: 'e7a8a2204b91e0f96e92960e84a09a89212e1633dcb7575a9bf3378b4df77f4c',
  );

  /// Every model above by the name an app lists to bundle it, under
  /// `hooks.user_defines.mediapipe_retrieval.models` in pubspec.yaml.
  static const byName = <String, DownloadAsset>{
    'embedding_gemma_2_text_vision': embeddingGemma2TextVision,
    'embedding_gemma_2': embeddingGemma2,
  };
}
