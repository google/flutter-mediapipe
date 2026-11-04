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

/// Native Summarizer owner, constructed and used on one worker isolate.
final class NativeTextSummarizer
    extends WorkerTask<String, TextSummarizerResult, TextSummarizerUpdate> {
  /// Create the official CPU pipeline without altering prompts or model bytes.
  NativeTextSummarizer(TextSummarizerOptions options) {
    if (options.delegate != Delegate.cpu) {
      throw UnsupportedError('TextSummarizer supports the CPU delegate only.');
    }
    using((arena) {
      final native = arena<mp.MpTextSummarizerOptions>();
      fillBaseOptions(
        native.ref.base_options,
        arena,
        modelPath: options.modelPath,
      );
      native.ref
        ..mode = switch (options.mode) {
          TextSummarizerMode.tldr =>
            mp.MpTextSummarizerMode.MP_TEXT_SUMMARIZER_MODE_TLDR,
          TextSummarizerMode.keypoints =>
            mp.MpTextSummarizerMode.MP_TEXT_SUMMARIZER_MODE_KEYPOINTS,
        }
        ..max_num_tokens = options.maxNumTokens ?? 0
        // Google's default: errors only.
        ..min_log_severity = 4;
      if (options.cacheDirectory case final directory?) {
        native.ref.cache_dir = directory.toNativeUtf8(allocator: arena).cast();
      }
      final handle = arena<mp.MpTextSummarizerPtr>();
      _checked((error) => mp.MpTextSummarizerCreate(native, handle, error));
      _handle = handle.value;
      if (_handle == nullptr) {
        throw StateError('MediaPipe returned no Summarizer.');
      }
    });
  }

  mp.MpTextSummarizerPtr _handle = nullptr;

  @override
  TextSummarizerResult run(String input) => using((arena) {
    final result = arena<mp.MpTextSummarizerResult>();
    _checked(
      (error) => mp.MpTextSummarizerSummarize(
        _handle,
        input.toNativeUtf8(allocator: arena).cast(),
        result,
        error,
      ),
    );
    try {
      return TextSummarizerResult(summary: nativeString(result.ref.summary));
    } finally {
      // Google frees the payload. The arena frees the caller-owned struct.
      mp.MpTextSummarizerCloseResult(result);
    }
  });

  @override
  Future<void> stream(
    String input,
    void Function(TextSummarizerUpdate) emit,
  ) => receiveNativeTextStream(
    submit: (context) => using((arena) {
      _checked(
        (error) => mp.MpTextSummarizerSummarizeStreaming(
          _handle,
          input.toNativeUtf8(allocator: arena).cast(),
          Native.addressOf<NativeFunction<mp.MpTextSummarizerCallbackFunction>>(
            bridge.summarizerCallback,
          ),
          context,
          error,
        ),
      );
    }),
    decode: (result, terminal) =>
        TextSummarizerUpdate(chunk: nativeString(result.text), done: terminal),
    emit: emit,
    exception: TaskException.new,
  );

  @override
  void close() {
    if (_handle == nullptr) return;
    final handle = _handle;
    _handle = nullptr;
    _checked((error) => mp.MpTextSummarizerClose(handle, error));
  }
}

void _checked(mp.MpStatus Function(Pointer<Pointer<Char>>) call) =>
    checkNativeStatus((error) => call(error).value, mp.MpErrorFree);
