import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';
import 'package:mediapipe_vision/src/io/native_vision_task.dart';
import 'package:mediapipe_vision/src/third_party/mediapipe/vision_bindings.dart'
    as mp;
import 'package:test/test.dart';

// The package binds only the image constructors it uses; Google's library
// also builds the float images its OpenGL ES postprocessing returns.
@Native<
  UnsignedInt Function(
    UnsignedInt,
    Int,
    Int,
    Pointer<Float>,
    Int,
    Pointer<mp.MpImagePtr>,
    Pointer<Pointer<Char>>,
  )
>(
  symbol: 'MpImageCreateFromFloatData',
  assetId: 'package:mediapipe_vision/mediapipe.dylib',
)
external int _createFloatImage(
  int format,
  int width,
  int height,
  Pointer<Float> pixels,
  int count,
  Pointer<mp.MpImagePtr> out,
  Pointer<Pointer<Char>> error,
);

/// Reads [values], one row of [channels]-channel float32 pixels, through
/// Google's image accessors as the package reads a task's category mask.
CategoryMask _read(List<double> values, {int channels = 1}) => using((arena) {
  final pixels = arena<Float>(values.length);
  pixels.asTypedList(values.length).setAll(0, values);
  final image = arena<mp.MpImagePtr>();
  final format = channels == 1
      ? mp.MpImageFormat.kMpImageFormatVec32F1
      : mp.MpImageFormat.kMpImageFormatVec32F4;
  expect(
    _createFloatImage(
      format.value,
      values.length ~/ channels,
      1,
      pixels,
      values.length,
      image,
      arena<Pointer<Char>>(),
    ),
    mp.MpStatus.kMpOk.value,
  );
  try {
    return copyVisionCategoryMask(arena, image.value);
  } finally {
    mp.MpImageFree(image.value);
  }
});

void main() {
  test("a GPU's float category mask reads as the CPU's classes", () {
    // Google's OpenGL ES postprocessing (Android and Linux GPUs) renders
    // each class divided by 255 into one float32 channel.
    final classes = [for (var k = 0; k < 256; k++) k];
    expect(_read([for (final k in classes) k / 255]).categories, classes);
  });

  test("a one-class model's GPU mask reads as the CPU's 0 and 255", () {
    // Foreground 0.0 and background 1.0, where the CPU writes 0 and 255.
    expect(_read([0, 1, 1, 0]).categories, [0, 255, 255, 0]);
  });

  test('classes round to the nearest, not down (UP-024)', () {
    // A truncating readback reports a class one low when the GPU's value
    // lands just under class / 255.
    final classes = [for (var k = 1; k < 255; k++) k];
    for (final drift in [-0.4, 0.4]) {
      expect(
        _read([for (final k in classes) (k + drift) / 255]).categories,
        classes,
        reason: '$drift',
      );
    }
  });

  test('another mask format fails with its shape', () {
    expect(
      () => _read([0, 0, 0, 1], channels: 4),
      throwsA(
        isA<TaskException>().having(
          (e) => e.message,
          'message',
          contains('4 channel(s) of 4 byte(s)'),
        ),
      ),
    );
  });
}
