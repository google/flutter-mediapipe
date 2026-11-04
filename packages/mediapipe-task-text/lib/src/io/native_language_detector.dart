import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:mediapipe_core/native_structs.dart'
    show fillBaseOptions, fillClassifierOptions, nativeString;

import '../types/options.dart';
import '../types/results.dart';
import 'classic_text_runtime.dart';
import 'third_party/mediapipe/classic_text_bindings.dart' as mp;

/// Google's Language Detector, created, used and closed on one worker
/// isolate.
final class NativeLanguageDetector
    extends NativeClassicTextTask<String, LanguageDetectorResult> {
  /// Loads the official task and acquires its handle.
  NativeLanguageDetector(LanguageDetectorOptions options) {
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
      checkTextStatus((error) => mp.languageCreate(native, output, error));
      handle = output.value;
      if (handle == nullptr) {
        throw StateError('MediaPipe returned no LanguageDetector.');
      }
    });
  }

  /// Runs Google's preprocessing, inference and postprocessing.
  LanguageDetectorResult detect(String text) {
    checkInput(text);
    return using((arena) {
      final output = arena<mp.MpLanguageDetectorResult>();
      checkTextStatus(
        (error) => mp.languageRun(
          handle,
          text.toNativeUtf8(allocator: arena).cast(),
          output,
          error,
        ),
      );
      try {
        return languageDetectorResultFromNative(output);
      } finally {
        // Google frees nested fields; the arena owns the outer result struct.
        mp.languageCloseResult(output);
      }
    });
  }

  @override
  LanguageDetectorResult run(String input) => detect(input);

  @override
  void close() {
    if (handle == nullptr) return;
    final task = handle;
    handle = nullptr;
    checkTextStatus((error) => mp.languageClose(task, error));
  }
}

/// Copies a borrowed result; the caller keeps Google's ownership.
LanguageDetectorResult languageDetectorResultFromNative(
  Pointer<mp.MpLanguageDetectorResult> pointer,
) => LanguageDetectorResult(
  predictions: [
    for (var i = 0; i < pointer.ref.predictionsCount; i++)
      LanguagePrediction(
        languageCode: nativeString(pointer.ref.predictions[i].languageCode)!,
        probability: pointer.ref.predictions[i].probability,
      ),
  ],
);
