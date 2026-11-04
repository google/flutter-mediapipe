/// Google's native Audio Classifier: a clips task is created on the calling
/// isolate and each clip is classified on a background isolate; a stream
/// task lives on a worker isolate of its own (native_audio_stream.dart).
library;

import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_core/native_structs.dart'
    show
        checkNativeStatus,
        copyClassifications,
        fillBaseOptions,
        fillClassifierOptions;
import 'package:mediapipe_core/platform_interface.dart';

import '../runner.dart';
import '../third_party/mediapipe/audio_classifier_bindings.dart' as mp;
import '../types.dart';

export 'native_audio_stream.dart' show openNativeAudioStream;

/// Google's AUDIO_CLIPS and AUDIO_STREAM modes in its C API.
const audioClipsMode = 1, audioStreamMode = 2;

/// Creates Google's task in [runningMode] from [options] and returns its
/// handle. A stream passes the [resultCallback] Google calls with each result.
Pointer<Void> openNativeTask(
  AudioClassifierOptions options, {
  required int runningMode,
  Pointer<Void>? resultCallback,
}) => using((arena) {
  final native = arena<mp.MpAudioClassifierOptions>();
  fillBaseOptions(
    native.ref.baseOptions,
    arena,
    modelPath: options.modelPath,
    modelBytes: options.modelBytes,
  );
  fillClassifierOptions(native.ref.classifierOptions, arena, options);
  native.ref
    ..runningMode = runningMode
    ..resultCallback = resultCallback ?? nullptr;
  final output = arena<Pointer<Void>>();
  checkedNativeCall((error) => mp.create(native, output, error));
  return output.value;
});

/// Opens Google's native Audio Classifier.
Future<AudioClassifierRunner> openNativeAudioClassifier(
  AudioClassifierOptions options,
) async {
  requireNativeAudioRuntime();
  return _NativeAudioClassifier(
    openNativeTask(options, runningMode: audioClipsMode).address,
  );
}

final class _NativeAudioClassifier implements AudioClassifierRunner {
  _NativeAudioClassifier(this._task);

  final int _task;
  final _queue = SerialTaskQueue('AudioClassifier');

  @override
  Future<List<AudioClassifierResult>> classify(AudioData audio) {
    final task = _task;
    final samples = audio.samples;
    final rate = audio.sampleRate;
    final channels = audio.channels;
    return _queue.add(
      () => Isolate.run(() => _classify(task, samples, rate, channels)),
    );
  }

  @override
  Future<void> dispose() => _queue.close(
    () => checkedNativeCall(
      (error) => mp.close(Pointer.fromAddress(_task), error),
    ),
  );
}

/// Resolves core's runtime before the first call, to explain a missing one.
void requireNativeAudioRuntime() {
  try {
    Native.addressOf<
      NativeFunction<
        Int32 Function(
          Pointer<mp.MpAudioClassifierOptions>,
          Pointer<Pointer<Void>>,
          Pointer<Pointer<Char>>,
        )
      >
    >(mp.create);
  } on ArgumentError catch (error) {
    if (missingLinuxGraphicsLibraries('$error') case final missing?) {
      throw missing;
    }
    throw RuntimeUnavailableException(
      'Audio Classifier runtime unavailable.',
      fix: tasksRuntimeUnavailable(
        'the Audio Classifier',
        Platform.operatingSystem,
      ),
    );
  }
}

List<AudioClassifierResult> _classify(
  int task,
  Float32List samples,
  double sampleRate,
  int channels,
) => using((arena) {
  final audio = nativeAudioData(samples, sampleRate, channels, arena);
  final result = arena<mp.MpAudioClassifierResult>();
  checkedNativeCall(
    (error) => mp.classify(Pointer.fromAddress(task), audio, result, error),
  );
  try {
    return [
      for (var i = 0; i < result.ref.resultsCount; i++)
        _chunk(result.ref.results[i]),
    ];
  } finally {
    mp.closeResult(result);
  }
});

/// [samples] as Google's C API takes them, in memory from [arena].
Pointer<mp.MpAudioData> nativeAudioData(
  Float32List samples,
  double sampleRate,
  int channels,
  Arena arena,
) {
  final data = arena<Float>(samples.length);
  data.asTypedList(samples.length).setAll(0, samples);
  final audio = arena<mp.MpAudioData>();
  audio.ref
    ..numChannels = channels
    ..sampleRate = sampleRate
    ..audioData = data
    ..audioDataSize = samples.length;
  return audio;
}

AudioClassifierResult _chunk(mp.MpClassificationResult result) =>
    AudioClassifierResult(
      timestampMilliseconds: result.hasTimestampMs ? result.timestampMs : 0,
      classifications: copyClassifications(result),
    );

/// Runs one of Google's audio calls, as core's [checkNativeStatus] does with
/// this family's library.
void checkedNativeCall(int Function(Pointer<Pointer<Char>> error) call) =>
    checkNativeStatus(call, mp.errorFree);
