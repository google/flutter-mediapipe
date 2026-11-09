import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_core/platform_interface.dart';

import 'capabilities.dart';
import 'native_tasks.dart';
import 'speech_runners.dart';
import 'speech_types.dart';
import 'stream/emulation.dart' show monoSamples;
import 'types.dart';

/// Google's Audio Transcriber (for example Parakeet TDT 0.6B v3): speech to
/// text, from whole utterances or a stream fed in blocks.
///
/// Google's native runtime serves it on 64-bit Android, iOS, macOS, Linux
/// and Windows, loading the model and transcribing on a worker isolate, and
/// its browser runtime on a web worker.
///
/// ```dart
/// final task = await AudioTranscriber.create(
///   AudioTranscriberOptions(model: AudioModels.parakeetTdtV3),
/// );
/// final result = await task.transcribe(audio);
/// print(result.text);
/// await task.dispose();
/// ```
///
/// For a stream, pass each block with `endOfStream: false` and call
/// [finishStream] at the end. Calls run one at a time, in call order.
/// `dispose()` waits for work already accepted and is idempotent.
final class AudioTranscriber {
  AudioTranscriber._(this._runner, this._options);

  final AudioTranscriberRunner _runner;
  final AudioTranscriberOptions _options;
  Future<void>? _disposing;

  /// The processor the task runs on, fixed at creation.
  Delegate get delegate => _options.delegate;

  /// Resolves the model and opens Google's task; the model loads before
  /// this completes.
  static Future<AudioTranscriber> create(
    AudioTranscriberOptions options,
  ) async {
    requireDelegate(
      await queryAudioTranscriberCapabilities(),
      options.delegate,
    );
    await resolveTaskModel(options);
    try {
      return AudioTranscriber._(
        await openNativeAudioTranscriber(options),
        options,
      );
    } catch (error) {
      throw taskException(error);
    }
  }

  /// Transcribes [audio], whose rate must be the options' `sampleRateHz`;
  /// several channels are averaged first. With [endOfStream] false, Google
  /// keeps the audio short of a segment for the next call.
  Future<AudioTranscriberResult> transcribe(
    AudioData audio, {
    bool endOfStream = true,
  }) async {
    _check();
    if (audio.sampleRate != _options.sampleRateHz) {
      throw ArgumentError.value(
        audio.sampleRate,
        'audio.sampleRate',
        'The task was created for ${_options.sampleRateHz} Hz',
      );
    }
    return _runner.transcribe(
      monoSamples(audio.samples, audio.channels),
      endOfStream,
    );
  }

  /// Transcribes the audio a stream still holds and ends the stream.
  Future<AudioTranscriberResult> finishStream() async {
    _check();
    return _runner.finishStream();
  }

  /// Runs Google's warm-up pass, so the first [transcribe] is not slower
  /// than the rest.
  Future<void> prewarm() async {
    _check();
    return _runner.prewarm();
  }

  /// Finishes accepted work and releases Google's task. Repeated calls
  /// return the same completion; any other call afterwards fails with
  /// [StateError].
  Future<void> dispose() => _disposing ??= _runner.dispose();

  void _check() {
    if (_disposing != null) {
      throw StateError('AudioTranscriber has been disposed.');
    }
  }
}
