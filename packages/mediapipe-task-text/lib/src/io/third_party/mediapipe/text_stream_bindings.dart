// Internal callback-copy adapter ABI; no MediaPipe inference code.
// tool/abi_check.cc checks its callback views against Google's headers.
// ignore_for_file: public_member_api_docs
import 'dart:ffi';

import 'generative_text_bindings.dart';

const _bridge = 'package:mediapipe_text/text_stream_bridge.dylib';

final class MpFlutterTextEvent extends Struct {
  external Pointer<Char> text;
  @Int32()
  external int correctionsCount;
  external Pointer<MpCorrection> corrections;
  external Pointer<Char> error;
  @Int32()
  external int copyError;
  @Bool()
  external bool terminal;
}

/// What the bridge posts in place of an event's address when its copy could
/// not be allocated (kMpFlutterTextLostEvent).
const lostEvent = -1;

/// What the bridge posts in place of the last event's address when its copy
/// could not be allocated (kMpFlutterTextLostTerminalEvent).
const lostTerminalEvent = -2;

@Native<Pointer<Void> Function(Pointer<Void>, Int64)>(
  symbol: 'MpFlutterTextStreamCreate',
  assetId: _bridge,
)
external Pointer<Void> streamCreate(Pointer<Void> post, int port);

@Native<Void Function(Pointer<Void>)>(
  symbol: 'MpFlutterTextStreamFree',
  assetId: _bridge,
)
external void streamFree(Pointer<Void> context);

@Native<Void Function(Pointer<MpFlutterTextEvent>)>(
  symbol: 'MpFlutterTextEventFree',
  assetId: _bridge,
)
external void eventFree(Pointer<MpFlutterTextEvent> event);

/// Copies each Proofreader update for the stream's Dart port.
@Native<MpTextProofreaderCallbackFunction>(
  symbol: 'MpFlutterProofreaderCallback',
  assetId: _bridge,
)
external void proofreaderCallback(
  Pointer<Void> context,
  Pointer<MpTextProofreaderStreamResult> result,
  Pointer<Char> error,
);

/// Copies each Summarizer update for the stream's Dart port.
@Native<MpTextSummarizerCallbackFunction>(
  symbol: 'MpFlutterSummarizerCallback',
  assetId: _bridge,
)
external void summarizerCallback(
  Pointer<Void> context,
  Pointer<MpTextSummarizerStreamResult> result,
  Pointer<Char> error,
);
