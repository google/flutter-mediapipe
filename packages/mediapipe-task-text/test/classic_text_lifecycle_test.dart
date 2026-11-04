@Tags(['native-assets'])
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:mediapipe_text/mediapipe_text.dart';
import 'package:test/test.dart';

typedef _Task = (Future<Object> Function(String), Future<void> Function());

/// A model as a file path or in memory.
typedef _Model = ({String? path, Uint8List? bytes});

Future<_Task> _start(String name, _Model model) async {
  switch (name) {
    case 'classifier':
      final task = await TextClassifier.create(
        TextClassifierOptions(modelPath: model.path, modelBytes: model.bytes),
      );
      return (task.classify, task.dispose);
    case 'embedder':
      final task = await TextEmbedder.create(
        TextEmbedderOptions(modelPath: model.path, modelBytes: model.bytes),
      );
      return (task.embed, task.dispose);
    default:
      final task = await LanguageDetector.create(
        LanguageDetectorOptions(modelPath: model.path, modelBytes: model.bytes),
      );
      return (task.detect, task.dispose);
  }
}

Object _values(Object result) => switch (result) {
  TextClassifierResult r => [
    for (final h in r.classifications)
      [
        for (final c in h.categories) [c.categoryName, c.index, c.score],
      ],
  ],
  TextEmbedderResult r => [
    for (final e in r.embeddings) e.floatEmbedding!.toList(),
  ],
  LanguageDetectorResult r => [
    for (final p in r.predictions) [p.languageCode, p.probability],
  ],
  _ => throw StateError('Unexpected result'),
};

void main() {
  const models = {
    'classifier': 'models/bert_classifier.tflite',
    'embedder': 'models/universal_sentence_encoder.tflite',
    'language': 'models/language_detector.tflite',
  };
  for (final entry in models.entries) {
    final name = entry.key;
    final _Model model = (path: entry.value, bytes: null);
    group(name, () {
      test('preserves concurrent response order and drains queued requests on '
          'disposal', () async {
        const inputs = [
          'Hello, world!',
          'This is terrible.',
          'Quiero agua, por favor.',
          '',
          'こんにちは',
        ];
        final (reference, closeReference) = await _start(name, model);
        final expected = <Object>[];
        try {
          for (final text in inputs) {
            expected.add(_values(await reference(text)));
          }
        } finally {
          await closeReference();
        }
        final (run, close) = await _start(name, model);
        final pending = [for (final text in inputs) run(text)];
        final closing = close();
        expect(identical(closing, close()), isTrue);
        await expectLater(run('Too late'), throwsStateError);
        final results = await Future.wait(pending);
        await closing;
        expect(results.map(_values).toList(), expected);
        await close();
      });

      test(
        'can dispose before any inference and recreate repeatedly',
        () async {
          for (var i = 0; i < 3; i++) {
            final (run, close) = await _start(name, model);
            await close().timeout(const Duration(seconds: 10));
            await expectLater(run('Late'), throwsStateError);
          }
        },
      );

      test('creation reports an invalid model and leaves no task', () async {
        for (final _Model bad in [
          (path: '/nonexistent/mediapipe-model.tflite', bytes: null),
          (path: null, bytes: Uint8List.fromList([1, 2, 3, 4])),
        ]) {
          await expectLater(
            _start(name, bad).timeout(const Duration(seconds: 10)),
            throwsA(
              isA<TaskException>().having(
                (e) => e.message,
                'message',
                isNotEmpty,
              ),
            ),
          );
        }
        final (run, close) = await _start(name, model);
        try {
          expect(await run('Hello'), isNotNull);
        } finally {
          await close();
        }
      });

      test('rejects NUL without poisoning a valid task', () async {
        final (run, close) = await _start(name, model);
        try {
          await expectLater(run('Hello\u0000ignored'), throwsArgumentError);
          expect(await run('Hello'), isNotNull);
        } finally {
          await close();
        }
      });
    });
  }

  test(
    'options snapshot model bytes and filter lists and are reusable',
    () async {
      final bytes = File(models['classifier']!).readAsBytesSync();
      final allow = ['positive'];
      final options = TextClassifierOptions(
        modelBytes: bytes,
        categoryAllowlist: allow,
      );
      bytes.fillRange(0, bytes.length, 0);
      allow[0] = 'negative';
      expect(() => options.modelBytes![0] = 0, throwsUnsupportedError);
      expect(() => options.categoryAllowlist.clear(), throwsUnsupportedError);
      for (var i = 0; i < 2; i++) {
        final task = await TextClassifier.create(options);
        try {
          expect(
            (await task.classify(
              'Hello, world!',
            )).classifications.single.categories.single.categoryName,
            'positive',
          );
        } finally {
          await task.dispose();
        }
      }
    },
  );

  test('async factories report invalid models immediately', () async {
    await expectLater(
      TextClassifier.create(
        TextClassifierOptions(modelPath: '/nonexistent/model'),
      ),
      throwsA(isA<TaskException>()),
    );
    await expectLater(
      TextEmbedder.create(TextEmbedderOptions(modelPath: '/nonexistent/model')),
      throwsA(isA<TaskException>()),
    );
    await expectLater(
      LanguageDetector.create(
        LanguageDetectorOptions(modelPath: '/nonexistent/model'),
      ),
      throwsA(isA<TaskException>()),
    );
  });

  test('rejects truncated C strings and unrepresentable option values', () {
    expect(
      () => TextClassifierOptions(modelPath: 'model\u0000suffix'),
      throwsArgumentError,
    );
    expect(
      () => TextEmbedderOptions(modelBytes: Uint8List(0)),
      throwsArgumentError,
    );
    expect(
      () => LanguageDetectorOptions(
        modelPath: 'model',
        categoryAllowlist: ['en\u0000fr'],
      ),
      throwsArgumentError,
    );
    expect(
      () => TextClassifierOptions(modelPath: 'model', maxResults: 0x80000000),
      throwsArgumentError,
    );
    expect(
      () => TextClassifierOptions(modelPath: 'model', maxResults: 0),
      throwsArgumentError,
    );
    expect(
      () =>
          TextClassifierOptions(modelPath: 'model', scoreThreshold: double.nan),
      throwsArgumentError,
    );
  });

  test('similarity reads quantized bytes as signed and rejects mismatches', () {
    final a = Embedding(
      quantizedEmbedding: Uint8List.fromList([127, 128]),
      headIndex: 0,
    );
    final b = Embedding(
      quantizedEmbedding: Uint8List.fromList([128, 127]),
      headIndex: 0,
    );
    expect(TextEmbedder.cosineSimilarity(a, b), lessThan(-.99));
    expect(
      () => TextEmbedder.cosineSimilarity(
        a,
        Embedding(floatEmbedding: Float32List.fromList([1, 2]), headIndex: 0),
      ),
      throwsArgumentError,
    );
    expect(
      () => TextEmbedder.cosineSimilarity(
        a,
        Embedding(quantizedEmbedding: Uint8List(2), headIndex: 0),
      ),
      throwsArgumentError,
    );
  });
}
