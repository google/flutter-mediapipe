import 'dart:typed_data';

import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_core/platform_interface.dart';
import 'package:mediapipe_core/platform_interface.dart' as core;

import 'capabilities.dart';
import 'results/decoders.dart';
import 'retrieval_backend.dart';
import 'runner/native_tasks.dart';
import 'types/content.dart';
import 'types/options.dart';
import 'types/results.dart';

/// Google's Universal Embedder: text, encoded images and audio samples as
/// vectors in one embedding space, from an EmbeddingGemma 2 model.
///
/// One class on every platform. Google's retrieval library serves it on a
/// worker isolate on Android, iOS, macOS, Linux and Windows; its browser
/// runtime serves it through the registered web plugin.
///
/// ```dart
/// final embedder = await UniversalEmbedder.create(
///   UniversalEmbedderOptions(model: RetrievalModels.embeddingGemma2TextVision),
/// );
/// final a = await embedder.embedText('A dog chasing a ball in the park.');
/// final b = await embedder.embedText('A puppy playing fetch outside.');
/// final similarity = UniversalEmbedder.cosineSimilarity(
///   a.embeddings.first,
///   b.embeddings.first,
/// );
/// await embedder.dispose();
/// ```
/// Calls run one at a time, in call order, together with those of the
/// [SemanticRetriever]s built on the embedder. A `Future` cannot cancel
/// native work; `dispose()` waits for work already accepted, closes the
/// retrievers still open, and is idempotent.
final class UniversalEmbedder {
  UniversalEmbedder._(this._backend, this.delegate);

  final RetrievalBackend _backend;
  final _queue = SerialTaskQueue('UniversalEmbedder');

  /// The processor the task runs on, fixed at creation.
  final Delegate delegate;

  /// Resolves the model and opens Google's task off the calling isolate.
  static Future<UniversalEmbedder> create(
    UniversalEmbedderOptions options,
  ) async {
    requireDelegate(
      await queryUniversalEmbedderCapabilities(),
      options.delegate,
    );
    await resolveTaskModel(options);
    final RetrievalBackend backend;
    if (retrievalBackendFactory case final factory?) {
      try {
        backend = await factory({
          'modelBytes': options.modelBytes,
          'modelPath': options.modelPath,
          'delegate': options.delegate.name.toUpperCase(),
          'l2Normalize': options.l2Normalize,
          'maxInputLength': options.maxInputLength == 0
              ? null
              : options.maxInputLength,
          'visionTokensPerImage': options.visionTokensPerImage == 0
              ? null
              : options.visionTokensPerImage,
          'activationDataType': switch (options.activationDataType) {
            ActivationDataType.modelDefault => null,
            ActivationDataType.float32 => 'FLOAT32',
            ActivationDataType.float16 => 'FLOAT16',
            ActivationDataType.int16 => 'INT16',
            ActivationDataType.int8 => 'INT8',
          },
        });
      } catch (error) {
        throw taskException(error);
      }
    } else {
      backend = await openNativeUniversalEmbedder(options);
    }
    return UniversalEmbedder._(backend, options.delegate);
  }

  /// The embedding of [text].
  Future<UniversalEmbedderResult> embedText(String text) async =>
      decodeEmbedderResult(
        await _run({'method': 'embedText', 'text': checkedText(text)}),
      );

  /// The embedding of an encoded image (JPEG or PNG) in [imageBytes].
  Future<UniversalEmbedderResult> embedImage(Uint8List imageBytes) async {
    if (imageBytes.isEmpty) {
      throw ArgumentError.value(imageBytes, 'imageBytes', 'Must not be empty.');
    }
    return decodeEmbedderResult(
      await _run({
        'method': 'embedImage',
        'imageBytes': Uint8List.fromList(imageBytes),
      }),
    );
  }

  /// The embedding of mono PCM [audioData], at the rate the model expects.
  Future<UniversalEmbedderResult> embedAudio(Float32List audioData) async {
    if (audioData.isEmpty) {
      throw ArgumentError.value(audioData, 'audioData', 'Must not be empty.');
    }
    return decodeEmbedderResult(
      await _run({
        'method': 'embedAudio',
        'audioData': Float32List.fromList(audioData),
      }),
    );
  }

  /// Cosine similarity of two embeddings, the same on every platform.
  static double cosineSimilarity(Embedding first, Embedding second) =>
      core.cosineSimilarity(first, second);

  /// Finishes accepted work, closes the retrievers built on this embedder and
  /// releases Google's task. Repeated calls return the same completion; any
  /// other call afterwards throws [StateError].
  Future<void> dispose() => _queue.close(_backend.dispose);

  /// Runs [request] after every request accepted before it.
  Future<Object?> _run(Map<String, Object?> request) =>
      _queue.add(() => _backend.run(request));
}

/// Google's Semantic Retriever: an on-device vector index over documents,
/// images, audio and mixed content, searched with text or multimodal
/// queries, embedded by a [UniversalEmbedder].
///
/// ```dart
/// final retriever = await SemanticRetriever.create(
///   SemanticRetrieverOptions(embedder: embedder),
/// );
/// await retriever.insertDocument('doc1', 'How to compute semantic distance.');
/// await retriever.insertDocument('doc2', 'Vector search libraries for Dart.');
/// final result = await retriever.retrieve('What is vector search?', limit: 1);
/// print(result.records.first.id);
/// await retriever.dispose();
/// ```
/// Requests run on the embedder's worker, in order with its own. Dispose a
/// retriever before its embedder; disposing the embedder first closes the
/// retriever, whose later calls then fail.
final class SemanticRetriever {
  SemanticRetriever._(this._embedder, this._id);

  final UniversalEmbedder _embedder;
  final int _id;
  Future<void>? _disposing;

  /// The processor the retriever's embedder runs on.
  Delegate get delegate => _embedder.delegate;

  /// Opens Google's retriever on [SemanticRetrieverOptions.embedder]'s worker.
  static Future<SemanticRetriever> create(
    SemanticRetrieverOptions options,
  ) async {
    final json = await options.embedder._run({
      'method': 'retriever.create',
      'databasePath': options.databasePath,
      'embeddingDimension': options.embeddingDimension,
      'chunkSize': options.chunkSize,
      'chunkOverlap': options.chunkOverlap,
      'chunkingMode': options.chunkingMode.name,
    });
    return SemanticRetriever._(
      options.embedder,
      ((json! as Map)['id']! as num).toInt(),
    );
  }

  /// Indexes [text] under [id], chunked as the options say, with [metadata]
  /// to filter on later. Inserting an existing [id] replaces the record.
  Future<void> insertDocument(
    String id,
    String text, {
    Map<String, String> metadata = const {},
  }) async {
    await _run({
      'method': 'retriever.insertDocument',
      'recordId': _recordId(id),
      'text': TextPart(text).text,
      'metadata': checkedMetadata(metadata),
    });
  }

  /// Indexes an image under [id]: encoded [imageBytes], or on the native
  /// platforms a [filePath] Google's runtime decodes itself.
  Future<void> insertImage(
    String id, {
    Uint8List? imageBytes,
    String? filePath,
    Map<String, String> metadata = const {},
  }) async {
    final part = ImagePart(imageBytes: imageBytes, filePath: filePath);
    await _run({
      'method': 'retriever.insertImage',
      'recordId': _recordId(id),
      'imageBytes': part.imageBytes,
      'filePath': part.filePath,
      'metadata': checkedMetadata(metadata),
    });
  }

  /// Indexes audio under [id]: mono PCM [audioData], or on the native
  /// platforms an [audioPath] to a WAV file Google's runtime decodes itself.
  Future<void> insertAudio(
    String id, {
    Float32List? audioData,
    String? audioPath,
    Map<String, String> metadata = const {},
  }) async {
    final part = AudioPart(audioData: audioData, audioPath: audioPath);
    await _run({
      'method': 'retriever.insertAudio',
      'recordId': _recordId(id),
      'audioData': part.audioData,
      'audioPath': part.audioPath,
      'metadata': checkedMetadata(metadata),
    });
  }

  /// Indexes mixed [parts] as one record under [id].
  Future<void> insertContent(
    String id,
    List<ContentPart> parts, {
    Map<String, String> metadata = const {},
  }) async {
    if (parts.isEmpty) {
      throw ArgumentError.value(parts, 'parts', 'Must not be empty.');
    }
    await _run({
      'method': 'retriever.insertContent',
      'recordId': _recordId(id),
      'parts': [for (final part in parts) part.toJson()],
      'metadata': checkedMetadata(metadata),
    });
  }

  /// The records nearest to a text [query], best first: at most [limit] of
  /// them, scoring at least [minSimilarity] (Google's default 0.5), and
  /// carrying every pair of [metadataFilter] when one is given.
  Future<RetrievalResult> retrieve(
    String query, {
    int limit = 5,
    double minSimilarity = 0.5,
    Map<String, String>? metadataFilter,
  }) => retrieveContent(
    [TextPart(query)],
    limit: limit,
    minSimilarity: minSimilarity,
    metadataFilter: metadataFilter,
  );

  /// [retrieve] for a multimodal [query].
  Future<RetrievalResult> retrieveContent(
    List<ContentPart> query, {
    int limit = 5,
    double minSimilarity = 0.5,
    Map<String, String>? metadataFilter,
  }) async {
    if (query.isEmpty) {
      throw ArgumentError.value(query, 'query', 'Must not be empty.');
    }
    if (limit <= 0) throw ArgumentError.value(limit, 'limit', 'Must be > 0.');
    if (!minSimilarity.isFinite) {
      throw ArgumentError.value(
        minSimilarity,
        'minSimilarity',
        'Must be finite.',
      );
    }
    return decodeRetrievalResult(
      await _run({
        'method': 'retriever.retrieve',
        'parts': [for (final part in query) part.toJson()],
        'limit': limit,
        'minSimilarity': minSimilarity,
        'metadataFilter': metadataFilter == null || metadataFilter.isEmpty
            ? null
            : checkedMetadata(metadataFilter),
      }),
    );
  }

  /// Removes the record inserted under [id].
  Future<void> delete(String id) async {
    await _run({'method': 'retriever.delete', 'recordId': _recordId(id)});
  }

  /// Removes every record carrying all pairs of [metadataFilter].
  Future<void> deleteWithMetadataFilter(
    Map<String, String> metadataFilter,
  ) async {
    if (metadataFilter.isEmpty) {
      throw ArgumentError.value(
        metadataFilter,
        'metadataFilter',
        'Must not be empty.',
      );
    }
    await _run({
      'method': 'retriever.deleteWithMetadataFilter',
      'metadataFilter': checkedMetadata(metadataFilter),
    });
  }

  /// Removes every record.
  Future<void> deleteAll() async {
    await _run({'method': 'retriever.deleteAll'});
  }

  /// The ids of every record in the index.
  Future<List<String>> getAllRecordIds() async =>
      decodeRecordIds(await _run({'method': 'retriever.getAllRecordIds'}));

  /// Finishes accepted work and releases Google's retriever, leaving the
  /// embedder open. Repeated calls return the same completion; any other
  /// call afterwards throws [StateError].
  Future<void> dispose() => _disposing ??= () async {
    try {
      await _embedder._run({'method': 'retriever.close', 'retriever': _id});
    } on StateError {
      // The embedder was disposed first and closed this retriever with it.
    }
  }();

  Future<Object?> _run(Map<String, Object?> request) {
    if (_disposing != null) {
      throw StateError('SemanticRetriever has been disposed.');
    }
    return _embedder._run({...request, 'retriever': _id});
  }

  String _recordId(String id) {
    if (id.isEmpty || id.contains('\u0000')) {
      throw ArgumentError.value(id, 'id', 'Must be non-empty, without NUL.');
    }
    return id;
  }
}

/// Google's C API reads NUL-terminated strings.
String checkedText(String text) {
  if (text.contains('\u0000')) {
    throw ArgumentError.value(text, 'text', 'Must not contain NUL.');
  }
  return text;
}

/// [metadata] with non-empty keys and no NUL anywhere, as a fresh map.
Map<String, String> checkedMetadata(Map<String, String> metadata) {
  for (final MapEntry(:key, :value) in metadata.entries) {
    if (key.isEmpty || key.contains('\u0000') || value.contains('\u0000')) {
      throw ArgumentError.value(
        metadata,
        'metadata',
        'Keys must be non-empty, and keys and values free of NUL.',
      );
    }
  }
  return Map.of(metadata);
}
