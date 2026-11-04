// Copyright 2026 The MediaPipe Authors. Licensed under Apache 2.0.
// Adapted from MediaPipe 1.1.0's C headers
// mediapipe/tasks/c/retrieval/universal_embedder/universal_embedder.h and
// mediapipe/tasks/c/retrieval/semantic_retriever/semantic_retriever.h, which
// Google's Python ctypes retrieval/universal_embedder.py and
// retrieval/semantic_retriever.py mirror. MpBaseOptions and the embedding
// structs are core's. Every status function returns an MpStatus and takes the
// error string last, as Google's mediapipe_c_utils.CStatusFunction does.
// ignore_for_file: public_member_api_docs
import 'dart:ffi';

import 'package:mediapipe_core/native_structs.dart';

export 'package:mediapipe_core/native_structs.dart'
    show MpBaseOptions, MpEmbedding, MpEmbeddingResult;

const _asset = 'package:mediapipe_retrieval/mediapipe.dylib';

final class MpUniversalEmbedderOptions extends Struct {
  external MpBaseOptions baseOptions;
  @Bool()
  external bool l2Normalize;
  @Int32()
  external int maxInputLength;
  @Int32()
  external int visionTokensPerImage;
  @Int32()
  external int activationDataType;
  external Pointer<Char> cacheDir;
}

final class MpKeyValuePair extends Struct {
  external Pointer<Char> key;
  external Pointer<Char> value;
}

final class MpRetrievalRecord extends Struct {
  external Pointer<Char> id;
  external Pointer<Char> text;
  @Float()
  external double score;
  external Pointer<MpKeyValuePair> metadata;
  @Int32()
  external int metadataCount;
}

final class MpRetrievalResult extends Struct {
  external Pointer<MpRetrievalRecord> records;
  @Uint32()
  external int recordsCount;
}

final class MpTextPart extends Struct {
  external Pointer<Char> text;
}

final class MpImagePart extends Struct {
  external Pointer<Uint8> imageBytes;
  @Int32()
  external int imageBytesSize;
  external Pointer<Char> filePath;
}

final class MpAudioPart extends Struct {
  external Pointer<Float> audioData;
  @Int32()
  external int audioDataSize;
  external Pointer<Char> audioPath;
}

/// `MpTaskPart`: one part of a record or query; [kind] is 0 for text, 1 for
/// an image and 2 for audio (`MpTaskPartKind`).
final class MpTaskPart extends Struct {
  @Int32()
  external int kind;
  external MpTextPart textPart;
  external MpImagePart imagePart;
  external MpAudioPart audioPart;
}

final class MpSemanticRetrieverOptions extends Struct {
  external Pointer<Char> databasePath;
  @Int32()
  external int embeddingDimension;
  external Pointer<Void> embedder;
  external Pointer<Void> textEmbedder;
  external Pointer<Void> imageEmbedder;
  @Int32()
  external int chunkSize;
  @Int32()
  external int chunkOverlap;
  @Int32()
  external int chunkingMode;
}

final class MpRecordIdsResult extends Struct {
  external Pointer<Pointer<Char>> ids;
  @Uint32()
  external int idsCount;
}

/// Google's error string, which the caller frees with [errorFree].
typedef MpErrorOut = Pointer<Pointer<Char>>;

@Native<
  Int32 Function(
    Pointer<MpUniversalEmbedderOptions>,
    Pointer<Pointer<Void>>,
    MpErrorOut,
  )
>(symbol: 'MpUniversalEmbedderCreate', assetId: _asset)
external int embedderCreate(
  Pointer<MpUniversalEmbedderOptions> options,
  Pointer<Pointer<Void>> embedder,
  MpErrorOut error,
);

@Native<
  Int32 Function(
    Pointer<Void>,
    Pointer<Char>,
    Pointer<MpEmbeddingResult>,
    MpErrorOut,
  )
>(symbol: 'MpUniversalEmbedderEmbedText', assetId: _asset)
external int embedText(
  Pointer<Void> embedder,
  Pointer<Char> text,
  Pointer<MpEmbeddingResult> result,
  MpErrorOut error,
);

@Native<
  Int32 Function(
    Pointer<Void>,
    Pointer<Char>,
    Int32,
    Pointer<MpEmbeddingResult>,
    MpErrorOut,
  )
>(symbol: 'MpUniversalEmbedderEmbedImage', assetId: _asset)
external int embedImage(
  Pointer<Void> embedder,
  Pointer<Char> imageBytes,
  int imageBytesSize,
  Pointer<MpEmbeddingResult> result,
  MpErrorOut error,
);

@Native<
  Int32 Function(
    Pointer<Void>,
    Pointer<Float>,
    Int32,
    Pointer<MpEmbeddingResult>,
    MpErrorOut,
  )
>(symbol: 'MpUniversalEmbedderEmbedAudio', assetId: _asset)
external int embedAudio(
  Pointer<Void> embedder,
  Pointer<Float> audioData,
  int audioDataSize,
  Pointer<MpEmbeddingResult> result,
  MpErrorOut error,
);

@Native<Void Function(Pointer<MpEmbeddingResult>)>(
  symbol: 'MpUniversalEmbedderCloseResult',
  assetId: _asset,
)
external void embedderCloseResult(Pointer<MpEmbeddingResult> result);

@Native<Int32 Function(Pointer<Void>, MpErrorOut)>(
  symbol: 'MpUniversalEmbedderClose',
  assetId: _asset,
)
external int embedderClose(Pointer<Void> embedder, MpErrorOut error);

@Native<
  Int32 Function(
    Pointer<MpSemanticRetrieverOptions>,
    Pointer<Pointer<Void>>,
    MpErrorOut,
  )
>(symbol: 'MpSemanticRetrieverCreate', assetId: _asset)
external int retrieverCreate(
  Pointer<MpSemanticRetrieverOptions> options,
  Pointer<Pointer<Void>> retriever,
  MpErrorOut error,
);

@Native<
  Int32 Function(
    Pointer<Void>,
    Pointer<Char>,
    Pointer<Char>,
    Pointer<MpKeyValuePair>,
    Int32,
    MpErrorOut,
  )
>(symbol: 'MpSemanticRetrieverInsertDocument', assetId: _asset)
external int insertDocument(
  Pointer<Void> retriever,
  Pointer<Char> id,
  Pointer<Char> text,
  Pointer<MpKeyValuePair> metadata,
  int metadataCount,
  MpErrorOut error,
);

@Native<
  Int32 Function(
    Pointer<Void>,
    Pointer<Char>,
    Pointer<Uint8>,
    Int32,
    Pointer<Char>,
    Pointer<MpKeyValuePair>,
    Int32,
    MpErrorOut,
  )
>(symbol: 'MpSemanticRetrieverInsertImage', assetId: _asset)
external int insertImage(
  Pointer<Void> retriever,
  Pointer<Char> id,
  Pointer<Uint8> imageBytes,
  int imageBytesSize,
  Pointer<Char> filePath,
  Pointer<MpKeyValuePair> metadata,
  int metadataCount,
  MpErrorOut error,
);

@Native<
  Int32 Function(
    Pointer<Void>,
    Pointer<Char>,
    Pointer<Float>,
    Int32,
    Pointer<Char>,
    Pointer<MpKeyValuePair>,
    Int32,
    MpErrorOut,
  )
>(symbol: 'MpSemanticRetrieverInsertAudio', assetId: _asset)
external int insertAudio(
  Pointer<Void> retriever,
  Pointer<Char> id,
  Pointer<Float> audioData,
  int audioDataSize,
  Pointer<Char> audioPath,
  Pointer<MpKeyValuePair> metadata,
  int metadataCount,
  MpErrorOut error,
);

@Native<
  Int32 Function(
    Pointer<Void>,
    Pointer<Char>,
    Pointer<MpTaskPart>,
    Int32,
    Pointer<MpKeyValuePair>,
    Int32,
    MpErrorOut,
  )
>(symbol: 'MpSemanticRetrieverInsertContent', assetId: _asset)
external int insertContent(
  Pointer<Void> retriever,
  Pointer<Char> id,
  Pointer<MpTaskPart> parts,
  int partsCount,
  Pointer<MpKeyValuePair> metadata,
  int metadataCount,
  MpErrorOut error,
);

@Native<
  Int32 Function(
    Pointer<Void>,
    Pointer<MpTaskPart>,
    Int32,
    Int32,
    Float,
    Pointer<MpRetrievalResult>,
    MpErrorOut,
  )
>(symbol: 'MpSemanticRetrieverRetrieve', assetId: _asset)
external int retrieve(
  Pointer<Void> retriever,
  Pointer<MpTaskPart> parts,
  int partsCount,
  int limit,
  double minSimilarity,
  Pointer<MpRetrievalResult> result,
  MpErrorOut error,
);

@Native<
  Int32 Function(
    Pointer<Void>,
    Pointer<MpTaskPart>,
    Int32,
    Int32,
    Pointer<MpKeyValuePair>,
    Int32,
    Float,
    Pointer<MpRetrievalResult>,
    MpErrorOut,
  )
>(symbol: 'MpSemanticRetrieverRetrieveWithMetadataFilter', assetId: _asset)
external int retrieveWithMetadataFilter(
  Pointer<Void> retriever,
  Pointer<MpTaskPart> parts,
  int partsCount,
  int limit,
  Pointer<MpKeyValuePair> metadataFilter,
  int metadataFilterCount,
  double minSimilarity,
  Pointer<MpRetrievalResult> result,
  MpErrorOut error,
);

@Native<Int32 Function(Pointer<Void>, Pointer<Char>, MpErrorOut)>(
  symbol: 'MpSemanticRetrieverDelete',
  assetId: _asset,
)
external int delete(
  Pointer<Void> retriever,
  Pointer<Char> id,
  MpErrorOut error,
);

@Native<
  Int32 Function(Pointer<Void>, Pointer<MpKeyValuePair>, Int32, MpErrorOut)
>(symbol: 'MpSemanticRetrieverDeleteWithMetadataFilter', assetId: _asset)
external int deleteWithMetadataFilter(
  Pointer<Void> retriever,
  Pointer<MpKeyValuePair> metadataFilter,
  int metadataFilterCount,
  MpErrorOut error,
);

@Native<Int32 Function(Pointer<Void>, Pointer<MpRecordIdsResult>, MpErrorOut)>(
  symbol: 'MpSemanticRetrieverGetAllRecordIds',
  assetId: _asset,
)
external int getAllRecordIds(
  Pointer<Void> retriever,
  Pointer<MpRecordIdsResult> result,
  MpErrorOut error,
);

@Native<Void Function(Pointer<MpRecordIdsResult>)>(
  symbol: 'MpSemanticRetrieverCloseRecordIdsResult',
  assetId: _asset,
)
external void closeRecordIdsResult(Pointer<MpRecordIdsResult> result);

@Native<Int32 Function(Pointer<Void>, MpErrorOut)>(
  symbol: 'MpSemanticRetrieverDeleteAll',
  assetId: _asset,
)
external int deleteAll(Pointer<Void> retriever, MpErrorOut error);

@Native<Void Function(Pointer<MpRetrievalResult>)>(
  symbol: 'MpSemanticRetrieverCloseResult',
  assetId: _asset,
)
external void retrieverCloseResult(Pointer<MpRetrievalResult> result);

@Native<Int32 Function(Pointer<Void>, MpErrorOut)>(
  symbol: 'MpSemanticRetrieverClose',
  assetId: _asset,
)
external int retrieverClose(Pointer<Void> retriever, MpErrorOut error);

@Native<Void Function(Pointer<Char>)>(symbol: 'MpErrorFree', assetId: _asset)
external void errorFree(Pointer<Char> error);
