import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:mediapipe_core/native_structs.dart'
    show copyClassifications, fillBaseOptions, fillClassifierOptions;

import '../types/options.dart';
import '../types/results.dart';
import 'classic_text_runtime.dart';
import 'third_party/mediapipe/classic_text_bindings.dart' as mp;

/// Google's Text Classifier, created, used and closed on one worker isolate.
final class NativeTextClassifier
    extends NativeClassicTextTask<String, TextClassifierResult> {
  /// Loads the official task and acquires its handle.
  NativeTextClassifier(TextClassifierOptions options) {
    requireTextTasksRuntime();
    using((arena) {
      final native = arena<mp.MpTextClassifierOptions>();
      fillBaseOptions(
        native.ref.baseOptions,
        arena,
        modelPath: options.modelPath,
        modelBytes: options.modelBytes,
      );
      fillClassifierOptions(native.ref.classifierOptions, arena, options);
      final output = arena<Pointer<Void>>();
      checkTextStatus((error) => mp.classifierCreate(native, output, error));
      handle = output.value;
      if (handle == nullptr) {
        throw StateError('MediaPipe returned no TextClassifier.');
      }
    });
  }

  /// Runs Google's preprocessing, inference and postprocessing.
  TextClassifierResult classify(String text) {
    checkInput(text);
    return using((arena) {
      final output = arena<mp.MpClassificationResult>();
      checkTextStatus(
        (error) => mp.classifierRun(
          handle,
          text.toNativeUtf8(allocator: arena).cast(),
          output,
          error,
        ),
      );
      try {
        return textClassifierResultFromNative(output);
      } finally {
        // Google frees nested fields; the arena owns the outer result struct.
        mp.classifierCloseResult(output);
      }
    });
  }

  @override
  TextClassifierResult run(String input) => classify(input);

  @override
  void close() {
    if (handle == nullptr) return;
    final task = handle;
    handle = nullptr;
    checkTextStatus((error) => mp.classifierClose(task, error));
  }
}

/// Copies a borrowed result; the caller keeps Google's ownership.
TextClassifierResult textClassifierResultFromNative(
  Pointer<mp.MpClassificationResult> pointer,
) {
  final result = pointer.ref;
  return TextClassifierResult(
    timestampMilliseconds: result.hasTimestampMs ? result.timestampMs : null,
    classifications: copyClassifications(result),
  );
}
