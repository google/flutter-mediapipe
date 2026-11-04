/// Audio Classifier's input, options and result: Google's names and
/// defaults, validated the same way on every platform.
library;

import 'dart:typed_data';

import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_core/platform_interface.dart'
    show ClassifierSettings, checkClassifierSettings;
import 'package:meta/meta.dart';

import '../models.dart' show AudioModels;

/// Samples to classify: interleaved frames at [sampleRate], in -1 to 1.
@immutable
final class AudioData {
  /// Wraps [samples]; [channels] values make up one frame.
  AudioData({
    required this.samples,
    required this.sampleRate,
    this.channels = 1,
  }) {
    if (sampleRate <= 0) throw ArgumentError.value(sampleRate, 'sampleRate');
    if (channels < 1 || samples.length % channels != 0) {
      throw ArgumentError.value(channels, 'channels');
    }
  }

  /// Interleaved samples: frame 0's channels, then frame 1's, and so on.
  final Float32List samples;

  /// Frames per second.
  final double sampleRate;

  /// Values per frame.
  final int channels;
}

/// How the Audio Classifier is fed, chosen when it is created; Google's
/// names.
enum AudioRunningMode {
  /// Independent clips, each classified whole with `classify`.
  audioClips,

  /// One continuous signal fed in blocks of any length with `classifyAsync`,
  /// framed into the model's windows across blocks, each window's result on
  /// `results`. Google's own stream on Android, iOS, macOS, Linux and
  /// Windows; in browsers, where Google has none, an emulation on its clips
  /// mode.
  audioStream,
}

/// Options for Google's Audio Classifier.
final class AudioClassifierOptions extends TaskOptions
    implements ClassifierSettings {
  /// Defaults match Google's: every category, no threshold.
  AudioClassifierOptions({
    super.model,
    super.modelPath,
    super.modelBytes,
    super.delegate,
    this.runningMode = AudioRunningMode.audioClips,
    this.displayNamesLocale,
    this.maxResults = -1,
    this.scoreThreshold = 0,
    List<String>? categoryAllowlist,
    List<String>? categoryDenylist,
  }) : categoryAllowlist = List.unmodifiable(categoryAllowlist ?? const []),
       categoryDenylist = List.unmodifiable(categoryDenylist ?? const []),
       super(family: 'mediapipe_audio', registry: AudioModels.byName) {
    checkClassifierSettings(this);
  }

  /// Clips, each classified whole, or a stream fed in blocks.
  final AudioRunningMode runningMode;

  /// Locale of the display names in the model metadata.
  @override
  final String? displayNamesLocale;

  /// Maximum categories per head and chunk; negative returns all of them.
  @override
  final int maxResults;

  /// Categories scoring below this are dropped.
  @override
  final double scoreThreshold;

  /// Category names to keep; exclusive with [categoryDenylist].
  @override
  final List<String> categoryAllowlist;

  /// Category names to drop; exclusive with [categoryAllowlist].
  @override
  final List<String> categoryDenylist;
}

/// The categories of one window of audio (0.975 s for YAMNet), per model
/// head.
@immutable
final class AudioClassifierResult {
  /// Owns an unmodifiable copy of [classifications].
  AudioClassifierResult({
    required List<Classifications> classifications,
    required this.timestampMilliseconds,
  }) : classifications = List.unmodifiable(classifications);

  /// One entry per model head, in the runtime's order.
  final List<Classifications> classifications;

  /// Where the window starts: in a clip, milliseconds from the clip's start;
  /// in a stream, the first block's timestamp plus the windows before it,
  /// for the tail too, which Google's native stream stamps with a sentinel
  /// instead.
  final int timestampMilliseconds;

  @override
  String toString() =>
      'AudioClassifierResult($timestampMilliseconds ms, $classifications)';
}
