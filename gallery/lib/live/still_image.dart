import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';

/// A phone picks from its photo library, as its own apps do; the web and
/// desktops open a file dialog.
Future<XFile?> pickStillImage() {
  final phone =
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);
  if (phone) {
    // Without full metadata iOS shows its picker without asking for
    // photo library access.
    return ImagePicker().pickImage(
      source: ImageSource.gallery,
      requestFullMetadata: false,
    );
  }
  return openFile(
    acceptedTypeGroups: const [
      XTypeGroup(
        label: 'Images',
        extensions: ['jpg', 'jpeg', 'png', 'webp'],
        uniformTypeIdentifiers: ['public.image'],
      ),
    ],
  );
}

/// An encoded image decoded for a vision task: its RGBA pixels and size.
typedef StillImage = ({VisionImage input, ui.Size size});

/// The longest side a still image is decoded at. A phone photo decoded in
/// full is 50 to 200 MB of RGBA, copied again on its way into Android's Java
/// heap, which ran the app out of memory; the models see far fewer pixels.
const stillImageMaxSide = 2048;

/// Opens [bytes] scaled down, if need be, to [maxSide] on its longer side.
Future<ui.Codec> decodeScaledDown(Uint8List bytes, int maxSide) async =>
    ui.instantiateImageCodecWithSize(
      await ui.ImmutableBuffer.fromUint8List(bytes),
      getTargetSize: (width, height) {
        final longer = math.max(width, height);
        if (longer <= maxSide) return const ui.TargetImageSize();
        final scale = maxSide / longer;
        return ui.TargetImageSize(
          width: math.max(1, (width * scale).round()),
          height: math.max(1, (height * scale).round()),
        );
      },
    );

/// Decodes [bytes] as the platform's image codec does for display, no larger
/// than [stillImageMaxSide], so the task sees the pixels the page shows.
Future<StillImage> decodeStillImage(Uint8List bytes) async {
  final codec = await decodeScaledDown(bytes, stillImageMaxSide);
  try {
    final frame = await codec.getNextFrame();
    final image = frame.image;
    try {
      final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (rgba == null) throw StateError('Could not decode this image.');
      return (
        input: VisionImage.fromPixels(
          pixels: rgba.buffer.asUint8List(
            rgba.offsetInBytes,
            rgba.lengthInBytes,
          ),
          width: image.width,
          height: image.height,
          format: VisionPixelFormat.rgba,
        ),
        size: ui.Size(image.width.toDouble(), image.height.toDouble()),
      );
    } finally {
      image.dispose();
    }
  } finally {
    codec.dispose();
  }
}
