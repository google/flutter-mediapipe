@TestOn('browser')
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mediapipe_text/mediapipe_text.dart';
import 'package:mediapipe_text/src/results/decoders.dart';

/// The browser worker's replies, as JSON text, through the shared decoder.
Map<String, dynamic> _json(String text) =>
    jsonDecode(text) as Map<String, dynamic>;

void main() {
  test('classification heads, absent labels and the request stamp', () {
    final result = decodeTextClassifierResult(
      _json('''{"timestampMs": 1000, "classifications": [{"headIndex": 0,
        "headName": "probability", "categories": [{"index": 1, "score": 0.99,
        "categoryName": "positive", "displayName": ""}]}]}'''),
    );
    final category = result.classifications.single.categories.single;
    expect(result.timestampMilliseconds, 1000);
    expect(result.classifications.single.headName, 'probability');
    expect(category.categoryName, 'positive');
    expect(category.displayName, isNull);
    expect(() => result.classifications.clear(), throwsUnsupportedError);
  });

  test('float and quantized embeddings', () {
    final result = decodeTextEmbedderResult(
      _json('''{"embeddings": [{"headIndex": 0, "headName": "",
        "floatEmbedding": [0.5, -0.25]}, {"headIndex": 1,
        "headName": "quantized", "quantizedEmbedding": [1, 255]}]}'''),
    );
    final [floats, bytes] = result.embeddings;
    expect(result.timestampMilliseconds, isNull);
    expect(floats.floatEmbedding, [0.5, -0.25]);
    expect(floats.headName, isNull);
    expect(bytes.quantizedEmbedding, [1, 255]);
    expect(TextEmbedder.cosineSimilarity(bytes, bytes), closeTo(1, 1e-12));
  });

  test('language predictions keep their order', () {
    final result = decodeLanguageDetectorResult(
      _json('''{"languages": [{"languageCode": "es", "probability": 0.9},
        {"languageCode": "en", "probability": 0.1}]}'''),
    );
    expect(result.predictions, const [
      LanguagePrediction(languageCode: 'es', probability: 0.9),
      LanguagePrediction(languageCode: 'en', probability: 0.1),
    ]);
  });

  test('generative tasks report their platforms before loading', () async {
    final support = await queryTextSummarizerCapabilities();
    expect(support.isSupported, isFalse);
    await expectLater(
      TextSummarizer.create(TextSummarizerOptions(modelPath: 'model')),
      throwsA(isA<RuntimeUnavailableException>()),
    );
  });
}
