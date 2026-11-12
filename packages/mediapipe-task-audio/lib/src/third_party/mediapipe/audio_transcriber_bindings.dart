// Copyright 2026 The MediaPipe Authors. Licensed under Apache 2.0.
// Adapted from mediapipe==1.2.3 Python ctypes
// audio/audio_transcriber.py and the 1.2.3 header
// audio/audio_transcriber/audio_transcriber.h; the structs every family
// shares are core's native_structs.dart. Every status-returning function
// takes a trailing error-message argument, freed with MpErrorFree.
// ignore_for_file: public_member_api_docs
import 'dart:ffi';

import 'package:mediapipe_core/native_structs.dart';

/// Google's audio library, which the audio hook bundles.
const _asset = 'package:mediapipe_audio/mediapipe.dylib';

/// 112 bytes.
final class MpAudioTranscriberOptions extends Struct {
  external MpBaseOptions baseOptions;

  /// 16000 when 0.
  @Int32()
  external int sampleRateHz;

  @Bool()
  external bool enableInterimResults;

  /// MpAudioTranscriberModelArchitecture: 0 auto, 1 omni.
  @Int32()
  external int modelArchitecture;

  /// Nullable.
  external Pointer<Char> prompt;

  /// Nullable.
  external Pointer<Char> cacheDir;
}

/// 32 bytes.
final class MpTranscriptionSegment extends Struct {
  external Pointer<Char> transcript;
  @Bool()
  external bool isFinal;
  @Int64()
  external int fromTimestampMs;
  @Int64()
  external int toTimestampMs;
}

/// 16 bytes.
final class MpAudioTranscriberResult extends Struct {
  external Pointer<MpTranscriptionSegment> segments;
  @Uint32()
  external int segmentsCount;
}

@Native<
  Int32 Function(
    Pointer<MpAudioTranscriberOptions>,
    Pointer<Pointer<Void>>,
    Pointer<Pointer<Char>>,
  )
>(symbol: 'MpAudioTranscriberCreate', assetId: _asset)
external int create(
  Pointer<MpAudioTranscriberOptions> options,
  Pointer<Pointer<Void>> transcriber,
  Pointer<Pointer<Char>> error,
);

@Native<
  Int32 Function(
    Pointer<Void>,
    Pointer<Float>,
    Size,
    Bool,
    Pointer<MpAudioTranscriberResult>,
    Pointer<Pointer<Char>>,
  )
>(symbol: 'MpAudioTranscriberTranscribe', assetId: _asset)
external int transcribe(
  Pointer<Void> transcriber,
  Pointer<Float> samples,
  int sampleCount,
  bool endOfStream,
  Pointer<MpAudioTranscriberResult> result,
  Pointer<Pointer<Char>> error,
);

@Native<
  Int32 Function(
    Pointer<Void>,
    Pointer<MpAudioTranscriberResult>,
    Pointer<Pointer<Char>>,
  )
>(symbol: 'MpAudioTranscriberFinishStream', assetId: _asset)
external int finishStream(
  Pointer<Void> transcriber,
  Pointer<MpAudioTranscriberResult> result,
  Pointer<Pointer<Char>> error,
);

@Native<Int32 Function(Pointer<Void>, Pointer<Pointer<Char>>)>(
  symbol: 'MpAudioTranscriberPrewarm',
  assetId: _asset,
)
external int prewarm(Pointer<Void> transcriber, Pointer<Pointer<Char>> error);

@Native<Void Function(Pointer<MpAudioTranscriberResult>)>(
  symbol: 'MpAudioTranscriberCloseResult',
  assetId: _asset,
)
external void closeResult(Pointer<MpAudioTranscriberResult> result);

@Native<Int32 Function(Pointer<Void>, Pointer<Pointer<Char>>)>(
  symbol: 'MpAudioTranscriberClose',
  assetId: _asset,
)
external int close(Pointer<Void> transcriber, Pointer<Pointer<Char>> error);
