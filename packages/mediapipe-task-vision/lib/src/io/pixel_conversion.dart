import 'dart:typed_data';

/// Copies BGRA pixels to packed RGBA, preserving alpha and discarding padding.
///
/// The caller owns distinct, correctly sized buffers. Camera rows aligned to
/// four bytes use one load/store per pixel. Unaligned rows/views and big-endian
/// hosts retain the byte-wise path. No resizing or color arithmetic is applied.
void copyBgraToRgba({
  required Uint8List source,
  required Uint8List target,
  required int width,
  required int height,
  required int bytesPerRow,
}) {
  if (Endian.host == Endian.little &&
      source.offsetInBytes % 4 == 0 &&
      target.offsetInBytes % 4 == 0 &&
      bytesPerRow % 4 == 0) {
    final input = source.buffer.asUint32List(
      source.offsetInBytes,
      source.lengthInBytes ~/ 4,
    );
    final output = target.buffer.asUint32List(
      target.offsetInBytes,
      width * height,
    );
    final stride = bytesPerRow ~/ 4;
    for (var y = 0; y < height; y++) {
      final sourceRow = y * stride;
      final targetRow = y * width;
      for (var x = 0; x < width; x++) {
        final bgra = input[sourceRow + x];
        output[targetRow + x] =
            (bgra & 0xff00ff00) |
            ((bgra & 0x00ff0000) >> 16) |
            ((bgra & 0x000000ff) << 16);
      }
    }
    return;
  }
  final rowSize = width * 4;
  for (var y = 0; y < height; y++) {
    final sourceRow = y * bytesPerRow;
    final targetRow = y * rowSize;
    for (var x = 0; x < rowSize; x += 4) {
      target[targetRow + x] = source[sourceRow + x + 2];
      target[targetRow + x + 1] = source[sourceRow + x + 1];
      target[targetRow + x + 2] = source[sourceRow + x];
      target[targetRow + x + 3] = source[sourceRow + x + 3];
    }
  }
}
