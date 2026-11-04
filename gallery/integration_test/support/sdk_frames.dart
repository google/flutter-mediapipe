import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';

/// A decoded sample: its RGBA pixels and the same pixels as a task input.
typedef SampleFrame = ({
  int width,
  int height,
  Uint8List pixels,
  VisionImage image,
});

/// Decodes the bundled `assets/samples/[name]` to RGBA.
Future<SampleFrame> loadSample(String name) async {
  final bytes = await rootBundle.load('assets/samples/$name');
  final codec = await ui.instantiateImageCodec(
    bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
  );
  final image = (await codec.getNextFrame()).image;
  try {
    final rgba = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final pixels = rgba.buffer.asUint8List(
      rgba.offsetInBytes,
      rgba.lengthInBytes,
    );
    return (
      width: image.width,
      height: image.height,
      pixels: pixels,
      image: VisionImage.fromPixels(
        pixels: pixels,
        width: image.width,
        height: image.height,
        format: VisionPixelFormat.rgba,
      ),
    );
  } finally {
    image.dispose();
    codec.dispose();
  }
}

/// [frame] in [format], with 16 bytes of row padding and opaque alpha.
VisionImage paddedImage(SampleFrame frame, VisionPixelFormat format) {
  final channels = format.channels;
  final stride = frame.width * channels + 16;
  final pixels = Uint8List(stride * frame.height);
  final bgra = format == VisionPixelFormat.bgra;
  for (var y = 0; y < frame.height; y++) {
    for (var x = 0; x < frame.width; x++) {
      final src = (y * frame.width + x) * 4;
      final dst = y * stride + x * channels;
      pixels[dst] = frame.pixels[src + (bgra ? 2 : 0)];
      pixels[dst + 1] = frame.pixels[src + 1];
      pixels[dst + 2] = frame.pixels[src + (bgra ? 0 : 2)];
      if (channels == 4) pixels[dst + 3] = 255;
    }
  }
  return VisionImage.fromPixels(
    pixels: pixels,
    width: frame.width,
    height: frame.height,
    format: format,
    bytesPerRow: stride,
  );
}

/// A black RGB square with nothing to detect.
VisionImage blankImage() => VisionImage.fromPixels(
  pixels: Uint8List(64 * 64 * 3),
  width: 64,
  height: 64,
  format: VisionPixelFormat.rgb,
);

/// [frame] turned clockwise by [turn] degrees (0, 90, 180 or 270).
VisionImage rotatedImage(SampleFrame frame, int turn) {
  final width = turn % 180 == 0 ? frame.width : frame.height;
  final height = turn % 180 == 0 ? frame.height : frame.width;
  final pixels = Uint8List(width * height * 4);
  for (var y = 0; y < frame.height; y++) {
    for (var x = 0; x < frame.width; x++) {
      final (dx, dy) = switch (turn) {
        90 => (frame.height - 1 - y, x),
        180 => (frame.width - 1 - x, frame.height - 1 - y),
        270 => (y, frame.width - 1 - x),
        _ => (x, y),
      };
      pixels.setRange(
        (dy * width + dx) * 4,
        (dy * width + dx) * 4 + 4,
        frame.pixels,
        (y * frame.width + x) * 4,
      );
    }
  }
  return VisionImage.fromPixels(
    pixels: pixels,
    width: width,
    height: height,
    format: VisionPixelFormat.rgba,
  );
}
