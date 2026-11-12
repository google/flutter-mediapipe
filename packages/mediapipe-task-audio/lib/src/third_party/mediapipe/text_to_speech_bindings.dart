// Copyright 2026 The MediaPipe Authors. Licensed under Apache 2.0.
// Adapted from mediapipe==1.2.3 Python ctypes
// audio/text_to_speech.py and the 1.2.3 header
// audio/text_to_speech/text_to_speech.h; the structs every family shares
// are core's native_structs.dart. Every status-returning function takes a
// trailing error-message argument, freed with MpTextToSpeechFreeError.
// ignore_for_file: public_member_api_docs
import 'dart:ffi';

import 'package:mediapipe_core/native_structs.dart';

/// Google's audio library, which the audio hook bundles.
const _asset = 'package:mediapipe_audio/mediapipe.dylib';

/// kMpCancelled: a cancel stopped the synthesis or the read.
const mpCancelled = 1;

/// kMpOutOfRange: the stream has no more chunks.
const mpOutOfRange = 11;

/// 112 bytes.
final class MpTextToSpeechOptions extends Struct {
  external MpBaseOptions baseOptions;

  /// Nullable: the engine's default voice.
  external Pointer<Char> defaultVoiceId;

  /// Nullable: inferred from the voice.
  external Pointer<Char> defaultLocale;

  /// In (0, 4]; 1 is normal speed.
  @Float()
  external double speakingRate;

  /// 0 picks the bucket.
  @Int32()
  external int targetBucket;

  /// Nullable.
  external Pointer<Char> cacheDir;
}

/// 16 bytes.
final class MpTextToSpeechSynthesisOptions extends Struct {
  external Pointer<Char> voiceId;
  external Pointer<Char> locale;
}

/// 32 bytes.
final class MpTextToSpeechVoiceInfo extends Struct {
  external Pointer<Char> voiceId;
  external Pointer<Char> displayName;
  external Pointer<Char> locale;
  @Int32()
  external int sampleRateHz;
  @Bool()
  external bool isDownloaded;
}

/// 16 bytes.
final class MpTextToSpeechVoiceList extends Struct {
  external Pointer<MpTextToSpeechVoiceInfo> voices;
  @Size()
  external int numVoices;
}

/// 24 bytes.
final class MpTextToSpeechWordTimestamp extends Struct {
  external Pointer<Char> word;

  /// UTF-8 byte offsets in the input text, the end exclusive.
  @Int32()
  external int startChar;
  @Int32()
  external int endChar;
  @Float()
  external double startSec;
  @Float()
  external double endSec;
}

/// 40 bytes.
final class MpTextToSpeechAudioResult extends Struct {
  external Pointer<Float> samples;
  @Size()
  external int numSamples;
  @Int32()
  external int sampleRateHz;
  external Pointer<MpTextToSpeechWordTimestamp> wordTimestamps;
  @Size()
  external int numWordTimestamps;
}

@Native<
  Int32 Function(
    Pointer<MpTextToSpeechOptions>,
    Pointer<Pointer<Void>>,
    Pointer<Pointer<Char>>,
  )
>(symbol: 'MpTextToSpeechCreate', assetId: _asset)
external int create(
  Pointer<MpTextToSpeechOptions> options,
  Pointer<Pointer<Void>> tts,
  Pointer<Pointer<Char>> error,
);

@Native<
  Int32 Function(
    Pointer<Void>,
    Pointer<MpTextToSpeechVoiceList>,
    Pointer<Pointer<Char>>,
  )
>(symbol: 'MpTextToSpeechListVoices', assetId: _asset)
external int listVoices(
  Pointer<Void> tts,
  Pointer<MpTextToSpeechVoiceList> voices,
  Pointer<Pointer<Char>> error,
);

@Native<Void Function(Pointer<MpTextToSpeechVoiceList>)>(
  symbol: 'MpTextToSpeechVoiceListFree',
  assetId: _asset,
)
external void voiceListFree(Pointer<MpTextToSpeechVoiceList> voices);

@Native<
  Int32 Function(
    Pointer<Void>,
    Pointer<Char>,
    Pointer<MpTextToSpeechSynthesisOptions>,
    Pointer<MpTextToSpeechAudioResult>,
    Pointer<Pointer<Char>>,
  )
>(symbol: 'MpTextToSpeechSynthesize', assetId: _asset)
external int synthesize(
  Pointer<Void> tts,
  Pointer<Char> text,
  Pointer<MpTextToSpeechSynthesisOptions> options,
  Pointer<MpTextToSpeechAudioResult> result,
  Pointer<Pointer<Char>> error,
);

@Native<Void Function(Pointer<MpTextToSpeechAudioResult>)>(
  symbol: 'MpTextToSpeechFreeAudioResult',
  assetId: _asset,
)
external void freeAudioResult(Pointer<MpTextToSpeechAudioResult> result);

@Native<
  Int32 Function(
    Pointer<Void>,
    Pointer<Char>,
    Pointer<MpTextToSpeechSynthesisOptions>,
    Bool,
    Pointer<Pointer<Void>>,
    Pointer<Pointer<Char>>,
  )
>(symbol: 'MpTextToSpeechStartStream', assetId: _asset)
external int startStream(
  Pointer<Void> tts,
  Pointer<Char> initialText,
  Pointer<MpTextToSpeechSynthesisOptions> options,
  bool finishInput,
  Pointer<Pointer<Void>> stream,
  Pointer<Pointer<Char>> error,
);

@Native<
  Int32 Function(
    Pointer<Void>,
    Pointer<MpTextToSpeechAudioResult>,
    Pointer<Int32>,
    Pointer<Bool>,
    Pointer<Pointer<Char>>,
  )
>(symbol: 'MpTextToSpeechStreamReadNext', assetId: _asset)
external int streamReadNext(
  Pointer<Void> stream,
  Pointer<MpTextToSpeechAudioResult> chunk,
  Pointer<Int32> chunkIndex,
  Pointer<Bool> isFinal,
  Pointer<Pointer<Char>> error,
);

/// Lock-free; safe from any thread while a read blocks on another.
@Native<Void Function(Pointer<Void>)>(
  symbol: 'MpTextToSpeechStreamCancel',
  assetId: _asset,
)
external void streamCancel(Pointer<Void> stream);

@Native<Void Function(Pointer<Void>)>(
  symbol: 'MpTextToSpeechStreamClose',
  assetId: _asset,
)
external void streamClose(Pointer<Void> stream);

/// Lock-free; safe from any thread while a synthesis or a read blocks on
/// another.
@Native<Void Function(Pointer<Void>)>(
  symbol: 'MpTextToSpeechCancel',
  assetId: _asset,
)
external void cancel(Pointer<Void> tts);

@Native<Void Function(Pointer<Void>)>(
  symbol: 'MpTextToSpeechClose',
  assetId: _asset,
)
external void close(Pointer<Void> tts);

@Native<Void Function(Pointer<Char>)>(
  symbol: 'MpTextToSpeechFreeError',
  assetId: _asset,
)
external void freeError(Pointer<Char> error);
