/// Decodes a video file frame by frame with each platform's own decoder:
/// AVFoundation on iOS and macOS, MediaCodec on Android, Media Foundation on
/// Windows, GStreamer on Linux and a `<video>` element in browsers. The
/// gallery's video file mode feeds every frame to a vision task in video mode;
/// the vision package itself decodes nothing.
library;

import 'dart:typed_data';

import 'src/reader_io.dart'
    if (dart.library.js_interop) 'src/reader_web.dart'
    as platform;

/// How a decoded frame's pixels are laid out.
enum VideoPixelLayout {
  /// Blue, green, red, alpha in one plane.
  bgra,

  /// Red, green, blue, alpha in one plane.
  rgba,

  /// 8-bit luma, then quarter-size blue and red chroma, as three planes.
  yuv420,

  /// A browser frame (`ImageBitmap`) the caller owns and must release.
  browser,
}

/// One plane of a frame: its bytes and how to step through them.
final class VideoPlane {
  /// Wraps [bytes] whose rows start [bytesPerRow] apart and whose samples sit
  /// [bytesPerPixel] apart.
  const VideoPlane(
    this.bytes, {
    required this.bytesPerRow,
    this.bytesPerPixel = 1,
  });

  /// The plane's bytes, from its first visible sample.
  final Uint8List bytes;

  /// Distance between the starts of two rows.
  final int bytesPerRow;

  /// Distance between two samples in a row.
  final int bytesPerPixel;
}

/// One decoded frame, in presentation order.
final class VideoFrame {
  /// A frame of [width] by [height] pixels shown at [timestampMicroseconds].
  const VideoFrame({
    required this.timestampMicroseconds,
    required this.width,
    required this.height,
    required this.layout,
    this.planes = const [],
    this.browserFrame,
  });

  /// When the frame is shown, from the start of the file.
  final int timestampMicroseconds;

  /// Width in pixels, before [VideoFileReader.rotationDegrees] is applied.
  final int width;

  /// Height in pixels, before [VideoFileReader.rotationDegrees] is applied.
  final int height;

  /// How [planes] or [browserFrame] hold the pixels.
  final VideoPixelLayout layout;

  /// One plane for [VideoPixelLayout.bgra] and [VideoPixelLayout.rgba], three
  /// (Y, U, V) for [VideoPixelLayout.yuv420], none for a browser frame.
  final List<VideoPlane> planes;

  /// The browser's frame for [VideoPixelLayout.browser]; null elsewhere.
  final Object? browserFrame;
}

/// A video file opened for decoding. Frames come one at a time, so a long
/// file never sits in memory whole.
abstract interface class VideoFileReader {
  /// Opens the file at [path]: a file on native platforms, a URL (an asset's
  /// or a picked file's object URL) in browsers.
  static Future<VideoFileReader> open(String path) => platform.open(path);

  /// The clockwise turn, a multiple of 90, that shows the frames upright, from
  /// the file's metadata. Browsers apply it themselves, so it is 0 there.
  int get rotationDegrees;

  /// The file's length, when it declares one.
  Duration? get duration;

  /// Frames per second, when the file declares a rate.
  double? get frameRate;

  /// Decodes the next frame; null after the last one.
  Future<VideoFrame?> next();

  /// Releases the decoder; later calls to [next] fail.
  Future<void> close();
}
