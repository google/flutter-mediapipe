import 'dart:typed_data';

/// Display-only threshold; the task's original float mask is retained.
Uint8List maskRgba(Float32List confidence, double threshold) {
  final rgba = Uint8List(confidence.length * 4);
  for (var i = 0; i < confidence.length; i++) {
    if (confidence[i] >= threshold) {
      final offset = i * 4;
      // decodeImageFromPixels expects premultiplied RGBA: #43eeb5 at 115/255.
      rgba[offset] = 30;
      rgba[offset + 1] = 107;
      rgba[offset + 2] = 82;
      rgba[offset + 3] = 115;
    }
  }
  return rgba;
}
