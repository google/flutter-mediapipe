import 'dart:js_interop';
import 'dart:ui' as ui;
import 'dart:ui_web' as ui_web;

import 'package:mediapipe_vision/mediapipe_vision.dart';
import 'package:video_frames/video_frames.dart';
import 'package:web/web.dart' as web;

/// A decoded frame as the task takes it and as the view draws it.
typedef PreparedFrame = ({VisionImage input, ui.Image picture});

/// Hands the browser's bitmap to the task, which closes it after inference,
/// and draws a copy of it.
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

/// Closes the bitmap of a frame no task will run.
void discardFrame(VideoFrame frame) =>
    (frame.browserFrame as web.ImageBitmap?)?.close();
