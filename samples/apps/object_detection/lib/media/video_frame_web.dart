import 'dart:js_interop';
import 'dart:ui' as ui;
import 'dart:ui_web' as ui_web;

import 'package:mediapipe_vision/mediapipe_vision.dart';
import 'package:video_frames/video_frames.dart';
import 'package:web/web.dart' as web;

/// A decoded video frame as the detector reads it and the page draws it.
typedef PreparedFrame = ({VisionImage input, ui.Image picture});

/// Hands the browser's bitmap to the detector, which closes it after
/// inference, and draws a copy of it.
Future<PreparedFrame> prepareFrame(VideoFrame frame) async {
  final bitmap = frame.browserFrame! as web.ImageBitmap;
  final copy = await web.window.createImageBitmap(bitmap).toDart;
  return (
    input: VisionImage.fromBrowserFrame(
      bitmap,
      width: frame.width,
      height: frame.height,
    ),
    picture: await ui_web.createImageFromImageBitmap(copy),
  );
}

/// Closes the bitmap of a frame that is never prepared.
void discardFrame(VideoFrame frame) =>
    (frame.browserFrame as web.ImageBitmap?)?.close();
