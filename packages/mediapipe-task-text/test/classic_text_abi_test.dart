import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:mediapipe_text/src/io/third_party/mediapipe/classic_text_bindings.dart'
    as mp;
import 'package:mediapipe_text/src/io/third_party/mediapipe/embedding_gemma_bindings.dart'
    as embedding;
import 'package:test/test.dart';

void main() {
  final abi =
      jsonDecode(
            File(
              'test/fixtures/classic_text/official_reference.json',
            ).readAsStringSync(),
          )['abi']
          as Map;
  test(
    'classification and language layouts match pinned Python ctypes sizes',
    () {
      for (final entry in {
        'MpClassifierOptionsC': sizeOf<mp.MpClassifierOptions>(),
        'MpTextClassifierOptionsC': sizeOf<mp.MpTextClassifierOptions>(),
        'MpLanguageDetectorOptionsC': sizeOf<mp.MpTextClassifierOptions>(),
        'MpCategoryC': sizeOf<mp.MpCategory>(),
        'MpClassificationsC': sizeOf<mp.MpClassifications>(),
        'MpClassificationResultC': sizeOf<mp.MpClassificationResult>(),
        'MpLanguageDetectorPredictionC': sizeOf<mp.MpLanguagePrediction>(),
        'MpLanguageDetectorResultC': sizeOf<mp.MpLanguageDetectorResult>(),
      }.entries) {
        expect(entry.value, abi[entry.key]['size'], reason: entry.key);
      }
    },
  );

  test(
    'classification timestamp and embedded options use official offsets',
    () {
      using((arena) {
        final result = arena<mp.MpClassificationResult>();
        final resultBytes = result.cast<Uint8>().asTypedList(
          sizeOf<mp.MpClassificationResult>(),
        );
        final resultData = ByteData.sublistView(resultBytes);
        final offsets = abi['MpClassificationResultC']['offsets'] as Map;
        resultData.setInt64(offsets['timestamp_ms'], 123456789, Endian.host);
        resultData.setUint8(offsets['has_timestamp_ms'], 1);
        resultData.setUint32(offsets['classifications_count'], 7, Endian.host);
        expect(result.ref.timestampMs, 123456789);
        expect(result.ref.hasTimestampMs, isTrue);
        expect(result.ref.classificationsCount, 7);
        final options = arena<mp.MpTextClassifierOptions>();
        final bytes = options.cast<Uint8>().asTypedList(
          sizeOf<mp.MpTextClassifierOptions>(),
        );
        final data = ByteData.sublistView(bytes);
        final start =
            abi['MpTextClassifierOptionsC']['offsets']['classifier_options']
                as int;
        final fields = abi['MpClassifierOptionsC']['offsets'] as Map;
        data.setInt32(start + (fields['max_results'] as int), -1, Endian.host);
        data.setFloat32(
          start + (fields['score_threshold'] as int),
          .75,
          Endian.host,
        );
        data.setUint32(
          start + (fields['category_allowlist_count'] as int),
          3,
          Endian.host,
        );
        data.setUint32(
          start + (fields['category_denylist_count'] as int),
          4,
          Endian.host,
        );
        expect(options.ref.classifierOptions.maxResults, -1);
        expect(options.ref.classifierOptions.scoreThreshold, .75);
        expect(options.ref.classifierOptions.categoryAllowlistCount, 3);
        expect(options.ref.classifierOptions.categoryDenylistCount, 4);
      });
    },
  );

  // The generator reads embedding results with the C header's layout
  // (tasks/c/components/containers/embedding_result.h); Google's Python
  // ctypes declare 24 bytes, which the library overruns.
  test('embedding result uses the C header layout', () {
    final layout = abi['MpEmbeddingResultC'] as Map;
    final offsets = layout['offsets'] as Map;
    expect(sizeOf<embedding.MpEmbeddingResult>(), layout['size']);
    using((arena) {
      final result = arena<embedding.MpEmbeddingResult>();
      final data = ByteData.sublistView(
        result.cast<Uint8>().asTypedList(layout['size'] as int),
      );
      data.setUint32(offsets['embeddings_count'], 7, Endian.host);
      data.setInt64(offsets['timestamp_ms'], 123456789, Endian.host);
      data.setUint8(offsets['has_timestamp_ms'], 1);
      expect(result.ref.embeddingsCount, 7);
      expect(result.ref.timestampMs, 123456789);
      expect(result.ref.hasTimestampMs, isTrue);
    });
  });
}
