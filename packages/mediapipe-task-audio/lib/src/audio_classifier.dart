import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_core/platform_interface.dart';

import 'audio_task_backend.dart';
import 'capabilities.dart';
import 'native_tasks.dart';
import 'runner.dart';
import 'stream/checks.dart';
import 'stream/model_bytes_web.dart'
    if (dart.library.io) 'stream/model_bytes_io.dart';
import 'stream/model_specs.dart';
import 'stream/results.dart';
import 'types.dart';

/// Google's Audio Classifier (for example YAMNet): the categories of each
/// window of audio the model reads (0.975 s for YAMNet), from clips or from a
/// continuous stream.
///
/// One class on every platform. Google's native runtime serves it on macOS,
/// Linux, Windows and iOS, classifying on a background isolate; its Android
/// SDK and browser runtime serve it through the registered platform plugin.
///
/// In [AudioRunningMode.audioClips] mode each clip is classified whole:
///
/// ```dart
/// final task = await AudioClassifier.create(
///   AudioClassifierOptions(model: AudioModels.yamnet),
/// );
/// final results = await task.classify(audio);
/// await task.dispose();
/// ```
///
/// In [AudioRunningMode.audioStream] mode blocks of any length go in with
/// [classifyAsync] and each window comes out on [results], stamped with
/// where its audio starts; [dispose] classifies the tail:
///
/// ```dart
/// final task = await AudioClassifier.create(
///   AudioClassifierOptions(
///     model: AudioModels.yamnet,
///     runningMode: AudioRunningMode.audioStream,
///   ),
/// );
/// task.results.listen(show);
/// task.classifyAsync(block, timestampMilliseconds: 0);
/// // More blocks, each stamped later than the one before...
/// await task.dispose();
/// ```
///
/// Clips run one at a time, in call order, and so do blocks. A `Future`
/// cannot cancel native work; `dispose()` waits for work already accepted
/// and is idempotent.
final class AudioClassifier {
  AudioClassifier._(
    this._checks,
    this.delegate, {
    this._clips,
    this._stream,
    this._results,
  });

  final AudioStreamChecks _checks;
  final AudioClassifierRunner? _clips;
  final AudioStreamRunner? _stream;
  final AudioStreamResults? _results;
  Future<void>? _disposing;

  /// The processor the task runs on, fixed at creation.
  final Delegate delegate;

  /// The mode the task was created in.
  AudioRunningMode get runningMode => _checks.runningMode;

  /// Resolves the model and opens Google's task.
  static Future<AudioClassifier> create(AudioClassifierOptions options) async {
    requireDelegate(await queryAudioClassifierCapabilities(), options.delegate);
    await resolveTaskModel(options);
    if (options.runningMode == AudioRunningMode.audioStream) {
      return _openStream(options);
    }
    final runner = switch (audioTaskBackendFactory) {
      final factory? => await BackendAudioClassifier.open(factory, options),
      null => await openNativeAudioClassifier(options),
    };
    return AudioClassifier._(
      AudioStreamChecks(AudioRunningMode.audioClips),
      options.delegate,
      clips: runner,
    );
  }

  /// Opens Google's stream where it has one and the emulation in browsers,
  /// then reads the model's audio input, which the checks and the clock
  /// need. Google opens its task first, so a model it refuses fails with its
  /// own message, as in clips mode.
  static Future<AudioClassifier> _openStream(
    AudioClassifierOptions options,
  ) async {
    final checks = AudioStreamChecks(AudioRunningMode.audioStream);
    final results = AudioStreamResults(checks);
    var model = options.modelBytes;
    AudioStreamRunner? stream;
    AudioClassifierRunner? clips;
    if (audioTaskBackendFactory case final factory?) {
      // The browser's clips task gets the bytes in place of the URL, so the
      // model is downloaded once.
      model ??= await readModelBytes(options.modelPath!);
      clips = await BackendAudioClassifier.open(
        factory,
        options,
        modelBytes: model,
      );
    } else {
      stream = await openNativeAudioStream(options, results);
    }
    try {
      checks.specs = AudioModelSpecs.read(
        model ?? await readModelBytes(options.modelPath!),
      );
    } catch (error) {
      await (stream?.close() ?? clips!.dispose());
      throw TaskException(
        "Cannot read the model's audio input: "
        '${error is FormatException ? error.message : error}.',
        cause: error,
      );
    }
    return AudioClassifier._(
      checks,
      options.delegate,
      stream: stream ?? EmulatedStreamRunner(clips!, results),
      results: results,
    );
  }

  /// Classifies [audio] in [AudioRunningMode.audioClips] mode: one result per
  /// window the model reads, in order, stamped with where it starts in the
  /// clip. Google's native tasks mix several channels down for a mono model;
  /// in browsers, whose task reads one channel, and on Android, whose plugin
  /// passes one, several channels are averaged first.
  Future<List<AudioClassifierResult>> classify(AudioData audio) async {
    _checks.clip();
    return _clips!.classify(audio);
  }

  /// Hands [block], the next part of the stream, to Google's audio stream
  /// mode and returns at once; its windows arrive on [results].
  ///
  /// Throws, before anything reaches Google's runtime, when the task is in
  /// clips mode or disposed, when no one listens to [results], when the
  /// block's rate differs from the first block's, when its channels differ
  /// from the model's (a mono model accepts any count), or when
  /// [timestampMilliseconds] is negative, not above the previous block's, or
  /// above 9007199254740. A block refused for its rate or channels does not
  /// use up its timestamp. An empty block is accepted and changes nothing.
  /// The block belongs to the task once accepted.
  void classifyAsync(AudioData block, {required int timestampMilliseconds}) {
    _checks.block(
      block,
      timestampMilliseconds,
      listening: _results?.listening ?? false,
    );
    if (block.samples.isEmpty) return;
    _results!.blockSent(timestampMilliseconds);
    _stream!.send(block, timestampMilliseconds);
  }

  /// The stream's results, one per window, in order: each window's
  /// timestamp is where its audio starts, the first block's timestamp plus
  /// the windows before it, whatever later blocks were stamped. Nothing is
  /// dropped.
  ///
  /// One subscription, made before the first block. Pausing buffers;
  /// cancelling discards later results. A failure arrives as a
  /// [TaskException], closes the stream, and every later [classifyAsync]
  /// throws it. [dispose] delivers the tail, then closes the stream.
  /// Throws [StateError] in clips mode.
  Stream<AudioClassifierResult> get results {
    _checks.requireMode(AudioRunningMode.audioStream);
    return _results!.stream;
  }

  /// Finishes accepted work and releases Google's task. In stream mode the
  /// tail, the audio short of a window, is classified as Google's close does
  /// and delivered before [results] closes. Repeated calls return the same
  /// completion; any other call afterwards fails with [StateError].
  Future<void> dispose() => _disposing ??= _dispose();

  Future<void> _dispose() async {
    _checks.markDisposing();
    if (_clips case final clips?) return clips.dispose();
    final results = _results!;
    try {
      await _stream!.close();
    } catch (error, stack) {
      results.fail(error, stack);
    } finally {
      results.close();
    }
  }
}
