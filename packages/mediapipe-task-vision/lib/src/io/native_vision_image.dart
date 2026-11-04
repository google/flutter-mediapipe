/// Shared native plumbing for every vision task.
library;

import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../third_party/mediapipe/vision_bindings.dart' as mp;
import '../types/vision_types.dart';
import 'pixel_conversion.dart';

/// Builds a native image from [input], copying pixels into [arena].
///
/// Set [expandRgbForGpu] when the task runs on the GPU: Apple's GPU image
/// upload aborts the process on an ImageFrame without alpha (UP-044), so
/// opaque alpha is added before entering the official graph, on every host as
/// in the GPU references. That covers files too, which Google's decoder turns
/// into three channels for a JPEG and one for a grayscale image.
mp.MpImagePtr createVisionImage(
  Arena arena,
  VisionImage input, {
  required bool expandRgbForGpu,
  required void Function(mp.MpStatus Function(Pointer<Pointer<Char>>)) checked,
}) {
  final imageOut = arena<mp.MpImagePtr>();
  if (input.path case final path?) {
    final name = path.toNativeUtf8(allocator: arena).cast<Char>();
    checked((error) => mp.MpImageCreateFromFile(name, imageOut, error));
    return expandRgbForGpu
        ? _withAlpha(arena, imageOut.value, checked)
        : imageOut.value;
  }
  final expandRgb = expandRgbForGpu && input.format == VisionPixelFormat.rgb;
  final (pixels, byteCount) = packVisionPixels(
    arena,
    input,
    expandRgb: expandRgb,
  );
  checked(
    (error) => mp.MpImageCreateFromUint8Data(
      input.format == VisionPixelFormat.rgb && !expandRgb
          ? mp.MpImageFormat.kMpImageFormatSrgb
          : mp.MpImageFormat.kMpImageFormatSrgba,
      input.width!,
      input.height!,
      pixels,
      byteCount,
      imageOut,
      error,
    ),
  );
  return imageOut.value;
}

/// Replaces a decoded 8-bit gray or RGB [image] with an RGBA copy and frees
/// it. Any other image, already four-channel or wider than 8 bits, is returned
/// as it is.
mp.MpImagePtr _withAlpha(
  Arena arena,
  mp.MpImagePtr image,
  void Function(mp.MpStatus Function(Pointer<Pointer<Char>>)) checked,
) {
  final channels = mp.MpImageGetChannels(image);
  if (mp.MpImageGetByteDepth(image) != 1 || (channels != 1 && channels != 3)) {
    return image;
  }
  try {
    final width = mp.MpImageGetWidth(image);
    final height = mp.MpImageGetHeight(image);
    final rowStride = mp.MpImageGetWidthStep(image);
    final data = arena<Pointer<Uint8>>();
    checked((error) => mp.MpImageDataUint8(image, data, error));
    final source = data.value.asTypedList(rowStride * height);
    final byteCount = width * height * 4;
    final pixels = arena<Uint8>(byteCount);
    final packed = pixels.asTypedList(byteCount);
    // Gray repeats its one channel as red, green and blue.
    final green = channels == 3 ? 1 : 0;
    final blue = channels == 3 ? 2 : 0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final from = y * rowStride + x * channels;
        final to = (y * width + x) * 4;
        packed[to] = source[from];
        packed[to + 1] = source[from + green];
        packed[to + 2] = source[from + blue];
        packed[to + 3] = 255;
      }
    }
    final expanded = arena<mp.MpImagePtr>();
    checked(
      (error) => mp.MpImageCreateFromUint8Data(
        mp.MpImageFormat.kMpImageFormatSrgba,
        width,
        height,
        pixels,
        byteCount,
        expanded,
        error,
      ),
    );
    return expanded.value;
  } finally {
    mp.MpImageFree(image);
  }
}

/// Copies [input]'s pixels into [arena] without row padding, as Google's C API
/// takes them: BGRA becomes RGBA, and RGB gains opaque alpha when [expandRgb]
/// is set. Returns the buffer and its length in bytes.
(Pointer<Uint8>, int) packVisionPixels(
  Arena arena,
  VisionImage input, {
  required bool expandRgb,
}) {
  final bytes = input.pixels!;
  final rowSize = input.width! * (expandRgb ? 4 : input.format!.channels);
  final byteCount = rowSize * input.height!;
  final pixels = arena<Uint8>(byteCount);
  final packed = pixels.asTypedList(byteCount);
  if (expandRgb) {
    for (var y = 0; y < input.height!; y++) {
      for (var x = 0; x < input.width!; x++) {
        final source = y * input.bytesPerRow! + x * 3;
        final target = y * rowSize + x * 4;
        packed[target] = bytes[source];
        packed[target + 1] = bytes[source + 1];
        packed[target + 2] = bytes[source + 2];
        packed[target + 3] = 255;
      }
    }
  } else if (input.format == VisionPixelFormat.bgra) {
    copyBgraToRgba(
      source: bytes,
      target: packed,
      width: input.width!,
      height: input.height!,
      bytesPerRow: input.bytesPerRow!,
    );
  } else {
    for (var y = 0; y < input.height!; y++) {
      packed.setRange(
        y * rowSize,
        (y + 1) * rowSize,
        bytes,
        y * input.bytesPerRow!,
      );
    }
  }
  return (pixels, byteCount);
}
