import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_core/native_structs.dart'
    show fillBaseOptions, nativeString;

import '../runner/text_task_runner.dart';
import '../types/format_context.dart';
import '../types/options.dart';
import '../types/results.dart';
import 'classic_text_runtime.dart';
import 'third_party/mediapipe/embedding_gemma_bindings.dart' as mp;

/// Google's Text Embedder, for the classic models and EmbeddingGemma alike,
/// created, used and closed on one worker isolate.
final class NativeTextEmbedder
    extends NativeClassicTextTask<TextEmbedderInput, TextEmbedderResult> {
  /// Loads the official task and acquires its handle.
  NativeTextEmbedder(TextEmbedderOptions options) {
    requireTextTasksRuntime();
    using((arena) {
      final native = arena<mp.MpTextEmbedderOptions>();
      fillBaseOptions(
        native.ref.baseOptions,
        arena,
        modelPath: options.modelPath,
        modelBytes: options.modelBytes,
      );
      native.ref.embedderOptions
        ..l2Normalize = options.l2Normalize
        ..quantize = options.quantize;
      final output = arena<Pointer<Void>>();
      checkTextStatus((error) => mp.create(native, output, error));
      handle = output.value;
      if (handle == nullptr) {
        throw StateError('MediaPipe returned no TextEmbedder.');
      }
    });
  }

  TaskException? _failure;

  /// Runs Google's tokenizer, formatting, model and output transformations.
  ///
  /// A graph failure, such as EmbeddingGemma's token limit, persists inside
  /// Google's task, so it is kept and reported for every later request
  /// rather than submitting more work to a failed graph.
  TextEmbedderResult embed(String text, [TextFormatContext? context]) {
    checkInput(text);
    if (_failure case final error?) throw error;
    return using((arena) {
      var format = nullptr.cast<mp.MpTextFormatContext>();
      if (context != null) {
        format = arena<mp.MpTextFormatContext>();
        format.ref
          ..taskType = context.taskType.nativeValue
          ..role = context.role.nativeValue;
        if (context.title case final title?) {
          format.ref.title = title.toNativeUtf8(allocator: arena).cast();
        }
      }
      final output = arena<mp.MpEmbeddingResult>();
      try {
        checkTextStatus(
          (error) => mp.embed(
            handle,
            text.toNativeUtf8(allocator: arena).cast(),
            format,
            output,
            error,
          ),
        );
      } on TaskException catch (error) {
        _failure = error;
        rethrow;
      }
      try {
        return textEmbedderResultFromNative(output);
      } finally {
        mp.closeResult(output);
      }
    });
  }

  @override
  TextEmbedderResult run(TextEmbedderInput input) => embed(input.$1, input.$2);

  @override
  void close() {
    if (handle == nullptr) return;
    final task = handle;
    handle = nullptr;
    checkTextStatus((error) => mp.close(task, error));
  }
}

/// Copies a borrowed result; the caller keeps Google's ownership.
TextEmbedderResult textEmbedderResultFromNative(
  Pointer<mp.MpEmbeddingResult> pointer,
) => TextEmbedderResult(
  timestampMilliseconds: pointer.ref.hasTimestampMs
      ? pointer.ref.timestampMs
      : null,
  embeddings: [
    for (var i = 0; i < pointer.ref.embeddingsCount; i++)
      _copyEmbedding(pointer.ref.embeddings[i]),
  ],
);

Embedding _copyEmbedding(mp.MpEmbedding value) {
  if ((value.floatEmbedding == nullptr) ==
      (value.quantizedEmbedding == nullptr)) {
    throw StateError('MediaPipe returned an invalid embedding.');
  }
  return Embedding(
    floatEmbedding: value.floatEmbedding == nullptr
        ? null
        : value.floatEmbedding.asTypedList(value.valuesCount),
    quantizedEmbedding: value.quantizedEmbedding == nullptr
        ? null
        : value.quantizedEmbedding.asTypedList(value.valuesCount),
    headIndex: value.headIndex,
    headName: nativeString(value.headName),
  );
}
