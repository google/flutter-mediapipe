// Internal cancel-guard ABI (native/text_to_speech_guard.h); no MediaPipe
// inference code.
// ignore_for_file: public_member_api_docs
import 'dart:ffi';

const _bridge = 'package:mediapipe_audio/audio_stream_bridge.dylib';

/// Takes MpTextToSpeechCancel and MpTextToSpeechStreamCancel; null when out
/// of memory.
@Native<Pointer<Void> Function(Pointer<Void>, Pointer<Void>)>(
  symbol: 'MpFlutterTtsGuardNew',
  assetId: _bridge,
)
external Pointer<Void> guardNew(
  Pointer<Void> cancel,
  Pointer<Void> streamCancel,
);

@Native<Void Function(Pointer<Void>)>(
  symbol: 'MpFlutterTtsGuardFree',
  assetId: _bridge,
)
external void guardFree(Pointer<Void> guard);

@Native<Bool Function(Pointer<Void>, Int64, Pointer<Void>)>(
  symbol: 'MpFlutterTtsGuardBegin',
  assetId: _bridge,
)
external bool guardBegin(Pointer<Void> guard, int request, Pointer<Void> tts);

@Native<Void Function(Pointer<Void>, Pointer<Void>)>(
  symbol: 'MpFlutterTtsGuardSetStream',
  assetId: _bridge,
)
external void guardSetStream(Pointer<Void> guard, Pointer<Void> stream);

@Native<Bool Function(Pointer<Void>)>(
  symbol: 'MpFlutterTtsGuardEnd',
  assetId: _bridge,
)
external bool guardEnd(Pointer<Void> guard);

@Native<Void Function(Pointer<Void>, Int64)>(
  symbol: 'MpFlutterTtsGuardCancel',
  assetId: _bridge,
)
external void guardCancel(Pointer<Void> guard, int through);

@Native<Void Function(Pointer<Void>, Int64)>(
  symbol: 'MpFlutterTtsGuardCancelStream',
  assetId: _bridge,
)
external void guardCancelStream(Pointer<Void> guard, int request);
