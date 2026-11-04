/// The one set of checks every Audio Classifier call runs, on every platform,
/// before Google's runtime sees it, so the same call fails the same way
/// everywhere.
library;

import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_core/platform_interface.dart'
    show checkStreamTimestamp;

import '../types.dart';
import 'model_specs.dart';

/// Mode, lifecycle, rate, channel and timestamp checks for one task.
final class AudioStreamChecks {
  /// Checks for a task created in [runningMode].
  AudioStreamChecks(this.runningMode);

  /// The mode the task was created in.
  final AudioRunningMode runningMode;

  /// The model's audio input, read once Google's stream task is open; a
  /// clips task never reads it.
  late final AudioModelSpecs specs;

  double? _sampleRate;
  int? _lastTimestamp;
  bool _disposing = false;

  /// A failure that ended the stream; every later block rethrows it.
  TaskException? failure;

  /// Rejects every later call.
  void markDisposing() => _disposing = true;

  /// Checks a clip.
  void clip() {
    _open();
    requireMode(AudioRunningMode.audioClips);
  }

  /// Checks a block of a stream in the contract's order, then fixes the
  /// stream's rate with the first block and reserves the block's timestamp.
  /// A block refused for its rate or channels reserves nothing.
  void block(
    AudioData block,
    int timestampMilliseconds, {
    required bool listening,
  }) {
    _open();
    requireMode(AudioRunningMode.audioStream);
    if (!listening) {
      throw StateError(
        'Listen to AudioClassifier.results before submitting the first '
        'block.',
      );
    }
    if (_sampleRate case final rate? when block.sampleRate != rate) {
      throw ArgumentError.value(
        block.sampleRate,
        'sampleRate',
        'The stream runs at ${_hertz(rate)} Hz, fixed by its first block',
      );
    }
    final channels = specs.channels;
    // Google mixes any input down for a mono model and refuses any other
    // mismatch (audio_to_tensor_calculator.cc).
    if (channels != 1 && block.channels != channels) {
      throw ArgumentError.value(
        block.channels,
        'channels',
        'The model requires $channels channel(s)',
      );
    }
    checkStreamTimestamp(timestampMilliseconds, _lastTimestamp);
    _sampleRate ??= block.sampleRate;
    _lastTimestamp = timestampMilliseconds;
  }

  /// Rejects a call that belongs to the other running mode.
  void requireMode(AudioRunningMode expected) {
    if (runningMode != expected) {
      throw StateError(
        'AudioClassifier was created in ${runningMode.name} mode; this method '
        'requires ${expected.name} mode.',
      );
    }
  }

  void _open() {
    if (_disposing) throw StateError('AudioClassifier has been disposed.');
    if (failure case final error?) throw error;
  }
}

/// A rate as the native VM prints a double, in browsers too, whose numbers
/// print a whole value without its decimal point.
String _hertz(double rate) =>
    rate == rate.truncateToDouble() ? rate.toStringAsFixed(1) : '$rate';
