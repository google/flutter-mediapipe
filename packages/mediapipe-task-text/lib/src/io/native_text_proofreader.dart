import 'dart:ffi';
import 'package:ffi/ffi.dart';

import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_core/task_worker.dart';
import 'package:mediapipe_core/native_structs.dart'
    show checkNativeStatus, fillBaseOptions, nativeString;

import '../types/options.dart';
import '../types/results.dart';
import 'native_text_stream.dart';
import 'third_party/mediapipe/generative_text_bindings.dart' as mp;
import 'third_party/mediapipe/text_stream_bindings.dart' as bridge;

/// Native task owner, used serially by one persistent worker isolate.
final class NativeTextProofreader
    extends WorkerTask<String, TextProofreaderResult, TextProofreaderUpdate> {
  /// Load the official CPU task.
  NativeTextProofreader(TextProofreaderOptions options) {
    if (options.delegate != Delegate.cpu) {
      throw UnsupportedError('TextProofreader supports the CPU delegate only.');
    }
    using((arena) {
      final native = arena<mp.MpTextProofreaderOptions>();
      fillBaseOptions(
        native.ref.base_options,
        arena,
        modelPath: options.modelPath,
      );
      native.ref
        ..max_num_tokens = options.maxNumTokens ?? 0
        // Google's default: errors only.
        ..min_log_severity = 4;
      if (options.cacheDirectory case final directory?) {
        native.ref.cache_dir = directory.toNativeUtf8(allocator: arena).cast();
      }
      final handle = arena<mp.MpTextProofreaderPtr>();
      _checked((error) => mp.MpTextProofreaderCreate(native, handle, error));
      _handle = handle.value;
      if (_handle == nullptr) {
        throw StateError('MediaPipe returned no Proofreader.');
      }
    });
  }

  mp.MpTextProofreaderPtr _handle = nullptr;

  /// Copy a completed result and close its native allocation before returning.
  @override
  TextProofreaderResult run(String input) => using((arena) {
    final output = arena<Pointer<mp.MpTextProofreaderResult>>();
    _checked(
      (error) => mp.MpTextProofreaderProofread(
        _handle,
        input.toNativeUtf8(allocator: arena).cast(),
        output,
        error,
      ),
    );
    if (output.value == nullptr) {
      throw StateError('MediaPipe returned no result.');
    }
    try {
      final result = output.value.ref;
      return TextProofreaderResult(
        proofreadText: nativeString(result.proofread_text),
        corrections: _corrections(result.corrections, result.corrections_count),
      );
    } finally {
      mp.MpTextProofreaderCloseResult(output.value);
    }
  });

  /// Await the terminal native update before releasing the callback/context.
  @override
  Future<void> stream(
    String input,
    void Function(TextProofreaderUpdate) emit,
  ) => receiveNativeTextStream(
    submit: (context) => using((arena) {
      _checked(
        (error) => mp.MpTextProofreaderProofreadStreaming(
          _handle,
          input.toNativeUtf8(allocator: arena).cast(),
          Native.addressOf<
            NativeFunction<mp.MpTextProofreaderCallbackFunction>
          >(bridge.proofreaderCallback),
          context,
          error,
        ),
      );
    }),
    decode: (result, terminal) => TextProofreaderUpdate(
      chunk: nativeString(result.text),
      done: terminal,
      corrections: _corrections(result.corrections, result.correctionsCount),
    ),
    emit: emit,
    exception: TaskException.new,
  );

  /// Close after all native requests have completed.
  @override
  void close() {
    if (_handle == nullptr) return;
    final handle = _handle;
    _handle = nullptr;
    _checked((error) => mp.MpTextProofreaderClose(handle, error));
  }
}

List<ProofreadingCorrection> _corrections(
  Pointer<mp.MpCorrection> values,
  int count,
) {
  if (count < 0 || (count > 0 && values == nullptr)) {
    throw StateError('Invalid native correction array.');
  }
  return [
    for (var i = 0; i < count; i++)
      ProofreadingCorrection(
        type: switch (values[i].type) {
          mp.MpCorrectionType.MP_CORRECTION_TYPE_SAME =>
            ProofreadingCorrectionType.same,
          mp.MpCorrectionType.MP_CORRECTION_TYPE_INSERTION =>
            ProofreadingCorrectionType.insertion,
          mp.MpCorrectionType.MP_CORRECTION_TYPE_DELETION =>
            ProofreadingCorrectionType.deletion,
        },
        text: nativeString(values[i].text) ?? '',
      ),
  ];
}

void _checked(mp.MpStatus Function(Pointer<Pointer<Char>>) call) =>
    checkNativeStatus((error) => call(error).value, mp.MpErrorFree);
