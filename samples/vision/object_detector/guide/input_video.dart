import 'dart:typed_data';

import 'package:mediapipe_vision/mediapipe_vision.dart';

VisionImage videoFrame(Uint8List rgba, int width, int height) =>
    VisionImage.fromPixels(
      pixels: rgba,
      width: width,
      height: height,
      format: VisionPixelFormat.rgba,
    );
