import 'dart:async';
import 'dart:ui' as ui;

import 'package:mediapipe_vision/mediapipe_vision.dart';
import 'package:video_frames/video_frames.dart';

import 'camera_frame.dart';

/// A decoded frame as the task takes it and as the view draws it.
typedef PreparedFrame = ({VisionImage input, ui.Image picture});

/// Converts [frame] for the task and the view: BGRA and RGBA as they are, and
/// Android's YUV with the camera path's conversion.
Future<PreparedFrame> prepareFrame(VideoFrame frame) async {
  final (pixels, format, bytesPerRow) = switch (frame.layout) {
    VideoPixelLayout.bgra || VideoPixelLayout.rgba => (
      frame.planes.single.bytes,
      frame.layout == VideoPixelLayout.bgra
          ? VisionPixelFormat.bgra
          : VisionPixelFormat.rgba,
      frame.planes.single.bytesPerRow,
    ),
    VideoPixelLayout.yuv420 => (
      yuv420ToRgba(
        width: frame.width,
        height: frame.height,
        y: frame.planes[0].bytes,
        u: frame.planes[1].bytes,
        v: frame.planes[2].bytes,
        yRowStride: frame.planes[0].bytesPerRow,
        uvRowStride: frame.planes[1].bytesPerRow,
        vRowStride: frame.planes[2].bytesPerRow,
        yPixelStride: frame.planes[0].bytesPerPixel,
        uvPixelStride: frame.planes[1].bytesPerPixel,
        vPixelStride: frame.planes[2].bytesPerPixel,
      ),
      VisionPixelFormat.rgba,
      frame.width * 4,
    ),
    VideoPixelLayout.browser => throw StateError('No browser frames here.'),
  };
  final input = VisionImage.fromPixels(
    pixels: pixels,
    width: frame.width,
    height: frame.height,
    format: format,
    bytesPerRow: bytesPerRow,
  );
  final picture = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    pixels,
    frame.width,
    frame.height,
    format == VisionPixelFormat.bgra
        ? ui.PixelFormat.bgra8888
        : ui.PixelFormat.rgba8888,
    picture.complete,
    rowBytes: bytesPerRow,
  );
  return (input: input, picture: await picture.future);
}

/// Releases a frame the view never shows. Native frames hold no resources.
void discardFrame(VideoFrame frame) {}
