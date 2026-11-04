/// Where Audio Classifier runs: the registered browser adapter (Google's
/// JavaScript runtime), or Google's native runtime.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:mediapipe_core/platform_interface.dart'
    show SerialTaskQueue, classifierSettingsJson, taskException;

import 'audio_task_backend.dart';
import 'decoders.dart';
import 'stream/emulation.dart';
import 'stream/results.dart';
import 'types.dart';

/// Audio Classifier's requests on whichever runtime serves it.
abstract interface class AudioClassifierRunner {
  /// Classifies [audio] after every request submitted before it.
  Future<List<AudioClassifierResult>> classify(AudioData audio);

  /// Waits for accepted requests, then closes Google's task once.
  Future<void> dispose();
}

/// An Audio Classifier stream on whichever runtime serves it: Google's own
/// stream on Android, iOS, macOS, Linux and Windows, an emulation on its
/// clips mode in browsers. Results go to the task's [AudioStreamResults].
abstract interface class AudioStreamRunner {
  /// Hands on a block that passed the task's checks and holds samples, after
  /// every block before it.
  void send(AudioData block, int timestampMilliseconds);

  /// Flushes the tail as Google's close does, delivers what that yields,
  /// then releases Google's task. Reports a failure through the results.
  Future<void> close();
}

/// [options]' model and settings, named as in Google's JavaScript API, with
/// [modelBytes] in place of the options' model when given.
Map<String, Object?> backendSettings(
  AudioClassifierOptions options, {
  Uint8List? modelBytes,
}) => {
  'modelBytes': modelBytes ?? options.modelBytes,
  'modelPath': modelBytes == null ? options.modelPath : null,
  'delegate': options.delegate.name.toUpperCase(),
  ...classifierSettingsJson(options),
};

/// Audio Classifier on a platform plugin's backend: requests run in
/// submission order and disposal waits for them.
final class BackendAudioClassifier implements AudioClassifierRunner {
  BackendAudioClassifier._(this._task);

  final AudioTaskBackend _task;
  final _queue = SerialTaskQueue('AudioClassifier');

  /// Starts Google's task through [factory] with [options]' model and
  /// settings, named as in Google's JavaScript API; with [modelBytes] in
  /// place of the options' model when given.
  static Future<BackendAudioClassifier> open(
    Future<AudioTaskBackend> Function(Map<String, Object?>) factory,
    AudioClassifierOptions options, {
    Uint8List? modelBytes,
  }) async {
    try {
      return BackendAudioClassifier._(
        await factory(backendSettings(options, modelBytes: modelBytes)),
      );
    } catch (error) {
      throw taskException(error);
    }
  }

  /// Google's browser tasks read one channel, so several channels are
  /// averaged first.
  @override
  Future<List<AudioClassifierResult>> classify(AudioData audio) {
    final samples = monoSamples(audio.samples, audio.channels);
    return _queue.add(
      () async => decodeAudioClassifierResults(
        await _task.classify(samples, audio.sampleRate),
      ),
    );
  }

  @override
  Future<void> dispose() => _queue.close(_task.dispose);
}

/// The stream in browsers: Google's browser runtime has no stream, so the
/// emulation frames the blocks and classifies each window with the
/// browser's clips mode.
final class EmulatedStreamRunner implements AudioStreamRunner {
  /// Emulates the stream of [results]' model on a clips task, whose
  /// disposal this runner's close ends with.
  EmulatedStreamRunner(this._clips, AudioStreamResults results)
    : _stream = EmulatedAudioStream(
        results.specs,
        (samples, sampleRate, channels) => _clips.classify(
          AudioData(
            samples: samples,
            sampleRate: sampleRate,
            channels: channels,
          ),
        ),
        results,
      );

  final AudioClassifierRunner _clips;
  final EmulatedAudioStream _stream;

  @override
  void send(AudioData block, int timestampMilliseconds) => _stream.add(block);

  @override
  Future<void> close() async {
    try {
      await _stream.close();
    } finally {
      await _clips.dispose();
    }
  }
}
