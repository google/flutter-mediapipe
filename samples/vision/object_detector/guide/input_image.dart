import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:mediapipe_vision/mediapipe_vision.dart';

VisionImage imageFromFile(String path) => VisionImage.fromFile(path);

Future<VisionImage> imageFromBytes(Uint8List encoded) async {
  final codec = await ui.instantiateImageCodec(encoded);
  final picture = (await codec.getNextFrame()).image;
  codec.dispose();
  final rgba = await picture.toByteData(format: ui.ImageByteFormat.rawRgba);
  final image = VisionImage.fromPixels(
    pixels: rgba!.buffer.asUint8List(),
    width: picture.width,
    height: picture.height,
    format: VisionPixelFormat.rgba,
  );
  picture.dispose();
  return image;
}
