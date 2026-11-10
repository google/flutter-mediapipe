import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:mediapipe_vision/mediapipe_vision.dart';

/// A decoded photo: the picture the page shows and the pixels the detector
/// reads, which are the same pixels.
typedef StillImage = ({ui.Image picture, VisionImage input});

/// The longest side a photo is decoded at. A phone photo decoded in full is
/// 50 to 200 MB of RGBA; the detector sees 320 by 320.
const _maxSide = 2048;

/// Decodes [bytes] with the platform's codec, scaled down to [_maxSide].
Future<StillImage> decodeStillImage(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodecWithSize(
    await ui.ImmutableBuffer.fromUint8List(bytes),
    getTargetSize: (width, height) {
      final longer = math.max(width, height);
      if (longer <= _maxSide) return const ui.TargetImageSize();
      final scale = _maxSide / longer;
      return ui.TargetImageSize(
        width: math.max(1, (width * scale).round()),
        height: math.max(1, (height * scale).round()),
      );
    },
  );
  try {
    final picture = (await codec.getNextFrame()).image;
    final rgba = await picture.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (rgba == null) {
      picture.dispose();
      throw StateError('Could not decode this image.');
    }
    return (
      picture: picture,
      input: VisionImage.fromPixels(
        pixels: rgba.buffer.asUint8List(rgba.offsetInBytes, rgba.lengthInBytes),
        width: picture.width,
        height: picture.height,
        format: VisionPixelFormat.rgba,
      ),
    );
  } finally {
    codec.dispose();
  }
}
