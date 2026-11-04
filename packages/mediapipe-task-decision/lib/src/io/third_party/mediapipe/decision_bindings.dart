// Copyright 2026 The MediaPipe Authors. Licensed under Apache 2.0.
// Adapted from mediapipe==1.1.0 Python ctypes decision/decision_maker.py,
// and matching Google's C header, decision/decision_maker/decision_maker.h in
// packages/mediapipe-core/native/include. Every function returns an MpStatus
// and takes the error string last, as Google's
// mediapipe_c_utils.CStatusFunction does.
// ignore_for_file: public_member_api_docs
import 'dart:ffi';

import 'package:mediapipe_core/native_structs.dart';

export 'package:mediapipe_core/native_structs.dart';

const _asset = 'package:mediapipe_decision/mediapipe.dylib';

final class MpBooleanQuestion extends Struct {
  external Pointer<Char> condition;
  @Float()
  external double threshold;
  @Float()
  external double temperature;
  @Bool()
  external bool normalizePrior;
}

final class MpChoiceQuestion extends Struct {
  external Pointer<Pointer<Char>> keys;
  external Pointer<Pointer<Char>> descriptions;
  @Int32()
  external int count;
  @Float()
  external double temperature;
  external Pointer<Char> instructions;
  @Int32()
  external int scoringMode;
  @Bool()
  external bool normalizePrior;
  // Multimodal options, which this package leaves null.
  external Pointer<Pointer<Uint8>> imageBytes;
  external Pointer<Int32> imageBytesLengths;
  external Pointer<Pointer<Float>> audioSamples;
  external Pointer<Int32> audioSamplesLengths;
}

final class MpScoreQuestion extends Struct {
  external Pointer<Pointer<Char>> rubric;
  @Int32()
  external int count;
  @Float()
  external double temperature;
  external Pointer<Char> instructions;
}

final class MpBooleanResult extends Struct {
  @Bool()
  external bool value;
  @Float()
  external double probabilityTrue;
  @Float()
  external double confidence;
}

final class MpChoiceResult extends Struct {
  external Pointer<Char> selectedKey;
  external Pointer<Pointer<Char>> keys;
  external Pointer<Float> probabilities;
  @Int32()
  external int count;
  @Float()
  external double confidence;
}

final class MpScoreResult extends Struct {
  external Pointer<Char> selectedKey;
  @Float()
  external double expectedScore;
  external Pointer<Float> probabilities;
  @Int32()
  external int count;
  @Float()
  external double confidence;
}

final class MpDecisionMakerOptions extends Struct {
  external MpBaseOptions baseOptions;
  @Int32()
  external int maxNumTokens;
}

/// Google's error string, which the caller frees with [errorFree].
typedef MpErrorOut = Pointer<Pointer<Char>>;

@Native<
  Int32 Function(
    Pointer<MpDecisionMakerOptions>,
    Pointer<Pointer<Void>>,
    MpErrorOut,
  )
>(symbol: 'MpDecisionMakerCreate', assetId: _asset)
external int create(
  Pointer<MpDecisionMakerOptions> options,
  Pointer<Pointer<Void>> task,
  MpErrorOut error,
);

@Native<
  Int32 Function(
    Pointer<Void>,
    Pointer<Char>,
    Pointer<MpBooleanQuestion>,
    Pointer<MpBooleanResult>,
    MpErrorOut,
  )
>(symbol: 'MpDecisionMakerEvaluateBoolean', assetId: _asset)
external int evaluateBoolean(
  Pointer<Void> task,
  Pointer<Char> text,
  Pointer<MpBooleanQuestion> question,
  Pointer<MpBooleanResult> result,
  MpErrorOut error,
);

@Native<
  Int32 Function(
    Pointer<Void>,
    Pointer<Char>,
    Pointer<MpChoiceQuestion>,
    Pointer<MpChoiceResult>,
    MpErrorOut,
  )
>(symbol: 'MpDecisionMakerEvaluateChoice', assetId: _asset)
external int evaluateChoice(
  Pointer<Void> task,
  Pointer<Char> text,
  Pointer<MpChoiceQuestion> question,
  Pointer<MpChoiceResult> result,
  MpErrorOut error,
);

@Native<
  Int32 Function(
    Pointer<Void>,
    Pointer<Char>,
    Pointer<MpScoreQuestion>,
    Pointer<MpScoreResult>,
    MpErrorOut,
  )
>(symbol: 'MpDecisionMakerEvaluateScore', assetId: _asset)
external int evaluateScore(
  Pointer<Void> task,
  Pointer<Char> text,
  Pointer<MpScoreQuestion> question,
  Pointer<MpScoreResult> result,
  MpErrorOut error,
);

@Native<
  Int32 Function(
    Pointer<Void>,
    Pointer<Char>,
    Pointer<Pointer<Char>>,
    Int32,
    Pointer<MpBooleanQuestion>,
    Pointer<MpBooleanResult>,
    MpErrorOut,
  )
>(symbol: 'MpDecisionMakerEvaluateBooleanBatch', assetId: _asset)
external int evaluateBooleanBatch(
  Pointer<Void> task,
  Pointer<Char> sharedPrefix,
  Pointer<Pointer<Char>> texts,
  int count,
  Pointer<MpBooleanQuestion> question,
  Pointer<MpBooleanResult> results,
  MpErrorOut error,
);

@Native<
  Int32 Function(
    Pointer<Void>,
    Pointer<Char>,
    Pointer<Pointer<Char>>,
    Int32,
    Pointer<MpChoiceQuestion>,
    Pointer<MpChoiceResult>,
    MpErrorOut,
  )
>(symbol: 'MpDecisionMakerEvaluateChoiceBatch', assetId: _asset)
external int evaluateChoiceBatch(
  Pointer<Void> task,
  Pointer<Char> sharedPrefix,
  Pointer<Pointer<Char>> texts,
  int count,
  Pointer<MpChoiceQuestion> question,
  Pointer<MpChoiceResult> results,
  MpErrorOut error,
);

@Native<
  Int32 Function(
    Pointer<Void>,
    Pointer<Char>,
    Pointer<Pointer<Char>>,
    Int32,
    Pointer<MpScoreQuestion>,
    Pointer<MpScoreResult>,
    MpErrorOut,
  )
>(symbol: 'MpDecisionMakerEvaluateScoreBatch', assetId: _asset)
external int evaluateScoreBatch(
  Pointer<Void> task,
  Pointer<Char> sharedPrefix,
  Pointer<Pointer<Char>> texts,
  int count,
  Pointer<MpScoreQuestion> question,
  Pointer<MpScoreResult> results,
  MpErrorOut error,
);

@Native<Void Function(Pointer<MpChoiceResult>)>(
  symbol: 'MpDecisionMakerCloseChoiceResult',
  assetId: _asset,
)
external void closeChoiceResult(Pointer<MpChoiceResult> result);

@Native<Void Function(Pointer<MpChoiceResult>, Int32)>(
  symbol: 'MpDecisionMakerCloseChoiceResultBatch',
  assetId: _asset,
)
external void closeChoiceResultBatch(
  Pointer<MpChoiceResult> results,
  int count,
);

@Native<Void Function(Pointer<MpScoreResult>)>(
  symbol: 'MpDecisionMakerCloseScoreResult',
  assetId: _asset,
)
external void closeScoreResult(Pointer<MpScoreResult> result);

@Native<Void Function(Pointer<MpScoreResult>, Int32)>(
  symbol: 'MpDecisionMakerCloseScoreResultBatch',
  assetId: _asset,
)
external void closeScoreResultBatch(Pointer<MpScoreResult> results, int count);

@Native<Int32 Function(Pointer<Void>, MpErrorOut)>(
  symbol: 'MpDecisionMakerClose',
  assetId: _asset,
)
external int close(Pointer<Void> task, MpErrorOut error);

@Native<Void Function(Pointer<Char>)>(symbol: 'MpErrorFree', assetId: _asset)
external void errorFree(Pointer<Char> error);
