@TestOn('vm')
@Tags(['native-assets'])
library;

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:mediapipe_retrieval/mediapipe_retrieval.dart';
import 'package:test/test.dart';

/// Google's EmbeddingGemma 2 text and vision model; `make models_retrieval`
/// downloads it.
final _model =
    Platform.environment['MEDIAPIPE_RETRIEVAL_MODEL'] ??
    'models/embeddinggemma-2-text-vision-440m.litertlm';

/// Google's answers from its own Python API (tool/generate_reference.py).
final _reference =
    jsonDecode(
          File(
            'test/fixtures/embedding_gemma_2_text_vision_reference.json',
          ).readAsStringSync(),
        )
        as Map<String, Object?>;

final _host =
    '${Platform.operatingSystem}/${Abi.current().toString().split('_').last}';

void main() {
  final missing = File(_model).existsSync()
      ? null
      : 'No EmbeddingGemma 2 model at $_model; set MEDIAPIPE_RETRIEVAL_MODEL.';
  // The reference host runs the same engine; another host's build may round
  // differently, and a query's close neighbours may swap places there.
  final sameHost = _host == 'macos/arm64';
  final tolerance = sameHost ? 1e-3 : 0.02;
  // The vision encoder differs by up to 2e-3 per dimension even on GitHub's
  // virtual Mac, and Linux's vector sits at cosine 0.998 to the reference, so
  // images get a looser bound and a cosine floor instead.
  final imageTolerance = sameHost ? 0.01 : 0.02;
  final imageCosineFloor = sameHost ? 0.995 : 0.99;
  final texts = (_reference['texts']! as Map).cast<String, String>();
  final vectors = (_reference['embeddings']! as Map).cast<String, List>();
  final documents = (_reference['documents']! as Map).cast<String, Map>();
  late UniversalEmbedder embedder;

  setUpAll(() async {
    if (missing != null) return;
    embedder = await UniversalEmbedder.create(
      UniversalEmbedderOptions(modelPath: _model),
    );
  });
  tearDownAll(() async {
    if (missing == null) await embedder.dispose();
  });

  test('text embeddings match Google\'s Python API', skip: missing, () async {
    for (final MapEntry(key: name, value: text) in texts.entries) {
      final result = await embedder.embedText(text);
      final embedding = result.embeddings.single;
      final expected = vectors[name]!.cast<num>();
      expect(
        embedding.floatEmbedding,
        hasLength(expected.length),
        reason: name,
      );
      for (var i = 0; i < expected.length; i++) {
        expect(
          embedding.floatEmbedding![i],
          closeTo(expected[i].toDouble(), tolerance),
          reason: '$name[$i]',
        );
      }
    }
  });

  test('cosine similarities match Google\'s', skip: missing, () async {
    final similarities = (_reference['similarities']! as Map)
        .cast<String, Map>();
    for (final MapEntry(key: query, value: row) in similarities.entries) {
      final q = (await embedder.embedText(texts[query]!)).embeddings.single;
      for (final MapEntry(key: doc, value: expected) in row.entries) {
        final d = (await embedder.embedText(texts[doc]!)).embeddings.single;
        expect(
          UniversalEmbedder.cosineSimilarity(q, d),
          closeTo((expected as num).toDouble(), tolerance),
          reason: '$query vs $doc',
        );
      }
    }
  });

  test('image embeddings match Google\'s Python API', skip: missing, () async {
    final sentence = (await embedder.embedText(
      _reference['imageText']! as String,
    )).embeddings.single;
    final images = (_reference['images']! as Map).cast<String, Map>();
    // The gallery's samples, from the repository root.
    final root = Directory.current.parent.parent;
    for (final MapEntry(key: name, value: image) in images.entries) {
      final bytes = File('${root.path}/${image['path']}').readAsBytesSync();
      final result = await embedder.embedImage(bytes);
      final embedding = result.embeddings.single;
      final expected = (image['embedding'] as List).cast<num>();
      expect(
        embedding.floatEmbedding,
        hasLength(expected.length),
        reason: name,
      );
      for (var i = 0; i < expected.length; i++) {
        expect(
          embedding.floatEmbedding![i],
          closeTo(expected[i].toDouble(), imageTolerance),
          reason: '$name[$i]',
        );
      }
      final reference = Embedding(
        floatEmbedding: Float32List.fromList([
          for (final v in expected) v.toDouble(),
        ]),
        headIndex: embedding.headIndex,
      );
      expect(
        UniversalEmbedder.cosineSimilarity(reference, embedding),
        greaterThan(imageCosineFloor),
        reason: '$name against Google\'s vector',
      );
      expect(
        UniversalEmbedder.cosineSimilarity(sentence, embedding),
        closeTo((image['similarityToText'] as num).toDouble(), imageTolerance),
        reason: name,
      );
    }
  });

  test('retrieval matches Google\'s Python API', skip: missing, () async {
    final retriever = await SemanticRetriever.create(
      SemanticRetrieverOptions(embedder: embedder),
    );
    try {
      for (final MapEntry(key: id, value: document) in documents.entries) {
        await retriever.insertDocument(
          id,
          document['text'] as String,
          metadata: (document['metadata'] as Map).cast<String, String>(),
        );
      }
      final ids = (_reference['recordIds']! as Map).cast<String, List>();
      expect(
        (await retriever.getAllRecordIds())..sort(),
        ids['all']!.cast<String>(),
      );
      for (final raw in _reference['retrieval']! as List) {
        final reference = raw as Map;
        final query = reference['query'] as String;
        void compare(RetrievalResult result, Object? want, String name) {
          final expected = (want! as List).cast<Map>();
          final why = '$query $name: ${result.records}';
          expect(result.records, hasLength(expected.length), reason: why);
          for (var i = 0; i < expected.length; i++) {
            final record = result.records[i];
            final e = expected[i];
            if (sameHost) expect(record.id, e['id'], reason: why);
            expect(
              record.score,
              closeTo((e['score'] as num).toDouble(), tolerance),
              reason: why,
            );
            expect(
              record.metadata,
              (e['metadata'] as Map).cast<String, String>(),
              reason: why,
            );
            expect(record.text, isNotEmpty, reason: why);
          }
          if (!sameHost) {
            expect(
              result.records.map((r) => r.id).toSet(),
              expected.map((e) => e['id']).toSet(),
              reason: why,
            );
          }
        }

        compare(
          await retriever.retrieve(query, limit: 3, minSimilarity: 0),
          reference['top3'],
          'top3',
        );
        compare(
          await retriever.retrieve(query, limit: 3),
          reference['default'],
          'default threshold',
        );
        compare(
          await retriever.retrieve(
            query,
            limit: 3,
            minSimilarity: 0,
            metadataFilter: {'topic': 'animals'},
          ),
          reference['animals'],
          'animals',
        );
      }
      await retriever.delete('cat');
      expect(
        (await retriever.getAllRecordIds())..sort(),
        ids['afterDeleteCat']!.cast<String>(),
      );
      await retriever.deleteWithMetadataFilter({'topic': 'animals'});
      expect(
        (await retriever.getAllRecordIds())..sort(),
        ids['afterDeleteAnimals']!.cast<String>(),
      );
      await retriever.deleteAll();
      expect(await retriever.getAllRecordIds(), isEmpty);
    } finally {
      await retriever.dispose();
    }
  });

  test('image records match Google\'s Python API', skip: missing, () async {
    final retriever = await SemanticRetriever.create(
      SemanticRetrieverOptions(embedder: embedder),
    );
    final images = (_reference['images']! as Map).cast<String, Map>();
    final root = Directory.current.parent.parent;
    final sentence = _reference['imageText']! as String;
    final expected = (_reference['imageRetrieval']! as Map)
        .cast<String, List>();
    try {
      for (final MapEntry(key: name, value: image) in images.entries) {
        await retriever.insertImage(
          'image:$name',
          imageBytes: File('${root.path}/${image['path']}').readAsBytesSync(),
          metadata: {'animal': name},
        );
      }
      void compare(RetrievalResult result, String name) {
        final want = expected[name]!.cast<Map>();
        final why = '$name: ${result.records}';
        expect(result.records, hasLength(want.length), reason: why);
        for (var i = 0; i < want.length; i++) {
          final record = result.records[i];
          if (sameHost) expect(record.id, want[i]['id'], reason: why);
          expect(
            record.score,
            closeTo((want[i]['score'] as num).toDouble(), imageTolerance),
            reason: why,
          );
          expect(
            record.metadata,
            (want[i]['metadata'] as Map).cast<String, String>(),
            reason: why,
          );
          // Inserted from bytes alone, so the stand-in path is the id.
          expect(record.text, record.id, reason: why);
        }
        expect(
          result.records.map((r) => r.id).toSet(),
          want.map((e) => e['id']).toSet(),
          reason: why,
        );
      }

      compare(
        await retriever.retrieve(sentence, limit: 3, minSimilarity: 0),
        'top3',
      );
      compare(
        await retriever.retrieve(
          sentence,
          limit: 3,
          minSimilarity: 0,
          metadataFilter: {'animal': 'cat'},
        ),
        'cat',
      );
    } finally {
      await retriever.dispose();
    }
  });

  test(
    'mixed content and images index through the same embedder',
    skip: missing,
    () async {
      final retriever = await SemanticRetriever.create(
        SemanticRetrieverOptions(embedder: embedder),
      );
      try {
        final photo = File(
          '${Directory.current.parent.parent.path}/gallery/samples/'
          'elephant.png',
        ).readAsBytesSync();
        await retriever.insertContent(
          'mixed',
          [TextPart('A dog chases a ball across the park.')],
          metadata: {'topic': 'animals'},
        );
        // Image parts from bytes alone, which Google's runtime refuses
        // without a path: the package passes the record's id, or "query".
        await retriever.insertContent('photo', [ImagePart(imageBytes: photo)]);
        final result = await retriever.retrieve(
          'A puppy playing fetch.',
          limit: 1,
          minSimilarity: 0,
        );
        expect(result.records.single.id, 'mixed');
        expect(result.records.single.metadata, {'topic': 'animals'});
        final byImage = await retriever.retrieveContent(
          [ImagePart(imageBytes: photo)],
          limit: 1,
          minSimilarity: 0,
        );
        expect(byImage.records.single.id, 'photo');
      } finally {
        await retriever.dispose();
      }
    },
  );

  test('a disposed task refuses requests', skip: missing, () async {
    final other = await UniversalEmbedder.create(
      UniversalEmbedderOptions(modelPath: _model),
    );
    final retriever = await SemanticRetriever.create(
      SemanticRetrieverOptions(embedder: other),
    );
    await retriever.dispose();
    await retriever.dispose();
    expect(() => retriever.deleteAll(), throwsStateError);
    await other.dispose();
    await other.dispose();
    expect(() => other.embedText('text'), throwsStateError);
  });

  test('Google\'s failures are TaskExceptions', () async {
    await expectLater(
      UniversalEmbedder.create(
        UniversalEmbedderOptions(modelPath: '/nonexistent/model.litertlm'),
      ),
      throwsA(isA<TaskException>()),
    );
  });
}
