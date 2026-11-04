@Tags(['native-assets'])
library;

import 'dart:typed_data';

import 'package:mediapipe_text/mediapipe_text.dart';
import 'package:test/test.dart';

void main() {
  test(
    'public classifier returns the reference scores through its isolate',
    () async {
      final classifier = await TextClassifier.create(
        TextClassifierOptions(modelPath: 'models/bert_classifier.tflite'),
      );
      addTearDown(classifier.dispose);
      final result = await classifier.classify('Hello, world!');
      final positive = result.classifications.first.categories.first;
      expect(classifier.delegate, Delegate.cpu);
      expect(positive.categoryName, 'positive');
      expect(positive.score, closeTo(0.9919, 0.0009));
    },
  );

  test(
    'public detector handles consecutive languages through its isolate',
    () async {
      final detector = await LanguageDetector.create(
        LanguageDetectorOptions(modelPath: 'models/language_detector.tflite'),
      );
      addTearDown(detector.dispose);
      final english = await detector.detect('Hello, world!');
      final spanish = await detector.detect('Quiero agua, por favor.');
      expect(english.predictions.first.languageCode, 'en');
      expect(spanish.predictions.first.languageCode, 'es');
      expect(spanish.predictions.first.probability, greaterThan(0.99));
    },
  );

  test('public embedder embeds and compares owned vectors', () async {
    final embedder = await TextEmbedder.create(
      TextEmbedderOptions(
        modelPath: 'models/universal_sentence_encoder.tflite',
      ),
    );
    addTearDown(embedder.dispose);
    final first = await embedder.embed('Hello, world!');
    final second = await embedder.embed('Hello, world!');
    expect(first.embeddings.first.floatEmbedding, hasLength(100));
    expect(
      TextEmbedder.cosineSimilarity(
        first.embeddings.first,
        second.embeddings.first,
      ),
      closeTo(1, 0.0001),
    );
  });

  test('the GPU delegate is refused before a model loads', () async {
    await expectLater(
      TextClassifier.create(
        TextClassifierOptions(
          modelPath: 'models/bert_classifier.tflite',
          delegate: Delegate.gpu,
        ),
      ),
      throwsA(
        isA<RuntimeUnavailableException>().having(
          (e) => e.fix,
          'fix',
          contains('CPU only'),
        ),
      ),
    );
  });

  test('generative options read their model from a file', () {
    expect(
      () => TextProofreaderOptions(modelBytes: Uint8List(1)),
      throwsArgumentError,
    );
    expect(
      () => TextSummarizerOptions(modelBytes: Uint8List(1)),
      throwsArgumentError,
    );
    expect(
      () => TextSummarizerOptions(modelPath: 'model', maxNumTokens: -1),
      throwsArgumentError,
    );
  });
}
