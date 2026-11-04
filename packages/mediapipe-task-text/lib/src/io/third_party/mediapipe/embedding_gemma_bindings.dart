// Copyright 2026 The MediaPipe Authors. Licensed under Apache 2.0.
// Adapted from mediapipe==1.0.1 Python ctypes: text/text_embedder.py and
// components/containers/embedding_result_c.py; MpBaseOptions and the embedding
// structs are core's.
// Sizes and field offsets are checked against the pinned official definitions.
// ignore_for_file: public_member_api_docs
import 'dart:ffi';

import 'package:mediapipe_core/native_structs.dart';

export 'package:mediapipe_core/native_structs.dart'
    show MpBaseOptions, MpEmbedding, MpEmbeddingResult;

const _asset = 'package:mediapipe_text/mediapipe.dylib';

final class MpEmbedderOptions extends Struct {
  @Bool()
  external bool l2Normalize;
  @Bool()
  external bool quantize;
}

final class MpTextEmbedderOptions extends Struct {
  external MpBaseOptions baseOptions;
  external MpEmbedderOptions embedderOptions;
}

final class MpTextFormatContext extends Struct {
  @Int32()
  external int taskType;
  external Pointer<Char> title;
  @Int32()
  external int role;
}

@Native<
  Int32 Function(
    Pointer<MpTextEmbedderOptions>,
    Pointer<Pointer<Void>>,
    Pointer<Pointer<Char>>,
  )
>(symbol: 'MpTextEmbedderCreate', assetId: _asset)
external int create(
  Pointer<MpTextEmbedderOptions> options,
  Pointer<Pointer<Void>> task,
  Pointer<Pointer<Char>> error,
);

@Native<
  Int32 Function(
    Pointer<Void>,
    Pointer<Char>,
    Pointer<MpTextFormatContext>,
    Pointer<MpEmbeddingResult>,
    Pointer<Pointer<Char>>,
  )
>(symbol: 'MpTextEmbedderEmbed', assetId: _asset)
external int embed(
  Pointer<Void> task,
  Pointer<Char> text,
  Pointer<MpTextFormatContext> context,
  Pointer<MpEmbeddingResult> result,
  Pointer<Pointer<Char>> error,
);

@Native<Int32 Function(Pointer<Void>, Pointer<Pointer<Char>>)>(
  symbol: 'MpTextEmbedderClose',
  assetId: _asset,
)
external int close(Pointer<Void> task, Pointer<Pointer<Char>> error);

@Native<Void Function(Pointer<MpEmbeddingResult>)>(
  symbol: 'MpTextEmbedderCloseResult',
  assetId: _asset,
)
external void closeResult(Pointer<MpEmbeddingResult> result);

@Native<Void Function(Pointer<Char>)>(symbol: 'MpErrorFree', assetId: _asset)
external void errorFree(Pointer<Char> error);
