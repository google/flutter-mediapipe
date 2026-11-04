import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:mediapipe_text/src/io/native_language_detector.dart';
import 'package:mediapipe_text/src/io/third_party/mediapipe/classic_text_bindings.dart'
    as mp;
import 'package:test/test.dart';

void main() {
  test('copies an empty 1.0.1 language result', () {
    final result = using(
      (arena) => languageDetectorResultFromNative(
        arena<mp.MpLanguageDetectorResult>(),
      ),
    );
    expect(result.predictions, isEmpty);
  });
  test('owns prediction text and probability after native free', () {
    final result = using((arena) {
      final output = arena<mp.MpLanguageDetectorResult>();
      final predictions = arena<mp.MpLanguagePrediction>();
      final code = 'es'.toNativeUtf8(allocator: arena);
      predictions.ref
        ..languageCode = code.cast()
        ..probability = .75;
      output.ref
        ..predictions = predictions
        ..predictionsCount = 1;
      final result = languageDetectorResultFromNative(output);
      predictions.ref.probability = 0;
      code.cast<Uint8>().value = 0;
      return result;
    });
    expect(result.predictions.single.languageCode, 'es');
    expect(result.predictions.single.probability, .75);
    expect(() => result.predictions.clear(), throwsUnsupportedError);
  });
}
