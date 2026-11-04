import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediapipe_gallery/live/camera_frame.dart';

void main() {
  test(
    'YUV planes retain odd dimensions, independent row/pixel strides and truncated padding',
    () {
      final result = yuv420ToRgba(
        width: 3,
        height: 3,
        y: Uint8List.fromList([16, 235, 16, 99, 235, 16, 235, 99, 16, 235, 16]),
        u: Uint8List.fromList([128, 99, 128, 99, 99, 128, 99, 128]),
        v: Uint8List.fromList([128, 99, 99, 128, 99, 99, 99, 128, 99, 99, 128]),
        yRowStride: 4,
        uvRowStride: 5,
        vRowStride: 7,
        uvPixelStride: 2,
        vPixelStride: 3,
      );
      expect(result.length, 36);
      for (var pixel = 0; pixel < 9; pixel++) {
        final expected = pixel.isEven ? 0 : 255;
        expect(result.sublist(pixel * 4, pixel * 4 + 4), [
          expected,
          expected,
          expected,
          255,
        ]);
      }
    },
  );
  test('YUV chroma order produces red rather than blue', () {
    final result = yuv420ToRgba(
      width: 1,
      height: 1,
      y: Uint8List.fromList([81]),
      u: Uint8List.fromList([90]),
      v: Uint8List.fromList([240]),
      yRowStride: 1,
      uvRowStride: 1,
      vRowStride: 1,
    );
    expect(result, [255, 0, 0, 255]);
  });
  test('incomplete plane is rejected', () {
    expect(
      () => yuv420ToRgba(
        width: 2,
        height: 2,
        y: Uint8List(3),
        u: Uint8List(1),
        v: Uint8List(1),
        yRowStride: 2,
        uvRowStride: 1,
        vRowStride: 1,
      ),
      throwsArgumentError,
    );
  });
}
