import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';
import 'package:test/test.dart';

const _fixtures = 'test/fixtures/face_detection';

/// The image of a face reference case: its `file`, or its `raw` pixels (the
/// portrait, 301 by 209) as its `name` asks, either checked against its
/// `sha256`; or without either, a blank of its `width` by `height`.
VisionImage fixtureImage(Map<String, dynamic> expected) {
  final width = expected['width'] as int;
  final height = expected['height'] as int;
  if (expected['file'] case final String name) {
    final file = File('$_fixtures/$name');
    expect(
      sha256.convert(file.readAsBytesSync()).toString(),
      expected['sha256'],
    );
    return VisionImage.fromFile(file.path);
  }
  if (expected['raw'] case final String name) {
    final pixels = File('$_fixtures/$name').readAsBytesSync();
    expect(sha256.convert(pixels).toString(), expected['sha256']);
    if (expected['name'] == 'rgb-pair') {
      // The portrait's middle 180 columns, twice, side by side.
      final pair = Uint8List(360 * 209 * 3);
      for (var y = 0; y < 209; y++) {
        for (var face = 0; face < 2; face++) {
          final offset = (y * 360 + face * 180) * 3;
          pair.setRange(offset, offset + 180 * 3, pixels, (y * 301 + 60) * 3);
        }
      }
      return VisionImage.fromPixels(
        pixels: pair,
        width: width,
        height: height,
        format: VisionPixelFormat.rgb,
      );
    }
    return pixelsImage(
      pixels,
      width: 301,
      height: 209,
      input: switch (expected['name']) {
        'rgba' => 'rgba',
        'rgb-rotated' => 'rotated',
        _ => 'rgb',
      },
    );
  }
  return VisionImage.fromPixels(
    pixels: Uint8List(width * height * 3),
    width: width,
    height: height,
    format: VisionPixelFormat.rgb,
  );
}

/// [raw] RGB pixels, [width] by [height], as a case's [input] asks: `rgb` as
/// they are, `blank` zeros of the same size, `rgba` behind an opaque alpha
/// channel, or `rotated` a quarter turn clockwise, which makes the image
/// [height] wide and [width] tall.
VisionImage pixelsImage(
  Uint8List raw, {
  required int width,
  required int height,
  required String input,
}) {
  var pixels = raw;
  var format = VisionPixelFormat.rgb;
  switch (input) {
    case 'blank':
      pixels = Uint8List(width * height * 3);
    case 'rgba':
      pixels = Uint8List(width * height * 4);
      for (var i = 0; i < width * height; i++) {
        pixels.setRange(i * 4, i * 4 + 3, raw, i * 3);
        pixels[i * 4 + 3] = 255;
      }
      format = VisionPixelFormat.rgba;
    case 'rotated':
      pixels = Uint8List(raw.length);
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          final output = ((width - 1 - x) * height + y) * 3;
          pixels.setRange(output, output + 3, raw, (y * width + x) * 3);
        }
      }
      return VisionImage.fromPixels(
        pixels: pixels,
        width: height,
        height: width,
        format: format,
      );
  }
  return VisionImage.fromPixels(
    pixels: pixels,
    width: width,
    height: height,
    format: format,
  );
}
