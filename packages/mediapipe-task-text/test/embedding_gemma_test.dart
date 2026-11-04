// Needs the generative text models (make models) and, off macOS arm64,
// same-host references; see dart_test.yaml.
@Tags(['modern-text'])
@TestOn('mac-os || linux || windows')
library;

import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:mediapipe_text/mediapipe_text.dart';
import 'package:mediapipe_text/src/io/third_party/mediapipe/embedding_gemma_bindings.dart'
    as mp;
import 'package:test/test.dart';

import 'support/modern_text_reference.dart';

final model = File('models/embedding_gemma.task').absolute.path;
final reference = loadReference('embedding_gemma');
final cases = (reference['cases'] as List).cast<Map<String, dynamic>>();

TextFormatContext? contextFor(Map<String, dynamic> entry) {
  final context = entry['context'] as Map<String, dynamic>?;
  if (context == null) return null;
  const types = [
    'RETRIEVAL_QUERY',
    'RETRIEVAL_DOCUMENT',
    'SEMANTIC_SIMILARITY',
    'CLASSIFICATION',
    'CLUSTERING',
    'QUESTION_ANSWERING',
    'FACT_CHECKING',
    'CODE_RETRIEVAL',
  ];
  return TextFormatContext(
    taskType: EmbeddingType.values[types.indexOf(context['task_type'])],
    title: context['title'],
    role: context['role'] == 'DOCUMENT' ? TextRole.document : TextRole.query,
  );
}

void compare(TextEmbedderResult result, Map<String, dynamic> entry) {
  final expected = entry['embeddings'] as List;
  expect(result.embeddings, hasLength(expected.length));
  // The library stamps each request; Google's Python ctypes misread it as
  // absent (see tool/official_embedding_layout.py).
  expect(result.timestampMilliseconds, isNotNull);
  for (var i = 0; i < expected.length; i++) {
    final embedding = result.embeddings[i];
    expect(embedding.headIndex, expected[i]['head_index']);
    expect(embedding.headName, expected[i]['head_name']);
    expect(embedding.length, 768);
    final values = expected[i]['values'] as List;
    if (entry['quantize'] == true) {
      expect(embedding.floatEmbedding, isNull);
      expect(embedding.quantizedEmbedding, values);
    } else {
      expect(embedding.quantizedEmbedding, isNull);
      for (var j = 0; j < values.length; j++) {
        expect(
          embedding.floatEmbedding![j],
          closeTo((values[j] as num).toDouble(), 1e-6),
          reason: '${entry['name']} head $i value $j',
        );
      }
    }
  }
}

void main() {
  test("the reference comes from this host's pinned runtime", () async {
    await expectReferenceRuntime(
      reference,
      () => queryTextEmbedderCapabilities(TextModels.embeddingGemma),
    );
  });

  test("FFI layout matches the official Python ABI of this host's wheel", () {
    final abi = reference['abi'] as Map<String, dynamic>;
    expect(sizeOf<mp.MpBaseOptions>(), abi['MpBaseOptionsC']['size']);
    expect(sizeOf<mp.MpEmbedderOptions>(), abi['_MpEmbedderOptionsC']['size']);
    expect(
      sizeOf<mp.MpTextEmbedderOptions>(),
      abi['_MpTextEmbedderOptionsC']['size'],
    );
    expect(
      sizeOf<mp.MpTextFormatContext>(),
      abi['_MpTextFormatContextC']['size'],
    );
    expect(sizeOf<mp.MpEmbedding>(), abi['MpEmbeddingC']['size']);
    expect(sizeOf<mp.MpEmbeddingResult>(), abi['MpEmbeddingResultC']['size']);
    using((arena) {
      final options = arena<mp.MpTextEmbedderOptions>();
      options.ref.baseOptions
        ..fileDescriptor = -1
        ..hostSystem = 2
        ..modelAssetBufferCount = 0x12345678;
      final data = options
          .cast<Uint8>()
          .asTypedList(sizeOf<mp.MpTextEmbedderOptions>())
          .buffer
          .asByteData();
      final offsets = abi['MpBaseOptionsC']['offsets'];
      expect(data.getInt32(offsets['file_descriptor'], Endian.host), -1);
      expect(data.getInt32(offsets['host_system'], Endian.host), 2);
      expect(
        data.getUint32(offsets['model_asset_buffer_count'], Endian.host),
        0x12345678,
      );
      final format = arena<mp.MpTextFormatContext>();
      format.ref
        ..taskType = 8
        ..role = 2
        ..title = Pointer.fromAddress(1234);
      final bytes = format
          .cast<Uint8>()
          .asTypedList(sizeOf<mp.MpTextFormatContext>())
          .buffer
          .asByteData();
      final fields = abi['_MpTextFormatContextC']['offsets'];
      expect(bytes.getInt32(fields['task_type'], Endian.host), 8);
      expect(bytes.getInt32(fields['role'], Endian.host), 2);
      expect(bytes.getUint64(fields['title'], Endian.host), 1234);
    });
  });

  for (final quantize in [false, true]) {
    test('official CPU reference embeddings, quantize=$quantize', () async {
      final task = await TextEmbedder.create(
        TextEmbedderOptions(
          modelPath: model,
          quantize: quantize,
          l2Normalize: quantize,
        ),
      );
      try {
        for (final entry in cases.where(
          (entry) => entry['quantize'] == quantize,
        )) {
          compare(
            await task.embed(entry['text'], formatContext: contextFor(entry)),
            entry,
          );
        }
      } finally {
        await task.dispose();
      }
    }, timeout: const Timeout(Duration(minutes: 2)));
  }

  test(
    'concurrent requests keep their own results; disposal drains the queue',
    () async {
      final task = await TextEmbedder.create(
        TextEmbedderOptions(modelPath: model),
      );
      final selected = cases.sublist(1, 4);
      final pending = [
        for (final entry in selected)
          task.embed(entry['text'], formatContext: contextFor(entry)),
      ];
      final closing = task.dispose();
      final results = await Future.wait(pending);
      await closing;
      await task.dispose();
      for (var i = 0; i < selected.length; i++) {
        compare(results[i], selected[i]);
      }
      final cat = results[0].embeddings.single;
      final related = TextEmbedder.cosineSimilarity(
        cat,
        results[1].embeddings.single,
      );
      final unrelated = TextEmbedder.cosineSimilarity(
        cat,
        results[2].embeddings.single,
      );
      expect(related, greaterThan(unrelated));
      expect(TextEmbedder.cosineSimilarity(cat, cat), closeTo(1, 1e-12));
      expect(() => cat.floatEmbedding![0] = 0, throwsUnsupportedError);
      await expectLater(task.embed('closed'), throwsStateError);
    },
  );

  test('buffer model produces the same official embedding', () async {
    final task = await TextEmbedder.create(
      TextEmbedderOptions(modelBytes: await File(model).readAsBytes()),
    );
    try {
      compare(await task.embed(cases.first['text']), cases.first);
    } finally {
      await task.dispose();
    }
  });

  test('creation errors propagate instead of hanging the worker', () async {
    await expectLater(
      TextEmbedder.create(TextEmbedderOptions(modelPath: '$model.missing')),
      throwsA(isA<TaskException>()),
    );
    await expectLater(
      TextEmbedder.create(
        TextEmbedderOptions(modelBytes: Uint8List.fromList([1, 2, 3])),
      ),
      throwsA(isA<TaskException>()),
    );
    await expectLater(
      TextEmbedder.create(
        TextEmbedderOptions(modelPath: model, delegate: Delegate.gpu),
      ),
      throwsA(
        isA<RuntimeUnavailableException>().having(
          (e) => e.fix,
          'fix',
          contains('CPU'),
        ),
      ),
    );
  }, timeout: const Timeout(Duration(seconds: 20)));

  test('invalid Dart inputs are rejected without poisoning the task', () async {
    expect(() => TextEmbedderOptions(), throwsArgumentError);
    expect(() => TextEmbedderOptions(modelPath: ''), throwsArgumentError);
    expect(
      () => TextEmbedderOptions(modelPath: model, modelBytes: Uint8List(1)),
      throwsArgumentError,
    );
    expect(
      () => TextFormatContext(
        taskType: EmbeddingType.retrievalDocument,
        title: 'bad\u0000title',
      ),
      throwsArgumentError,
    );
    final task = await TextEmbedder.create(
      TextEmbedderOptions(modelPath: model),
    );
    try {
      await expectLater(task.embed('bad\u0000text'), throwsArgumentError);
      compare(await task.embed(cases.first['text']), cases.first);
    } finally {
      await task.dispose();
    }
  });

  test('cosine uses signed quantized bytes and validates vector types', () {
    Embedding q(List<int> values) =>
        Embedding(quantizedEmbedding: Uint8List.fromList(values), headIndex: 0);
    expect(
      TextEmbedder.cosineSimilarity(q([127, 128]), q([128, 127])),
      lessThan(-.99),
    );
    expect(
      () => TextEmbedder.cosineSimilarity(q([0]), q([1])),
      throwsArgumentError,
    );
    expect(
      () => TextEmbedder.cosineSimilarity(q([1]), q([1, 2])),
      throwsArgumentError,
    );
    expect(
      () => TextEmbedder.cosineSimilarity(
        q([1]),
        Embedding(floatEmbedding: Float32List.fromList([1]), headIndex: 0),
      ),
      throwsArgumentError,
    );
  });

  test(
    'official token-limit failures propagate through inference and close',
    () async {
      final task = await TextEmbedder.create(
        TextEmbedderOptions(modelPath: model),
      );
      await expectLater(
        task.embed(
          List.filled(160, 'A cat sleeps peacefully. ').join(),
          formatContext: TextFormatContext(
            taskType: EmbeddingType.semanticSimilarity,
          ),
        ),
        throwsA(
          isA<TaskException>().having(
            (e) => e.message,
            'message',
            contains('too long'),
          ),
        ),
      );
      await expectLater(
        task.embed('The graph has already failed.'),
        throwsA(isA<TaskException>()),
      );
      final closing = task.dispose();
      expect(identical(closing, task.dispose()), isTrue);
      await expectLater(closing, throwsA(isA<TaskException>()));
      await expectLater(task.embed('closed'), throwsStateError);
    },
  );
}
