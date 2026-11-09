/// Audio Transcriber's and Text to Speech's options and results: Google's
/// names and defaults, validated the same way on every platform.
library;

import 'dart:typed_data';

import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:meta/meta.dart';

import '../models.dart' show AudioModels;
import 'types.dart' show AudioData;

/// Which family of speech recognition model Google's Audio Transcriber
/// routes the model to; Google's names.
enum TranscriberModelArchitecture {
  /// Read from the model file.
  auto,

  /// An omni model's audio path.
  omni,
}

/// Options for Google's Audio Transcriber.
///
/// Google's task reads its model from a file, so it takes a pinned [model]
/// or a [modelPath], not bytes. In a browser, a [modelPath] URL keeps a model
/// as large as Parakeet out of the page's memory: a pinned [model] passes
/// through it as bytes.
final class AudioTranscriberOptions extends TaskOptions {
  /// Defaults match Google's: 16 kHz input, final results only, the model's
  /// own architecture and prompt, no compile cache.
  AudioTranscriberOptions({
    super.model,
    super.modelPath,
    super.delegate,
    int sampleRateHz = 16000,
    this.enableInterimResults = false,
    this.modelArchitecture = TranscriberModelArchitecture.auto,
    this.prompt,
    this.cacheDirectory,
  }) : sampleRateHz = sampleRateHz == 0 ? 16000 : sampleRateHz,
       super(family: 'mediapipe_audio', registry: AudioModels.byName) {
    if (sampleRateHz < 0) {
      throw ArgumentError.value(sampleRateHz, 'sampleRateHz', 'Must be >= 0');
    }
  }

  /// The rate of the audio every [AudioData] passed to `transcribe` has.
  /// Google resamples it to the model's. 0 means 16000, as in Google's API.
  final int sampleRateHz;

  /// Whether a stream also returns segments that later audio may revise.
  final bool enableInterimResults;

  /// The model family Google routes the model to.
  final TranscriberModelArchitecture modelArchitecture;

  /// A decoding prompt for generative models; null keeps the model's.
  final String? prompt;

  /// A directory where Google's runtime caches compiled model artifacts
  /// between runs. Null, the default, passes no directory, which Google's
  /// Python documents as turning the disk cache off; Parakeet wrote no cache
  /// with it on a Mac, on the CPU or the GPU, but Google's Text to Speech
  /// does with Kokoro, so pass `':nocache'`, as Google's guides say, to be
  /// sure caching is off. In a browser it is a path in the runtime's virtual
  /// file system, which goes with the page.
  final String? cacheDirectory;
}

/// One stretch of recognized speech.
@immutable
final class TranscriptionSegment {
  /// A segment as Google reports it.
  const TranscriptionSegment({
    required this.transcript,
    required this.isFinal,
    required this.fromTimestampMilliseconds,
    required this.toTimestampMilliseconds,
  });

  /// The recognized text.
  final String transcript;

  /// False for an interim hypothesis, which later audio may revise.
  final bool isFinal;

  /// Where the segment starts, in milliseconds from the stream's start.
  final int fromTimestampMilliseconds;

  /// Where the segment ends, in milliseconds from the stream's start.
  final int toTimestampMilliseconds;

  @override
  String toString() =>
      'TranscriptionSegment($fromTimestampMilliseconds-'
      '$toTimestampMilliseconds ms, ${isFinal ? 'final' : 'interim'}, '
      '"$transcript")';
}

/// What one call to the Audio Transcriber recognized.
@immutable
final class AudioTranscriberResult {
  /// Owns an unmodifiable copy of [segments].
  AudioTranscriberResult(List<TranscriptionSegment> segments)
    : segments = List.unmodifiable(segments);

  /// The segments, in order.
  final List<TranscriptionSegment> segments;

  /// Every segment's trimmed text that is not empty, joined by spaces, as
  /// Google's Python `text` reads it.
  String get text => [
    for (final segment in segments)
      if (segment.transcript.trim() case final text when text.isNotEmpty) text,
  ].join(' ');

  @override
  String toString() => 'AudioTranscriberResult($segments)';
}

/// Options for Google's Text to Speech.
///
/// Google's task reads its model from a file, so it takes a pinned [model]
/// or a [modelPath], not bytes.
final class TextToSpeechOptions extends TaskOptions {
  /// Defaults match Google's Web, Android and iOS tasks: the engine's default
  /// voice, the locale that voice speaks, normal speed, the model's default
  /// bucket, and no cache directory (Kokoro then caches next to its model
  /// file). (Google's Python alone defaults to US English.)
  TextToSpeechOptions({
    super.model,
    super.modelPath,
    super.delegate,
    this.defaultVoiceId,
    this.defaultLocale,
    this.speakingRate = 1,
    this.targetBucket = 0,
    this.cacheDirectory,
  }) : super(family: 'mediapipe_audio', registry: AudioModels.byName) {
    if (!(speakingRate > 0 && speakingRate <= 4)) {
      throw ArgumentError.value(
        speakingRate,
        'speakingRate',
        'Must be in (0, 4]',
      );
    }
    if (!const {0, 64, 128, 256}.contains(targetBucket)) {
      throw ArgumentError.value(
        targetBucket,
        'targetBucket',
        'Must be 0, 64, 128 or 256',
      );
    }
  }

  /// The voice a call without its own uses; null or empty is the model's
  /// default voice.
  final String? defaultVoiceId;

  /// The BCP-47 locale a call without its own uses; null or empty infers it
  /// from the voice.
  final String? defaultLocale;

  /// Speed: 1 is normal, 2 twice as fast; in (0, 4].
  final double speakingRate;

  /// The sequence-length bucket for Kokoro's static-shape graph: 64, 128 or
  /// 256 tokens, the values Google's guide lists, or 0 for the model's default
  /// capacity. Phonon and PocketTTS ignore it.
  final int targetBucket;

  /// A directory where Google's runtime caches unpacked model files and
  /// compiled weights between runs. Null, the default, passes no directory,
  /// and Google's runtime then caches Kokoro's compiled weights next to the
  /// model file: on a Mac, about 73 MB of XNNPACK caches on the CPU, and
  /// about 34 MB of XNNPACK and GPU program and weight caches on the GPU.
  /// Phonon wrote none. Google's Python documents null as turning the disk
  /// cache off, which it does not do for Kokoro; pass `':nocache'` to turn
  /// caching off, as Google's guide says. In a browser it is a path in the
  /// runtime's virtual file system, which goes with the page.
  final String? cacheDirectory;
}

/// A voice the loaded model can speak in.
@immutable
final class TextToSpeechVoice {
  /// A voice as Google lists it.
  const TextToSpeechVoice({
    required this.voiceId,
    required this.displayName,
    required this.locale,
    required this.sampleRateHz,
    required this.isDownloaded,
  });

  /// The id calls pass to pick this voice.
  final String voiceId;

  /// A name to show people.
  final String displayName;

  /// The BCP-47 locale the voice speaks.
  final String locale;

  /// The rate of the audio this voice produces.
  final int sampleRateHz;

  /// Whether the voice's weights are in the model file.
  final bool isDownloaded;

  @override
  String toString() =>
      'TextToSpeechVoice($voiceId, "$displayName", $locale, $sampleRateHz Hz)';
}

/// When one word of the input is spoken.
@immutable
final class WordTimestamp {
  /// A word's timing.
  const WordTimestamp({
    required this.word,
    required this.start,
    required this.end,
    required this.startSeconds,
    required this.endSeconds,
  });

  /// The word as it appears in the input.
  final String word;

  /// Where the word starts in the input string, as a UTF-16 index, so
  /// `text.substring(start, end)` is the word. Google reports UTF-8 byte
  /// offsets; this package converts them.
  final int start;

  /// Where the word ends in the input string, exclusive.
  final int end;

  /// When the word starts in the audio, in seconds.
  final double startSeconds;

  /// When the word ends in the audio, in seconds.
  final double endSeconds;

  @override
  String toString() =>
      'WordTimestamp("$word" $start-$end, ${startSeconds}s-${endSeconds}s)';
}

/// Synthesized audio: a whole utterance from `synthesize`, or one chunk of
/// `synthesizeStream`.
@immutable
final class TextToSpeechResult {
  /// Owns [samples] and an unmodifiable copy of [wordTimestamps].
  TextToSpeechResult({
    required this.samples,
    required this.sampleRateHz,
    List<WordTimestamp> wordTimestamps = const [],
    this.chunkIndex = 0,
    this.isFinal = true,
  }) : wordTimestamps = List.unmodifiable(wordTimestamps);

  /// Mono samples in -1 to 1.
  final Float32List samples;

  /// The rate of [samples].
  final int sampleRateHz;

  /// When each word is spoken, for read-along highlighting.
  final List<WordTimestamp> wordTimestamps;

  /// The chunk's position in a stream, from 0; 0 for a whole utterance.
  final int chunkIndex;

  /// Whether this is the stream's last chunk; true for a whole utterance.
  final bool isFinal;

  /// How long [samples] play.
  Duration get duration => Duration(
    microseconds: sampleRateHz > 0
        ? samples.length * Duration.microsecondsPerSecond ~/ sampleRateHz
        : 0,
  );

  /// [samples] as [AudioData], for the Audio Classifier or the Audio
  /// Transcriber.
  AudioData toAudioData() =>
      AudioData(samples: samples, sampleRate: sampleRateHz.toDouble());

  @override
  String toString() =>
      'TextToSpeechResult(${samples.length} samples at $sampleRateHz Hz, '
      'chunk $chunkIndex${isFinal ? ', final' : ''}, '
      '${wordTimestamps.length} words)';
}
