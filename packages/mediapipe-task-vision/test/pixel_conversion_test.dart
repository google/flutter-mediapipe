import 'dart:math';
import 'dart:typed_data';

import 'package:mediapipe_vision/src/io/pixel_conversion.dart';
import 'package:test/test.dart';

void main() {
  test('BGRA conversion preserves every channel and ignores row padding', () {
    final random = Random(478);
    for (final width in [1, 2, 3, 17, 32, 301]) {
      for (final height in [1, 3, 9]) {
        for (final padding in [0, 1, 2, 3, 4, 64]) {
          for (final offset in [0, 1, 4]) {
            final stride = width * 4 + padding;
            final storage = Uint8List(offset + stride * height);
            final source = Uint8List.sublistView(storage, offset);
            final expected = <int>[];
            for (var y = 0; y < height; y++) {
              for (var x = 0; x < width; x++) {
                final rgba = List.generate(4, (_) => random.nextInt(256));
                expected.addAll(rgba);
                source.setRange(y * stride + x * 4, y * stride + x * 4 + 4, [
                  rgba[2],
                  rgba[1],
                  rgba[0],
                  rgba[3],
                ]);
              }
              source.fillRange(y * stride + width * 4, (y + 1) * stride, 219);
            }
            final original = Uint8List.fromList(storage);
            final destination = Uint8List(offset + expected.length + 4)
              ..fillRange(0, offset + expected.length + 4, 173);
            final target = Uint8List.sublistView(
              destination,
              offset,
              offset + expected.length,
            );
            copyBgraToRgba(
              source: source.asUnmodifiableView(),
              target: target,
              width: width,
              height: height,
              bytesPerRow: stride,
            );
            expect(
              target,
              expected,
              reason: '$width x $height, padding $padding, offset $offset',
            );
            expect(storage, original);
            expect(destination.sublist(0, offset), everyElement(173));
            expect(
              destination.sublist(offset + expected.length),
              everyElement(173),
            );
          }
        }
      }
    }
  });
}
