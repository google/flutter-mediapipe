import 'dart:typed_data';

import 'package:mediapipe_vision/mediapipe_vision.dart';

VisionImage cameraFrame(
  Uint8List bgra, {
  required int width,
  required int height,
  required int bytesPerRow,
}) => VisionImage.deferred(
  () => VisionImage.fromPixels(
    pixels: bgra,
    width: width,
    height: height,
    bytesPerRow: bytesPerRow,
    format: VisionPixelFormat.bgra,
  ),
);
