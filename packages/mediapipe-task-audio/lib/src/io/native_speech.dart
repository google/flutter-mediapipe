/// Google's native Audio Transcriber and Text to Speech, each made, used and
/// closed on a worker isolate of its own, so loading the model and every
/// request stay off the calling isolate.
library;

import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_core/native_structs.dart'
    show checkNativeStatus, fillBaseOptions, nativeString;
import 'package:mediapipe_core/platform_interface.dart';
import 'package:mediapipe_core/task_worker.dart';

import '../litertlm_header.dart';
import '../speech_runners.dart';
import '../speech_types.dart';
import '../third_party/mediapipe/audio_transcriber_bindings.dart' as asr;
import '../third_party/mediapipe/text_to_speech_bindings.dart' as tts;
import '../third_party/mediapipe/text_to_speech_guard_bindings.dart' as guard;
import '../utf16_indices.dart';
import 'native_audio_classifier.dart' show checkedNativeCall;

/// Opens Google's Audio Transcriber on a worker.
Future<AudioTranscriberRunner> openNativeAudioTranscriber(
  AudioTranscriberOptions options,
) async {
  _requireSpeechRuntime('the Audio Transcriber');
  final worker = _TranscriberWorker();
  await worker.start(_transcriberSettings(options), _NativeTranscriber.new);
  return worker;
}

/// Opens Google's Text to Speech on a worker.
Future<TextToSpeechRunner> openNativeTextToSpeech(
  TextToSpeechOptions options,
) async {
  _requireSpeechRuntime('Text to Speech');
  if (Platform.isLinux) await _requireModelFile(_modelFile(options));
  if (options.delegate == Delegate.gpu) {
    await _requireGpuSection(_modelFile(options));
  }
  final cancels = guard.guardNew(
    Native.addressOf<NativeFunction<Void Function(Pointer<Void>)>>(
      tts.cancel,
    ).cast(),
    Native.addressOf<NativeFunction<Void Function(Pointer<Void>)>>(
      tts.streamCancel,
    ).cast(),
  );
  if (cancels == nullptr) throw const TaskException('Out of memory.');
  final worker = _TextToSpeechWorker(cancels);
  try {
    await worker.start(
      _textToSpeechSettings(options, cancels),
      _NativeTextToSpeech.new,
    );
  } catch (_) {
    // The worker has exited, or never started.
    guard.guardFree(cancels);
    rethrow;
  }
  return worker;
}

/// Resolves core's runtime before the worker starts, to explain a missing
/// one.
void _requireSpeechRuntime(String task) {
  try {
    Native.addressOf<
      NativeFunction<
        Int32 Function(
          Pointer<asr.MpAudioTranscriberOptions>,
          Pointer<Pointer<Void>>,
          Pointer<Pointer<Char>>,
        )
      >
    >(asr.create);
  } on ArgumentError catch (error) {
    if (missingLinuxGraphicsLibraries('$error') case final missing?) {
      throw missing;
    }
    throw RuntimeUnavailableException(
      '${task[0].toUpperCase()}${task.substring(1)} runtime unavailable.',
      fix: tasksRuntimeUnavailable(task, Platform.operatingSystem),
    );
  }
}

/// Refuses a model path that is no file, on Linux, where Google's Text to
/// Speech ends the process for a missing Phonon or PocketTTS file and for a
/// directory with Phonon's file name (init_google.cc logs a fatal "InitGoogle()
/// has not finished yet" for `<path>/tokenizer.model`) instead of returning
/// an error as it does on macOS and Windows. The status is NOT_FOUND,
/// Google's for a missing model there; the speech tests' error reference,
/// regenerated on each runner, holds what Google does with each such path.
Future<void> _requireModelFile(String modelPath) async {
  if (await FileSystemEntity.isFile(modelPath)) return;
  throw TaskException(
    'No Text to Speech model file at $modelPath: it is missing or not a file.',
    statusCode: 5,
  );
}

/// Refuses the GPU for a model whose bundle puts no section there: Google's
/// task accepts the delegate for Phonon and runs it on the CPU, with no error
/// or log line that says so.
Future<void> _requireGpuSection(String modelPath) async {
  final file = await File(modelPath).open();
  bool? gpu;
  try {
    final preamble = await file.read(litertlmPreambleBytes);
    final end = litertlmHeaderEnd(preamble);
    // Kokoro's header takes 7 KB.
    if (end != null && end <= 1 << 20) {
      await file.setPosition(0);
      gpu = litertlmHasGpuSection(await file.read(end));
    }
  } finally {
    await file.close();
  }
  if (gpu ?? false) return;
  throw RuntimeUnavailableException(
    'The GPU delegate is unavailable for this model.',
    fix:
        "Google's Text to Speech runs a model on the GPU only where its "
        'bundle marks a section for it, as Kokoro '
        '(kokoro_int8_gpu_fp16.litertlm) does for its vocoder. This model '
        'marks none, so it runs on the CPU either way: choose Delegate.cpu.',
  );
}

/// Google's tasks read the model from a file: a pinned model resolves to
/// one on native platforms.
String _modelFile(TaskOptions options) =>
    options.modelPath ??
    (throw TaskException(
      "Google's speech tasks read their model from a file; this model "
      'resolved to bytes.',
    ));

// Settings cross to the worker as plain records.

typedef _TranscriberSettings = ({
  String modelPath,
  Delegate delegate,
  int sampleRateHz,
  bool enableInterimResults,
  int modelArchitecture,
  String? prompt,
  String? cacheDirectory,
});

_TranscriberSettings _transcriberSettings(AudioTranscriberOptions options) => (
  modelPath: _modelFile(options),
  delegate: options.delegate,
  sampleRateHz: options.sampleRateHz,
  enableInterimResults: options.enableInterimResults,
  modelArchitecture: options.modelArchitecture.index,
  prompt: options.prompt,
  cacheDirectory: options.cacheDirectory,
);

typedef _TextToSpeechSettings = ({
  String modelPath,
  Delegate delegate,
  String? defaultVoiceId,
  String? defaultLocale,
  double speakingRate,
  int targetBucket,
  String? cacheDirectory,
  int cancelGuard,
});

_TextToSpeechSettings _textToSpeechSettings(
  TextToSpeechOptions options,
  Pointer<Void> cancelGuard,
) => (
  modelPath: _modelFile(options),
  delegate: options.delegate,
  defaultVoiceId: options.defaultVoiceId,
  defaultLocale: options.defaultLocale,
  speakingRate: options.speakingRate,
  targetBucket: options.targetBucket,
  cacheDirectory: options.cacheDirectory,
  cancelGuard: cancelGuard.address,
);

/// [value] in [arena], or null when it is null or empty, as Google's Python
/// passes optional strings.
Pointer<Char> _optional(String? value, Arena arena) =>
    value == null || value.isEmpty
    ? nullptr
    : value.toNativeUtf8(allocator: arena).cast();

// The Audio Transcriber.

/// A transcriber request: samples to transcribe, or a flush, or a warm-up.
sealed class _TranscriberRequest {
  const _TranscriberRequest();
}

final class _Transcribe extends _TranscriberRequest {
  const _Transcribe(this.samples, this.endOfStream);
  final Float32List samples;
  final bool endOfStream;
}

final class _FinishStream extends _TranscriberRequest {
  const _FinishStream();
}

final class _Prewarm extends _TranscriberRequest {
  const _Prewarm();
}

final class _TranscriberWorker
    extends TaskWorker<_TranscriberRequest, AudioTranscriberResult?, Never>
    implements AudioTranscriberRunner {
  _TranscriberWorker() : super('AudioTranscriber');

  @override
  Future<AudioTranscriberResult> transcribe(
    Float32List samples,
    bool endOfStream,
  ) async => (await run(_Transcribe(samples, endOfStream)))!;

  @override
  Future<AudioTranscriberResult> finishStream() async =>
      (await run(const _FinishStream()))!;

  @override
  Future<void> prewarm() => run(const _Prewarm());
}

final class _NativeTranscriber
    extends WorkerTask<_TranscriberRequest, AudioTranscriberResult?, Never> {
  _NativeTranscriber(_TranscriberSettings settings) {
    using((arena) {
      final native = arena<asr.MpAudioTranscriberOptions>();
      fillBaseOptions(
        native.ref.baseOptions,
        arena,
        modelPath: settings.modelPath,
        delegate: settings.delegate,
      );
      native.ref
        ..sampleRateHz = settings.sampleRateHz
        ..enableInterimResults = settings.enableInterimResults
        ..modelArchitecture = settings.modelArchitecture
        ..prompt = _optional(settings.prompt, arena)
        ..cacheDir = _optional(settings.cacheDirectory, arena);
      final output = arena<Pointer<Void>>();
      checkedNativeCall((error) => asr.create(native, output, error));
      _handle = output.value;
    });
  }

  late Pointer<Void> _handle;

  @override
  AudioTranscriberResult? run(_TranscriberRequest input) => using(
    (arena) => switch (input) {
      _Transcribe(:final samples, :final endOfStream) => _result(arena, (
        result,
        error,
      ) {
        final data = arena<Float>(samples.isEmpty ? 1 : samples.length);
        data.asTypedList(samples.length).setAll(0, samples);
        return asr.transcribe(
          _handle,
          data,
          samples.length,
          endOfStream,
          result,
          error,
        );
      }),
      _FinishStream() => _result(
        arena,
        (result, error) => asr.finishStream(_handle, result, error),
      ),
      _Prewarm() => () {
        checkedNativeCall((error) => asr.prewarm(_handle, error));
        return null;
      }(),
    },
  );

  AudioTranscriberResult _result(
    Arena arena,
    int Function(
      Pointer<asr.MpAudioTranscriberResult> result,
      Pointer<Pointer<Char>> error,
    )
    call,
  ) {
    final result = arena<asr.MpAudioTranscriberResult>();
    checkedNativeCall((error) => call(result, error));
    try {
      return AudioTranscriberResult([
        for (var i = 0; i < result.ref.segmentsCount; i++)
          if (result.ref.segments[i] case final segment)
            TranscriptionSegment(
              transcript: nativeString(segment.transcript) ?? '',
              isFinal: segment.isFinal,
              fromTimestampMilliseconds: segment.fromTimestampMs,
              toTimestampMilliseconds: segment.toTimestampMs,
            ),
      ]);
    } finally {
      asr.closeResult(result);
    }
  }

  @override
  void close() => checkedNativeCall((error) => asr.close(_handle, error));
}

// Text to Speech.

/// A Text to Speech request: list the voices, or synthesize [text].
final class _TextToSpeechRequest {
  const _TextToSpeechRequest.voices()
    : text = null,
      voiceId = null,
      locale = null,
      number = 0,
      cancelFlag = 0;

  const _TextToSpeechRequest.synthesize(
    String this.text,
    this.voiceId,
    this.locale,
    this.number, {
    this.cancelFlag = 0,
  });

  final String? text;
  final String? voiceId;
  final String? locale;

  /// A synthesis's place in call order, from 1, which cancels name.
  final int number;

  /// A stream's cancel flag: the address of a byte the calling isolate sets
  /// to 1 to stop it.
  final int cancelFlag;
}

/// A synthesis cancelled before Google ran it, or after Google finished it
/// but before the worker returned it, which fails as Google's would.
TaskException _cancelled() =>
    const TaskException('Synthesis cancelled.', statusCode: tts.mpCancelled);

/// Cancels reach Google from the calling isolate through [_cancels], the
/// native guard (native/text_to_speech_guard.c) that the worker publishes
/// its handles to, and that this isolate frees only once the worker has
/// exited.
final class _TextToSpeechWorker
    extends TaskWorker<_TextToSpeechRequest, Object?, TextToSpeechResult>
    implements TextToSpeechRunner {
  _TextToSpeechWorker(this._cancels) : super('TextToSpeech');

  /// Null once freed.
  Pointer<Void>? _cancels;
  var _numbered = 0;
  Future<void>? _disposal;

  @override
  Future<List<TextToSpeechVoice>> listVoices() async =>
      (await run(const _TextToSpeechRequest.voices()))!
          as List<TextToSpeechVoice>;

  @override
  Future<TextToSpeechResult> synthesize(
    String text,
    String? voiceId,
    String? locale,
  ) async =>
      (await run(
            _TextToSpeechRequest.synthesize(text, voiceId, locale, ++_numbered),
          ))!
          as TextToSpeechResult;

  /// The worker checks a flag in native memory before each read, which a
  /// cancel sets before cancelling Google's stream through the guard, if it
  /// is open: so a read in progress returns, and one not begun never starts.
  /// A request is numbered when listened to, as it is sent then.
  @override
  Stream<TextToSpeechResult> synthesizeStream(
    String text,
    String? voiceId,
    String? locale,
  ) {
    Pointer<Uint8>? flag;
    var number = 0;
    StreamSubscription<TextToSpeechResult>? subscription;
    void free() {
      if (flag case final allocated?) calloc.free(allocated);
      flag = null;
    }

    late final StreamController<TextToSpeechResult> controller;
    controller = StreamController(
      onListen: () {
        final allocated = flag = calloc<Uint8>();
        number = ++_numbered;
        try {
          subscription =
              stream(
                _TextToSpeechRequest.synthesize(
                  text,
                  voiceId,
                  locale,
                  number,
                  cancelFlag: allocated.address,
                ),
              ).listen(
                controller.add,
                onError: controller.addError,
                onDone: () {
                  free();
                  unawaited(controller.close());
                },
              );
        } catch (error, stack) {
          free();
          controller.addError(error, stack);
          unawaited(controller.close());
        }
      },
      onPause: () => subscription?.pause(),
      onResume: () => subscription?.resume(),
      onCancel: () async {
        // Closing the controller after onDone also lands here, with the
        // flag already freed.
        final allocated = flag;
        if (allocated == null) return;
        allocated.value = 1;
        if (_cancels case final cancels?) {
          guard.guardCancelStream(cancels, number);
        }
        // Waits for the worker to finish the request.
        await subscription?.cancel();
        free();
      },
    );
    return controller.stream;
  }

  @override
  void cancel() {
    if (_cancels case final cancels?) guard.guardCancel(cancels, _numbered);
  }

  /// Frees the guard once the worker has exited, whether or not the close
  /// succeeded.
  @override
  Future<void> dispose() => _disposal ??= () async {
    try {
      await super.dispose();
    } finally {
      guard.guardFree(_cancels!);
      _cancels = null;
    }
  }();
}

final class _NativeTextToSpeech
    extends WorkerTask<_TextToSpeechRequest, Object?, TextToSpeechResult> {
  _NativeTextToSpeech(_TextToSpeechSettings settings)
    : _cancels = Pointer.fromAddress(settings.cancelGuard) {
    using((arena) {
      final native = arena<tts.MpTextToSpeechOptions>();
      fillBaseOptions(
        native.ref.baseOptions,
        arena,
        modelPath: settings.modelPath,
        delegate: settings.delegate,
      );
      native.ref
        ..defaultVoiceId = _optional(settings.defaultVoiceId, arena)
        ..defaultLocale = _optional(settings.defaultLocale, arena)
        ..speakingRate = settings.speakingRate
        ..targetBucket = settings.targetBucket
        ..cacheDirectory = _optional(settings.cacheDirectory, arena);
      final output = arena<Pointer<Void>>();
      _checked((error) => tts.create(native, output, error));
      _handle = output.value;
    });
  }

  late Pointer<Void> _handle;

  /// Holds the handles a synthesis uses while it runs, for the calling
  /// isolate's cancels.
  final Pointer<Void> _cancels;

  @override
  Object? run(_TextToSpeechRequest input) => using((arena) {
    final text = input.text;
    if (text == null) return _voices(arena);
    if (!guard.guardBegin(_cancels, input.number, _handle)) throw _cancelled();
    final TextToSpeechResult audio;
    try {
      final result = arena<tts.MpTextToSpeechAudioResult>();
      _checked(
        (error) => tts.synthesize(
          _handle,
          text.toNativeUtf8(allocator: arena).cast(),
          _synthesisOptions(input, arena),
          result,
          error,
        ),
      );
      audio = _audio(result, text);
    } finally {
      if (guard.guardEnd(_cancels)) throw _cancelled();
    }
    return audio;
  });

  /// A cancel, of this stream or of the task, ends it without an error:
  /// Google's read then reports kMpCancelled, which only a cancel causes.
  @override
  Future<void> stream(
    _TextToSpeechRequest input,
    void Function(TextToSpeechResult update) emit,
  ) async {
    final text = input.text!;
    final cancelled = Pointer<Uint8>.fromAddress(input.cancelFlag);
    if (cancelled.value != 0 ||
        !guard.guardBegin(_cancels, input.number, _handle)) {
      return;
    }
    try {
      final stream = using((arena) {
        final output = arena<Pointer<Void>>();
        _checked(
          (error) => tts.startStream(
            _handle,
            text.toNativeUtf8(allocator: arena).cast(),
            _synthesisOptions(input, arena),
            true,
            output,
            error,
          ),
        );
        return output.value;
      });
      guard.guardSetStream(_cancels, stream);
      try {
        // The flag is read after the stream is published: a cancel that
        // found no stream to cancel set it before then.
        while (cancelled.value == 0) {
          final chunk = using((arena) {
            final result = arena<tts.MpTextToSpeechAudioResult>();
            final index = arena<Int32>();
            final last = arena<Bool>();
            final error = arena<Pointer<Char>>();
            final status = tts.streamReadNext(
              stream,
              result,
              index,
              last,
              error,
            );
            if (status == tts.mpOutOfRange || status == tts.mpCancelled) {
              if (error.value != nullptr) tts.freeError(error.value);
              return null;
            }
            _checked((out) {
              out.value = error.value;
              return status;
            });
            return _audio(
              result,
              text,
              chunkIndex: index.value,
              isFinal: last.value,
            );
          });
          if (chunk == null) break;
          emit(chunk);
        }
      } finally {
        guard.guardSetStream(_cancels, nullptr);
        tts.streamClose(stream);
      }
    } finally {
      guard.guardEnd(_cancels);
    }
  }

  Pointer<tts.MpTextToSpeechSynthesisOptions> _synthesisOptions(
    _TextToSpeechRequest input,
    Arena arena,
  ) {
    final options = arena<tts.MpTextToSpeechSynthesisOptions>();
    options.ref
      ..voiceId = _optional(input.voiceId, arena)
      ..locale = _optional(input.locale, arena);
    return options;
  }

  List<TextToSpeechVoice> _voices(Arena arena) {
    final list = arena<tts.MpTextToSpeechVoiceList>();
    _checked((error) => tts.listVoices(_handle, list, error));
    try {
      return [
        for (var i = 0; i < list.ref.numVoices; i++)
          if (list.ref.voices[i] case final voice)
            TextToSpeechVoice(
              voiceId: nativeString(voice.voiceId) ?? '',
              displayName: nativeString(voice.displayName) ?? '',
              locale: nativeString(voice.locale) ?? '',
              sampleRateHz: voice.sampleRateHz,
              isDownloaded: voice.isDownloaded,
            ),
      ];
    } finally {
      tts.voiceListFree(list);
    }
  }

  /// Copies Google's [result] for [text], then frees it.
  TextToSpeechResult _audio(
    Pointer<tts.MpTextToSpeechAudioResult> result,
    String text, {
    int chunkIndex = 0,
    bool isFinal = true,
  }) {
    try {
      final count = result.ref.numSamples;
      final samples = result.ref.samples == nullptr || count == 0
          ? Float32List(0)
          : Float32List.fromList(result.ref.samples.asTypedList(count));
      final words = result.ref.wordTimestamps;
      final indices = words == nullptr ? null : utf16Indices(text);
      return TextToSpeechResult(
        samples: samples,
        sampleRateHz: result.ref.sampleRateHz,
        chunkIndex: chunkIndex,
        isFinal: isFinal,
        wordTimestamps: [
          if (indices != null)
            for (var i = 0; i < result.ref.numWordTimestamps; i++)
              if (words[i] case final word)
                WordTimestamp(
                  word: nativeString(word.word) ?? '',
                  start: indices[word.startChar.clamp(0, indices.length - 1)],
                  end: indices[word.endChar.clamp(0, indices.length - 1)],
                  startSeconds: word.startSec,
                  endSeconds: word.endSec,
                ),
        ],
      );
    } finally {
      tts.freeAudioResult(result);
    }
  }

  @override
  void close() => tts.close(_handle);
}

/// Runs one of Google's Text to Speech calls, whose messages it frees with
/// its own function.
void _checked(int Function(Pointer<Pointer<Char>> error) call) =>
    checkNativeStatus(call, tts.freeError);
