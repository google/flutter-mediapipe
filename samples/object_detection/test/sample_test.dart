import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';
import 'package:object_detection/camera/geometry.dart';
import 'package:object_detection/camera/pixels.dart';
import 'package:object_detection/detector_helper.dart';
import 'package:object_detection/overlay.dart';

void main() {
  group('PreviewTransform', () {
    test('maps an upright frame onto a box of its own shape', () {
      final transform = PreviewTransform.fit(
        frameSize: const Size(640, 480),
        rotationDegrees: 0,
        viewSize: const Size(320, 240),
      );
      expect(
        transform.mapRect(64, 48, 320, 240),
        const Rect.fromLTRB(32, 24, 160, 120),
      );
    });

    test('turns a sensor-layout frame upright', () {
      // A 640x480 landscape frame shown upright in a 480x640 portrait box.
      final transform = PreviewTransform.fit(
        frameSize: const Size(640, 480),
        rotationDegrees: 90,
        viewSize: const Size(480, 640),
      );
      // The frame's top left corner lands at the box's top right.
      expect(transform.map(0, 0), const Offset(480, 0));
      expect(transform.map(1, 1), const Offset(0, 640));
    });

    test('mirrors x for a mirrored preview', () {
      final transform = PreviewTransform.fit(
        frameSize: const Size(100, 100),
        rotationDegrees: 0,
        viewSize: const Size(100, 100),
        mirror: true,
      );
      expect(
        transform.mapRect(10, 20, 30, 40),
        const Rect.fromLTRB(70, 20, 90, 40),
      );
    });

    test('cover-fits a frame into a box of another shape', () {
      final transform = PreviewTransform.fit(
        frameSize: const Size(200, 100),
        rotationDegrees: 0,
        viewSize: const Size(100, 100),
      );
      expect(transform.scale, 1);
      expect(transform.map(0.5, 0.5), const Offset(50, 50));
      expect(transform.map(0, 0), const Offset(-50, 0));
    });
  });

  test('previewAspectRatio inverts the sensor ratio in portrait', () {
    expect(previewAspectRatio(4 / 3, DeviceOrientation.portraitUp), 3 / 4);
    expect(previewAspectRatio(4 / 3, DeviceOrientation.landscapeLeft), 4 / 3);
  });

  test('yuv420ToRgba converts gray and honors row strides', () {
    // 2x2 frame, one padding byte per Y row, neutral chroma.
    final rgba = yuv420ToRgba(
      width: 2,
      height: 2,
      y: Uint8List.fromList([16, 235, 0, 126, 126]),
      u: Uint8List.fromList([128]),
      v: Uint8List.fromList([128]),
      yRowStride: 3,
      uvRowStride: 1,
      vRowStride: 1,
    );
    expect(rgba.sublist(0, 4), [0, 0, 0, 255]);
    expect(rgba.sublist(4, 8), [255, 255, 255, 255]);
    expect(rgba[8], rgba[12]);
  });

  test('detectionLabel shows the top category and its score', () {
    final detection = Detection(
      boundingBox: BoundingBox(left: 0, top: 0, right: 1, bottom: 1),
      categories: const [
        MediaPipeCategory(index: 1, score: 0.876, categoryName: 'cat'),
      ],
    );
    expect(detectionLabel(detection), 'cat 0.88');
  });

  test('DetectorSettings starts at the Android sample defaults', () {
    const settings = DetectorSettings();
    expect(settings.threshold, 0.5);
    expect(settings.maxResults, 3);
    expect(settings.delegate, Delegate.cpu);
    expect(settings.copyWith(maxResults: 5).maxResults, 5);
    expect(settings.copyWith(maxResults: 5), isNot(settings));
  });
}
