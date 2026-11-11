import 'dart:async';
import 'dart:ui' as ui;

import 'package:mediapipe_vision/mediapipe_vision.dart';
import 'package:video_frames/video_frames.dart';

import '../camera/pixels.dart';

/// A decoded video frame as the detector reads it and the page draws it.
typedef PreparedFrame = ({VisionImage input, ui.Image picture});

/// Wraps [frame]'s pixels for the detector, converting Android's YUV to
/// RGBA, and decodes the same pixels for display.
Future<PreparedFrame> prepareFrame(VideoFrame frame) async {
  final (pixels, format, bytesPerRow) = switch (frame.layout) {
    VideoPixelLayout.bgra => (
      frame.planes.single.bytes,
      VisionPixelFormat.bgra,
      frame.planes.single.bytesPerRow,
    ),
    VideoPixelLayout.rgba => (
      frame.planes.single.bytes,
      VisionPixelFormat.rgba,
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
    VideoPixelLayout.browser => throw StateError('Browser frame off the web.'),
  };
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
  return (
    input: VisionImage.fromPixels(
      pixels: pixels,
      width: frame.width,
      height: frame.height,
      format: format,
      bytesPerRow: bytesPerRow,
    ),
    picture: await picture.future,
  );
}

/// Releases a frame that is never prepared. Native frames hold nothing.
void discardFrame(VideoFrame frame) {}
