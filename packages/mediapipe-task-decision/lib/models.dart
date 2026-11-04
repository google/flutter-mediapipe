/// The verified official models of the Decision Maker, [DecisionModels], which
/// `mediapipe_decision.dart` also exports. `bundle_models` reads them from this
/// library alone.
library;

import 'package:mediapipe_core/mediapipe_core.dart';

/// Verified official models accepted by `DecisionMakerOptions`.
///
/// Google's cross-encoder decision models, Laya and GLiNER2.5-Decide, and
/// the EmbeddingGemma 2 bi-encoder, as Google's Decision Maker guide lists
/// them. The `s256` and `s512` variants read up to 256 or 512 tokens.
abstract final class DecisionModels {
  /// Laya, float32, 256 tokens: 678 MB. The model the gallery runs.
  static const layaS256 = DownloadAsset(
    url:
        'https://storage.googleapis.com/mediapipe-models/decision_maker/'
        'laya/float32/laya_s256/1/laya_s256.task',
    sha256: '8cb730b89ef99cb5c98cdbc7936de79deab77623ce25dc0031eec9e25c64c24e',
  );

  /// Laya, float32, 512 tokens: 679 MB.
  static const layaS512 = DownloadAsset(
    url:
        'https://storage.googleapis.com/mediapipe-models/decision_maker/'
        'laya/float32/laya_s512/1/laya_s512.task',
    sha256: 'e9f1693861c9a79a541d6f716648142ee844fd2e7119c9ed48d166f4b85a15df',
  );

  /// GLiNER2.5-Decide, float16, 256 tokens: 981 MB.
  static const glinerS256 = DownloadAsset(
    url:
        'https://storage.googleapis.com/mediapipe-models/decision_maker/'
        'gliner/float16/gliner_s256/1/gliner_s256.task',
    sha256: '18e8eb07a06e3833c4ebb4b0a32c76bff0e1197acba0e4c1658b121d01c92674',
  );

  /// GLiNER2.5-Decide, float16, 512 tokens: 1.08 GB.
  static const glinerS512 = DownloadAsset(
    url:
        'https://storage.googleapis.com/mediapipe-models/decision_maker/'
        'gliner/float16/gliner_s512/1/gliner_s512.task',
    sha256: '23a02e1b286fab7573ef2a00acbd8bf80fd2b1284de25eb8fafcd74f8bccd7ec',
  );

  /// EmbeddingGemma 2, text, 270M parameters: 165 MB. A bi-encoder backend
  /// in Google's Decision Maker guide, and the model Google's web demo starts
  /// with: as fast as Laya here at a quarter of the download. From Google's
  /// LiteRT community on Hugging Face, Apache 2.0, pinned to its revision.
  static const embeddingGemma2Text = DownloadAsset(
    url:
        'https://huggingface.co/litert-community/'
        'embeddinggemma-2-text-270m-litert-lm/resolve/'
        '9be6e8b90982095dc05c2bd162e4b954ee4dbac7/'
        'embeddinggemma-2-text-270m.litertlm',
    sha256: '2d079ee2f6f066b1f368e8d7c819f55214eaef1d0513b312321901f30ab286fb',
  );

  /// EmbeddingGemma 2, text and images, 440M parameters: 388 MB. The same
  /// text encoder as [embeddingGemma2Text] with a vision encoder Decision
  /// Maker never runs, so it answers as that model does, at more than twice
  /// the download. The same pin as `RetrievalModels.embeddingGemma2TextVision`,
  /// downloaded once for both packages.
  static const embeddingGemma2TextVision = DownloadAsset(
    url:
        'https://huggingface.co/litert-community/'
        'embeddinggemma-2-text-vision-440m-litert-lm/resolve/'
        'e301f74d5551b0c2641bd5cb4652a76239d5c5f8/'
        'embeddinggemma-2-text-vision-440m.litertlm',
    sha256: '92dcbea108899e5d6e30d919b0744f90d9967e80c67a4ab5503ac16d54f62eb0',
  );

  /// Every model above by the name an app lists to bundle it, under
  /// `hooks.user_defines.mediapipe_decision.models` in pubspec.yaml.
  static const byName = <String, DownloadAsset>{
    'laya_s256': layaS256,
    'laya_s512': layaS512,
    'gliner_s256': glinerS256,
    'gliner_s512': glinerS512,
    'embedding_gemma_2_text': embeddingGemma2Text,
    'embedding_gemma_2_text_vision': embeddingGemma2TextVision,
  };
}
