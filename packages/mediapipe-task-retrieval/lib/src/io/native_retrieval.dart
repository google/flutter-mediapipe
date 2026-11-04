import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_core/native_structs.dart'
    show checkNativeStatus, fillBaseOptions, nativeString;
import 'package:mediapipe_core/platform_interface.dart';
import 'package:mediapipe_core/task_worker.dart';

import '../capabilities.dart';
import '../types/options.dart';
import 'third_party/mediapipe/retrieval_bindings.dart' as mp;

/// This process's target, as [retrievalRuntimeTargets] names it.
final _target =
    '${Platform.operatingSystem}/${Abi.current().toString().split('_').last}';

/// Fails before a worker starts where no library with the retrieval tasks
/// was bundled.
void requireRetrievalRuntime() {
  if (!retrievalRuntimeTargets.containsKey(_target)) {
    throw RuntimeUnavailableException(
      "Google's retrieval library is unavailable on this platform.",
      fix:
          "Google's per-family retrieval library covers "
          '${retrievalRuntimeTargets.keys.join(', ')}, and browsers run its '
          'JavaScript runtime.',
    );
  }
  try {
    Native.addressOf<
      NativeFunction<
        Int32 Function(
          Pointer<mp.MpUniversalEmbedderOptions>,
          Pointer<Pointer<Void>>,
          mp.MpErrorOut,
        )
      >
    >(mp.embedderCreate);
  } catch (error) {
    if (missingLinuxGraphicsLibraries('$error') case final missing?) {
      throw missing;
    }
    throw RuntimeUnavailableException(
      "Google's retrieval library is unavailable.",
      fix: tasksRuntimeUnavailable(
        'Universal Embedder',
        Platform.operatingSystem,
      ),
    );
  }
}

/// Google's Universal Embedder and the Semantic Retrievers built on it,
/// created, used and closed on one worker isolate. Requests and results are
/// the shapes of Google's JavaScript API, so both runtimes share one decoder.
final class NativeUniversalEmbedder
    extends WorkerTask<Map<String, Object?>, Object?, Never> {
  /// Loads Google's task and acquires its handle.
  NativeUniversalEmbedder(UniversalEmbedderOptions options) {
    using((arena) {
      final native = arena<mp.MpUniversalEmbedderOptions>();
      fillBaseOptions(
        native.ref.baseOptions,
        arena,
        modelPath: options.modelPath,
        modelBytes: options.modelBytes,
      );
      native.ref
        ..l2Normalize = options.l2Normalize
        ..maxInputLength = options.maxInputLength
        ..visionTokensPerImage = options.visionTokensPerImage
        ..activationDataType = options.activationDataType.index
        ..cacheDir = options.cacheDir == null
            ? nullptr
            : options.cacheDir!.toNativeUtf8(allocator: arena).cast();
      final output = arena<Pointer<Void>>();
      _check((error) => mp.embedderCreate(native, output, error));
      _handle = output.value;
      if (_handle == nullptr) {
        throw StateError('MediaPipe returned no UniversalEmbedder.');
      }
    });
  }

  Pointer<Void> _handle = nullptr;

  /// The open retrievers by the id the caller holds.
  final _retrievers = <int, Pointer<Void>>{};
  int _nextRetriever = 1;

  /// Runs one request (see `RetrievalBackend.run`).
  @override
  Object? run(Map<String, Object?> request) {
    if (_handle == nullptr) {
      throw StateError('UniversalEmbedder has been closed.');
    }
    final method = request['method']! as String;
    return using((arena) {
      Pointer<Char> string(String? value) =>
          value == null ? nullptr : value.toNativeUtf8(allocator: arena).cast();
      Pointer<Uint8> bytes(Uint8List? data) {
        if (data == null || data.isEmpty) return nullptr;
        final buffer = arena<Uint8>(data.length);
        buffer.asTypedList(data.length).setAll(0, data);
        return buffer;
      }

      Pointer<Float> floats(Float32List? data) {
        if (data == null || data.isEmpty) return nullptr;
        final buffer = arena<Float>(data.length);
        buffer.asTypedList(data.length).setAll(0, data);
        return buffer;
      }

      // Metadata as Google's key-value array, or none.
      (Pointer<mp.MpKeyValuePair>, int) pairs(Object? metadata) {
        final map = (metadata as Map?)?.cast<String, String>();
        if (map == null || map.isEmpty) return (nullptr, 0);
        final array = arena<mp.MpKeyValuePair>(map.length);
        var i = 0;
        for (final MapEntry(:key, :value) in map.entries) {
          array[i]
            ..key = string(key)
            ..value = string(value);
          i++;
        }
        return (array, map.length);
      }

      // Record or query parts as Google's MpTaskPart array. Google's runtime
      // needs a path for media even when it has the bytes or samples, and
      // keeps it as the record's text; [name] stands in where none was given.
      Pointer<mp.MpTaskPart> parts(List<Object?> list, String name) {
        final array = arena<mp.MpTaskPart>(list.length);
        for (final (i, raw) in list.indexed) {
          final part = raw! as Map;
          final target = array[i];
          switch (part['kind']) {
            case 'text':
              target.kind = 0;
              target.textPart.text = string(part['text']! as String);
            case 'image':
              final data = part['imageBytes'] as Uint8List?;
              target.kind = 1;
              target.imagePart
                ..imageBytes = bytes(data)
                ..imageBytesSize = data?.length ?? 0
                ..filePath = string(part['filePath'] as String? ?? name);
            case 'audio':
              final data = part['audioData'] as Float32List?;
              target.kind = 2;
              target.audioPart
                ..audioData = floats(data)
                ..audioDataSize = data?.length ?? 0
                ..audioPath = string(part['audioPath'] as String? ?? name);
            default:
              throw ArgumentError.value(part['kind'], 'kind');
          }
        }
        return array;
      }

      switch (method) {
        case 'embedText':
          return _embed(
            arena,
            (result, error) => mp.embedText(
              _handle,
              string(request['text']! as String),
              result,
              error,
            ),
          );
        case 'embedImage':
          final data = request['imageBytes']! as Uint8List;
          return _embed(
            arena,
            (result, error) => mp.embedImage(
              _handle,
              bytes(data).cast(),
              data.length,
              result,
              error,
            ),
          );
        case 'embedAudio':
          final data = request['audioData']! as Float32List;
          return _embed(
            arena,
            (result, error) => mp.embedAudio(
              _handle,
              floats(data),
              data.length,
              result,
              error,
            ),
          );
        case 'retriever.create':
          final native = arena<mp.MpSemanticRetrieverOptions>();
          native.ref
            ..databasePath = string(request['databasePath'] as String?)
            ..embeddingDimension = request['embeddingDimension']! as int
            ..embedder = _handle
            ..textEmbedder = nullptr
            ..imageEmbedder = nullptr
            ..chunkSize = request['chunkSize']! as int
            ..chunkOverlap = request['chunkOverlap']! as int
            ..chunkingMode = ChunkingMode.values
                .byName(request['chunkingMode']! as String)
                .index;
          final output = arena<Pointer<Void>>();
          _check((error) => mp.retrieverCreate(native, output, error));
          if (output.value == nullptr) {
            throw StateError('MediaPipe returned no SemanticRetriever.');
          }
          final id = _nextRetriever++;
          _retrievers[id] = output.value;
          return {'id': id};
      }

      final retriever = _retrievers[request['retriever']];
      if (retriever == null) {
        throw StateError('SemanticRetriever has been closed.');
      }
      final (metadata, metadataCount) = pairs(request['metadata']);
      switch (method) {
        case 'retriever.insertDocument':
          _check(
            (error) => mp.insertDocument(
              retriever,
              string(request['recordId']! as String),
              string(request['text']! as String),
              metadata,
              metadataCount,
              error,
            ),
          );
          return null;
        case 'retriever.insertImage':
          final data = request['imageBytes'] as Uint8List?;
          _check(
            (error) => mp.insertImage(
              retriever,
              string(request['recordId']! as String),
              bytes(data),
              data?.length ?? 0,
              string(
                request['filePath'] as String? ??
                    request['recordId']! as String,
              ),
              metadata,
              metadataCount,
              error,
            ),
          );
          return null;
        case 'retriever.insertAudio':
          final data = request['audioData'] as Float32List?;
          _check(
            (error) => mp.insertAudio(
              retriever,
              string(request['recordId']! as String),
              floats(data),
              data?.length ?? 0,
              string(
                request['audioPath'] as String? ??
                    request['recordId']! as String,
              ),
              metadata,
              metadataCount,
              error,
            ),
          );
          return null;
        case 'retriever.insertContent':
          final list = request['parts']! as List;
          _check(
            (error) => mp.insertContent(
              retriever,
              string(request['recordId']! as String),
              parts(list, request['recordId']! as String),
              list.length,
              metadata,
              metadataCount,
              error,
            ),
          );
          return null;
        case 'retriever.retrieve':
          final list = request['parts']! as List;
          final query = parts(list, 'query');
          final limit = request['limit']! as int;
          final minSimilarity = (request['minSimilarity']! as num).toDouble();
          final (filter, filterCount) = pairs(request['metadataFilter']);
          final result = arena<mp.MpRetrievalResult>();
          if (filterCount == 0) {
            _check(
              (error) => mp.retrieve(
                retriever,
                query,
                list.length,
                limit,
                minSimilarity,
                result,
                error,
              ),
            );
          } else {
            _check(
              (error) => mp.retrieveWithMetadataFilter(
                retriever,
                query,
                list.length,
                limit,
                filter,
                filterCount,
                minSimilarity,
                result,
                error,
              ),
            );
          }
          try {
            return {
              'records': [
                for (var i = 0; i < result.ref.recordsCount; i++)
                  _record(result.ref.records[i]),
              ],
            };
          } finally {
            mp.retrieverCloseResult(result);
          }
        case 'retriever.delete':
          _check(
            (error) => mp.delete(
              retriever,
              string(request['recordId']! as String),
              error,
            ),
          );
          return null;
        case 'retriever.deleteWithMetadataFilter':
          final (filter, filterCount) = pairs(request['metadataFilter']);
          _check(
            (error) => mp.deleteWithMetadataFilter(
              retriever,
              filter,
              filterCount,
              error,
            ),
          );
          return null;
        case 'retriever.deleteAll':
          _check((error) => mp.deleteAll(retriever, error));
          return null;
        case 'retriever.getAllRecordIds':
          final result = arena<mp.MpRecordIdsResult>();
          _check((error) => mp.getAllRecordIds(retriever, result, error));
          try {
            return {
              'ids': [
                for (var i = 0; i < result.ref.idsCount; i++)
                  nativeString(result.ref.ids[i]) ?? '',
              ],
            };
          } finally {
            mp.closeRecordIdsResult(result);
          }
        case 'retriever.close':
          _retrievers.remove(request['retriever']);
          _check((error) => mp.retrieverClose(retriever, error));
          return null;
      }
      throw ArgumentError.value(method, 'method');
    });
  }

  /// Releases the retrievers, then Google's embedder; later calls do nothing.
  @override
  void close() {
    if (_handle == nullptr) return;
    final embedder = _handle;
    _handle = nullptr;
    Object? failure;
    for (final retriever in _retrievers.values) {
      try {
        _check((error) => mp.retrieverClose(retriever, error));
      } catch (error) {
        failure ??= error;
      }
    }
    _retrievers.clear();
    _check((error) => mp.embedderClose(embedder, error));
    if (failure != null) throw failure;
  }
}

/// Runs [call] into a fresh result and copies it out before Google frees it.
Map<String, Object?> _embed(
  Arena arena,
  int Function(Pointer<mp.MpEmbeddingResult>, mp.MpErrorOut) call,
) {
  final result = arena<mp.MpEmbeddingResult>();
  _check((error) => call(result, error));
  try {
    return {
      'embeddings': [
        for (var i = 0; i < result.ref.embeddingsCount; i++)
          _embedding(result.ref.embeddings[i]),
      ],
    };
  } finally {
    mp.embedderCloseResult(result);
  }
}

Map<String, Object?> _embedding(mp.MpEmbedding value) => {
  'floatEmbedding': value.floatEmbedding == nullptr
      ? null
      : Float32List.fromList(
          value.floatEmbedding.asTypedList(value.valuesCount),
        ),
  'quantizedEmbedding': value.quantizedEmbedding == nullptr
      ? null
      : Uint8List.fromList(
          value.quantizedEmbedding.asTypedList(value.valuesCount),
        ),
  'headIndex': value.headIndex,
  'headName': nativeString(value.headName),
};

Map<String, Object?> _record(mp.MpRetrievalRecord record) => {
  'id': nativeString(record.id) ?? '',
  'text': nativeString(record.text) ?? '',
  'score': record.score,
  'metadata': {
    for (var j = 0; j < record.metadataCount; j++)
      nativeString(record.metadata[j].key) ?? '':
          nativeString(record.metadata[j].value) ?? '',
  },
};

/// Frees Google's error string on success and failure alike.
void _check(int Function(Pointer<Pointer<Char>>) call) =>
    checkNativeStatus(call, mp.errorFree);
