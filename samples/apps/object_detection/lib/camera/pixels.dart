import 'dart:typed_data';

/// Converts Android's YUV_420_888 planes to RGBA.
///
/// The planes may be planar or interleaved, and each has its own row and
/// pixel strides; the last row need not include its padding.
Uint8List yuv420ToRgba({
  required int width,
  required int height,
  required Uint8List y,
  required Uint8List u,
  required Uint8List v,
  required int yRowStride,
  required int uvRowStride,
  required int vRowStride,
  int yPixelStride = 1,
  int uvPixelStride = 1,
  int vPixelStride = 1,
}) {
  void validate(Uint8List plane, int cols, int rows, int row, int pixel) {
    if (cols <= 0 ||
        rows <= 0 ||
        pixel <= 0 ||
        row < (cols - 1) * pixel + 1 ||
        plane.length < (rows - 1) * row + (cols - 1) * pixel + 1) {
      throw ArgumentError('Invalid YUV plane dimensions or strides');
    }
  }

  validate(y, width, height, yRowStride, yPixelStride);
  validate(u, (width + 1) ~/ 2, (height + 1) ~/ 2, uvRowStride, uvPixelStride);
  validate(v, (width + 1) ~/ 2, (height + 1) ~/ 2, vRowStride, vPixelStride);
  final rgba = Uint8List(width * height * 4);
  // Floor division rather than a shift: compiled to JavaScript, a shift of a
  // negative intermediate is unsigned.
  int byte(int numerator) => (numerator / 256).floor().clamp(0, 255);
  for (var row = 0; row < height; row++) {
    for (var col = 0; col < width; col++) {
      final luma = y[row * yRowStride + col * yPixelStride] - 16;
      final cb = u[(row ~/ 2) * uvRowStride + (col ~/ 2) * uvPixelStride] - 128;
      final cr = v[(row ~/ 2) * vRowStride + (col ~/ 2) * vPixelStride] - 128;
      final i = (row * width + col) * 4;
      rgba[i] = byte(298 * luma + 409 * cr + 128);
      rgba[i + 1] = byte(298 * luma - 100 * cb - 208 * cr + 128);
      rgba[i + 2] = byte(298 * luma + 516 * cb + 128);
      rgba[i + 3] = 255;
    }
  }
  return rgba;
}
