@TestOn('vm')
@Tags(['native-assets'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:mediapipe_retrieval/mediapipe_retrieval.dart';
import 'package:test/test.dart';

/// Google's full EmbeddingGemma 2 model, the only one that embeds audio;
/// `make models_retrieval` downloads it.
final _model =
    Platform.environment['MEDIAPIPE_RETRIEVAL_AUDIO_MODEL'] ??
    'models/embeddinggemma-2-740m.litertlm';

/// Google's answers from its own Python API
/// (`tool/generate_reference.py --audio`).
final _reference =
    jsonDecode(
          File(
            'test/fixtures/embedding_gemma_2_audio_reference.json',
          ).readAsStringSync(),
        )
        as Map<String, Object?>;

/// The first [count] samples of a mono 16-bit PCM WAV file, as the floats
/// Google's audio tasks take, the same values the reference generator reads.
Float32List _samples(String path, int count) {
  final bytes = File(path).readAsBytesSync();
  final data = ByteData.sublistView(bytes);
  var offset = 12;
  int? channels, bits;
  while (offset + 8 <= bytes.length) {
    final id = ascii.decode(bytes.sublist(offset, offset + 4));
    final size = data.getUint32(offset + 4, Endian.little);
    final body = offset + 8;
    if (id == 'fmt ') {
      channels = data.getUint16(body + 2, Endian.little);
      bits = data.getUint16(body + 14, Endian.little);
    } else if (id == 'data') {
      expect((channels, bits), (1, 16), reason: path);
      return Float32List.fromList([
        for (var i = body; i + 1 < body + size && i < body + 2 * count; i += 2)
          data.getInt16(i, Endian.little) / 32768.0,
      ]);
    }
    offset = body + size + size % 2;
  }
  throw StateError('$path has no data chunk.');
}

void main() {
  final missing = File(_model).existsSync()
      ? null
      : 'No EmbeddingGemma 2 model at $_model; set '
            'MEDIAPIPE_RETRIEVAL_AUDIO_MODEL.';
  // Google's audio embeddings vary from call to call, in its Python as here,
  // by up to about 0.005 per value and 0.004 in a score (upstream-issues.md
  // UP-058), so audio gets bounds that hold on every host, and records are
  // compared as a set.
  const tolerance = 0.01;
  const cosineFloor = 0.998;
  final clips = (_reference['audio']! as Map).cast<String, Map>();
  // The audio package's clips, from the repository root.
  final root = Directory.current.parent.parent;
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

  test('audio embeddings match Google\'s Python API', skip: missing, () async {
    for (final MapEntry(key: name, value: clip) in clips.entries) {
      final result = await embedder.embedAudio(
        _samples('${root.path}/${clip['path']}', clip['samples'] as int),
      );
      final embedding = result.embeddings.single;
      final expected = (clip['embedding'] as List).cast<num>();
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
      final reference = Embedding(
        floatEmbedding: Float32List.fromList([
          for (final v in expected) v.toDouble(),
        ]),
        headIndex: embedding.headIndex,
      );
      expect(
        UniversalEmbedder.cosineSimilarity(reference, embedding),
        greaterThan(cosineFloor),
        reason: '$name against Google\'s vector',
      );
      final texts = (clip['similarityToTexts'] as Map).cast<String, num>();
      for (final MapEntry(key: text, value: similarity) in texts.entries) {
        final sentence = (await embedder.embedText(text)).embeddings.single;
        expect(
          UniversalEmbedder.cosineSimilarity(sentence, embedding),
          closeTo(similarity.toDouble(), tolerance),
          reason: '$name vs $text',
        );
      }
    }
  });

  test('audio records match Google\'s Python API', skip: missing, () async {
    final retriever = await SemanticRetriever.create(
      SemanticRetrieverOptions(embedder: embedder),
    );
    try {
      for (final MapEntry(key: name, value: clip) in clips.entries) {
        await retriever.insertAudio(
          'audio:$name',
          audioData: _samples(
            '${root.path}/${clip['path']}',
            clip['samples'] as int,
          ),
          metadata: {'clip': name},
        );
      }
      for (final raw in _reference['audioRetrieval']! as List) {
        final reference = raw as Map;
        final query = reference['query'] as String;
        final want = (reference['top2'] as List).cast<Map>();
        final result = await retriever.retrieve(
          query,
          limit: 2,
          minSimilarity: 0,
        );
        final why = '$query: ${result.records}';
        expect(result.records, hasLength(want.length), reason: why);
        for (var i = 0; i < want.length; i++) {
          final record = result.records.firstWhere(
            (r) => r.id == want[i]['id'],
            orElse: () => fail(why),
          );
          expect(
            record.score,
            closeTo((want[i]['score'] as num).toDouble(), tolerance),
            reason: why,
          );
          expect(
            record.metadata,
            (want[i]['metadata'] as Map).cast<String, String>(),
            reason: why,
          );
          // Inserted from samples alone, so the stand-in path is the id.
          expect(record.text, record.id, reason: why);
        }
        expect(
          result.records.map((r) => r.id).toSet(),
          want.map((e) => e['id']).toSet(),
          reason: why,
        );
      }
    } finally {
      await retriever.dispose();
    }
  });
}
