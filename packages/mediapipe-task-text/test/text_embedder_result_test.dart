import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:mediapipe_text/src/io/native_text_embedder.dart';
import 'package:mediapipe_text/src/io/third_party/mediapipe/embedding_gemma_bindings.dart'
    as mp;
import 'package:test/test.dart';

void main() {
  test('copies an empty 1.0.1 embedding result', () {
    final result = using(
      (arena) => textEmbedderResultFromNative(arena<mp.MpEmbeddingResult>()),
    );
    expect(result.embeddings, isEmpty);
    expect(result.timestampMilliseconds, isNull);
  });
  test('owns immutable float and signed-byte storage after native free', () {
    final result = using((arena) {
      final output = arena<mp.MpEmbeddingResult>();
      final heads = arena<mp.MpEmbedding>(2);
      final floats = arena<Float>(2)..asTypedList(2).setAll(0, [.25, -.5]);
      final bytes = arena<Uint8>(2)..asTypedList(2).setAll(0, [127, 128]);
      heads[0]
        ..floatEmbedding = floats
        ..valuesCount = 2
        ..headIndex = 0;
      heads[1]
        ..quantizedEmbedding = bytes
        ..valuesCount = 2
        ..headIndex = 1;
      output.ref
        ..embeddings = heads
        ..embeddingsCount = 2;
      final result = textEmbedderResultFromNative(output);
      floats.asTypedList(2).fillRange(0, 2, 99);
      bytes.asTypedList(2).fillRange(0, 2, 0);
      return result;
    });
    expect(result.embeddings[0].floatEmbedding, [.25, -.5]);
    expect(result.embeddings[1].quantizedEmbedding, [127, 128]);
    expect(result.embeddings[0].headName, isNull);
    expect(result.embeddings[1].headIndex, 1);
    expect(() => result.embeddings.clear(), throwsUnsupportedError);
    expect(
      () => result.embeddings[0].floatEmbedding![0] = 0,
      throwsUnsupportedError,
    );
    expect(
      () => result.embeddings[1].quantizedEmbedding![0] = 0,
      throwsUnsupportedError,
    );
  });
}
