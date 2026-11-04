// Internal callback-copy adapter ABI (native/audio_stream_bridge.h); no
// MediaPipe inference code.
// ignore_for_file: public_member_api_docs
import 'dart:ffi';

const _bridge = 'package:mediapipe_audio/audio_stream_bridge.dylib';

/// How many audio streams may be open at once (MP_FLUTTER_AUDIO_STREAM_SLOTS).
const streamSlots = 64;

final class MpFlutterAudioCategory extends Struct {
  @Int32()
  external int index;
  @Float()
  external double score;
  external Pointer<Char> categoryName;
  external Pointer<Char> displayName;
}

final class MpFlutterAudioHead extends Struct {
  external Pointer<MpFlutterAudioCategory> categories;
  @Int32()
  external int categoriesCount;
  @Int32()
  external int headIndex;
  external Pointer<Char> headName;
}

final class MpFlutterAudioEvent extends Struct {
  @Int32()
  external int status;

  /// 0: success, 1: allocation failure, 2: invalid native payload.
  @Int32()
  external int copyError;
  @Int64()
  external int timestampMs;
  @Bool()
  external bool hasTimestampMs;
  external Pointer<MpFlutterAudioHead> heads;
  @Int32()
  external int headsCount;
}

/// Takes a slot whose results [post], `NativeApi.postCObject`, sends to the
/// Dart [port]: each copy's address as an integer, then null for the end.
@Native<Int32 Function(Pointer<Void>, Int64, Pointer<Pointer<Void>>)>(
  symbol: 'MpFlutterAudioStreamAcquire',
  assetId: _bridge,
)
external int streamAcquire(
  Pointer<Void> post,
  int port,
  Pointer<Pointer<Void>> callback,
);

@Native<Void Function(Int32)>(
  symbol: 'MpFlutterAudioStreamEnd',
  assetId: _bridge,
)
external void streamEnd(int slot);

@Native<Void Function(Int32)>(
  symbol: 'MpFlutterAudioStreamRelease',
  assetId: _bridge,
)
external void streamRelease(int slot);

@Native<Void Function(Pointer<MpFlutterAudioEvent>)>(
  symbol: 'MpFlutterAudioEventFree',
  assetId: _bridge,
)
external void eventFree(Pointer<MpFlutterAudioEvent> event);
