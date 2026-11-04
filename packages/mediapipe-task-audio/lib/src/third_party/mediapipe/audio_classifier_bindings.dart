// Copyright 2026 The MediaPipe Authors. Licensed under Apache 2.0.
// Adapted from mediapipe==1.0.1 Python ctypes audio/audio_classifier.py and
// components/containers/audio_data_c.py; the structs every family shares are
// core's native_structs.dart. Every status-returning function takes a
// trailing error-message argument.
// ignore_for_file: public_member_api_docs
import 'dart:ffi';

import 'package:mediapipe_core/native_structs.dart';

export 'package:mediapipe_core/native_structs.dart';

/// Google's audio library, which the audio hook bundles.
const _asset = 'package:mediapipe_audio/mediapipe.dylib';

final class MpAudioClassifierOptions extends Struct {
  external MpBaseOptions baseOptions;
  external MpClassifierOptions classifierOptions;

  /// 1 for audio clips, 2 for an audio stream.
  @Int32()
  external int runningMode;

  /// Only used in stream mode.
  external Pointer<Void> resultCallback;
}

final class MpAudioData extends Struct {
  @Int32()
  external int numChannels;
  @Double()
  external double sampleRate;

  /// Interleaved frames: frame 0's channels, then frame 1's, and so on.
  external Pointer<Float> audioData;

  /// Every float, frames times channels.
  @Size()
  external int audioDataSize;
}

/// One classification result per chunk of the clip.
final class MpAudioClassifierResult extends Struct {
  external Pointer<MpClassificationResult> results;
  @Int32()
  external int resultsCount;
}

@Native<
  Int32 Function(
    Pointer<MpAudioClassifierOptions>,
    Pointer<Pointer<Void>>,
    Pointer<Pointer<Char>>,
  )
>(symbol: 'MpAudioClassifierCreate', assetId: _asset)
external int create(
  Pointer<MpAudioClassifierOptions> options,
  Pointer<Pointer<Void>> task,
  Pointer<Pointer<Char>> error,
);

@Native<
  Int32 Function(
    Pointer<Void>,
    Pointer<MpAudioData>,
    Pointer<MpAudioClassifierResult>,
    Pointer<Pointer<Char>>,
  )
>(symbol: 'MpAudioClassifierClassify', assetId: _asset)
external int classify(
  Pointer<Void> task,
  Pointer<MpAudioData> audio,
  Pointer<MpAudioClassifierResult> result,
  Pointer<Pointer<Char>> error,
);

/// Hands one block to a task in stream mode; Google copies the samples.
@Native<
  Int32 Function(
    Pointer<Void>,
    Pointer<MpAudioData>,
    Int64,
    Pointer<Pointer<Char>>,
  )
>(symbol: 'MpAudioClassifierClassifyAsync', assetId: _asset)
external int classifyAsync(
  Pointer<Void> task,
  Pointer<MpAudioData> audio,
  int timestampMs,
  Pointer<Pointer<Char>> error,
);

@Native<Void Function(Pointer<MpAudioClassifierResult>)>(
  symbol: 'MpAudioClassifierCloseResult',
  assetId: _asset,
)
external void closeResult(Pointer<MpAudioClassifierResult> result);

@Native<Int32 Function(Pointer<Void>, Pointer<Pointer<Char>>)>(
  symbol: 'MpAudioClassifierClose',
  assetId: _asset,
)
external int close(Pointer<Void> task, Pointer<Pointer<Char>> error);

@Native<Void Function(Pointer<Char>)>(symbol: 'MpErrorFree', assetId: _asset)
external void errorFree(Pointer<Char> error);
