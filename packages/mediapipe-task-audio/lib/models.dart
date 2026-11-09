/// The verified official models of the audio tasks, [AudioModels], which
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

  /// NVIDIA's Parakeet TDT 0.6B v3 speech recognizer for the Audio
  /// Transcriber, as Google's LiteRT community converted it (int8, 5 s
  /// stateful windows, 25 European languages): 615 MB, CC BY 4.0.
  static const parakeetTdtV3 = DownloadAsset(
    url:
        'https://huggingface.co/litert-community/parakeet-tdt-0.6b-v3/'
        'resolve/1f78e5eb6175b1b2cce35f16bcf9e2027b83e8bd/'
        'parakeet_tdt_0.6b_v3_5s_i8_stateful.litertlm',
    sha256: '66c5a74cf6c2c1d2b990901f6cece5bb53e3214dbceafa0989900a6f0eeb3504',
  );

  /// Gradium's Phonon 31M voices for Text to Speech, as Google's LiteRT
  /// community converted them (int8; five voices at 24 kHz, `freya` by
  /// default): 87 MB, Apache 2.0. Google's guide says Phonon speaks US
  /// English only. Its 1.2.2 runtime labels four of the voices with other
  /// locales (`claire` fr-FR, `lukas` de-DE, `sofia` es-ES, `lucas` pt-BR);
  /// for other languages, use [kokoro].
  static const phonon = DownloadAsset(
    url:
        'https://huggingface.co/litert-community/phonon-31m-en/resolve/'
        '63a6170895a34600560f80dce4c70f7c90e32956/phonon_int8.litertlm',
    sha256: 'b33a9a0d65acec36762db38a2bff6d899f4aab34b196bb56d89fab5665eabebe',
  );

  /// hexgrad's Kokoro 82M voices for Text to Speech, as Google's LiteRT
  /// community converted them (int8, with an FP16 vocoder for the GPU
  /// delegate; English, Spanish, French, Italian, Portuguese, Hindi, Chinese
  /// and Japanese at 24 kHz): 295 MB, Apache 2.0.
  ///
  /// This is the file Google's guide uses, with the GPU delegate. Its model
  /// card warns that on the CPU delegate, or with no GPU accelerator, its
  /// vocoder runs on the CPU and the speech, though intelligible, may be
  /// noisier, and names `kokoro_int8_fp16.litertlm` for CPU-only devices.
  /// This package offers Kokoro the GPU delegate only on macOS 15 and later
  /// on arm64; elsewhere it runs on the CPU. That file is not pinned: pass a
  /// `modelPath` to a copy of it to load it.
  static const kokoro = DownloadAsset(
    url:
        'https://huggingface.co/litert-community/Kokoro-82M/resolve/'
        '33ad69fec6c4d9eb10a547aaf9a8c63e7c446a56/'
        'kokoro_int8_gpu_fp16.litertlm',
    sha256: '1ef178b127ec48c737daf17eabb4cea5f6b3ffbc510aced270fe5c267bbeac52',
  );

  /// Kyutai's PocketTTS 100M English voices for Text to Speech, as Google's
  /// LiteRT community converted them (int8, CPU only; eight US English
  /// voices at 24 kHz, `alba` by default): 163 MB, CC BY 4.0, so an app
  /// that ships it credits Kyutai, as in its open source notices.
  static const pocketTtsEn = DownloadAsset(
    url:
        'https://huggingface.co/litert-community/pocket-tts/resolve/'
        '03f949ec418ccd4d153008f7ef9c58c754cc0616/'
        'pocket_tts_en_int8.litertlm',
    sha256: '465e0083cd61188772aed76160b07af0dcf59057497d7659f43f3f2b13a174a1',
  );

  /// Every model above by the name an app lists to bundle it, under
  /// `hooks.user_defines.mediapipe_audio.models` in pubspec.yaml.
  static const byName = <String, DownloadAsset>{
    'yamnet': yamnet,
    'parakeet_tdt_v3': parakeetTdtV3,
    'phonon': phonon,
    'kokoro': kokoro,
    'pocket_tts_en': pocketTtsEn,
  };
}
