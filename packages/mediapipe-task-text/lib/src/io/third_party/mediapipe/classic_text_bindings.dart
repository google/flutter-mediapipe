// Copyright 2026 The MediaPipe Authors. Licensed under Apache 2.0.
// Adapted from mediapipe==1.0.1 Python ctypes text_classifier.py and
// language_detector.py; the classification structs are core's.
// ignore_for_file: public_member_api_docs
import 'dart:ffi';

import 'package:mediapipe_core/native_structs.dart';

export 'package:mediapipe_core/native_structs.dart';
export 'embedding_gemma_bindings.dart' show errorFree;

const _asset = 'package:mediapipe_text/mediapipe.dylib';

/// Identical layout for TextClassifierOptions and LanguageDetectorOptions.
final class MpTextClassifierOptions extends Struct {
  external MpBaseOptions baseOptions;
  external MpClassifierOptions classifierOptions;
}

final class MpLanguagePrediction extends Struct {
  external Pointer<Char> languageCode;
  @Float()
  external double probability;
}

final class MpLanguageDetectorResult extends Struct {
  external Pointer<MpLanguagePrediction> predictions;
  @Uint32()
  external int predictionsCount;
}

@Native<
  Int32 Function(
    Pointer<MpTextClassifierOptions>,
    Pointer<Pointer<Void>>,
    Pointer<Pointer<Char>>,
  )
>(symbol: 'MpTextClassifierCreate', assetId: _asset)
external int classifierCreate(
  Pointer<MpTextClassifierOptions> options,
  Pointer<Pointer<Void>> task,
  Pointer<Pointer<Char>> error,
);

@Native<
  Int32 Function(
    Pointer<Void>,
    Pointer<Char>,
    Pointer<MpClassificationResult>,
    Pointer<Pointer<Char>>,
  )
>(symbol: 'MpTextClassifierClassify', assetId: _asset)
external int classifierRun(
  Pointer<Void> task,
  Pointer<Char> text,
  Pointer<MpClassificationResult> result,
  Pointer<Pointer<Char>> error,
);

@Native<Int32 Function(Pointer<Void>, Pointer<Pointer<Char>>)>(
  symbol: 'MpTextClassifierClose',
  assetId: _asset,
)
external int classifierClose(Pointer<Void> task, Pointer<Pointer<Char>> error);

@Native<Void Function(Pointer<MpClassificationResult>)>(
  symbol: 'MpTextClassifierCloseResult',
  assetId: _asset,
)
external void classifierCloseResult(Pointer<MpClassificationResult> result);

@Native<
  Int32 Function(
    Pointer<MpTextClassifierOptions>,
    Pointer<Pointer<Void>>,
    Pointer<Pointer<Char>>,
  )
>(symbol: 'MpLanguageDetectorCreate', assetId: _asset)
external int languageCreate(
  Pointer<MpTextClassifierOptions> options,
  Pointer<Pointer<Void>> task,
  Pointer<Pointer<Char>> error,
);

@Native<
  Int32 Function(
    Pointer<Void>,
    Pointer<Char>,
    Pointer<MpLanguageDetectorResult>,
    Pointer<Pointer<Char>>,
  )
>(symbol: 'MpLanguageDetectorDetect', assetId: _asset)
external int languageRun(
  Pointer<Void> task,
  Pointer<Char> text,
  Pointer<MpLanguageDetectorResult> result,
  Pointer<Pointer<Char>> error,
);

@Native<Int32 Function(Pointer<Void>, Pointer<Pointer<Char>>)>(
  symbol: 'MpLanguageDetectorClose',
  assetId: _asset,
)
external int languageClose(Pointer<Void> task, Pointer<Pointer<Char>> error);

@Native<Void Function(Pointer<MpLanguageDetectorResult>)>(
  symbol: 'MpLanguageDetectorCloseResult',
  assetId: _asset,
)
external void languageCloseResult(Pointer<MpLanguageDetectorResult> result);
