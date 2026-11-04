import 'dart:ui' show Size;

import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:flutter_test/flutter_test.dart';
import 'package:mediapipe_gallery/live/camera_geometry.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  group('uprightRotationDegrees', () {
    test('leaves desktop frames alone', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(
        uprightRotationDegrees(
          width: 1280,
          height: 720,
          sensorOrientation: 90,
          isFrontCamera: true,
          deviceOrientation: DeviceOrientation.portraitUp,
        ),
        0,
        reason: 'camera_desktop already delivers upright frames',
      );
    });

    test('turns a landscape iOS frame upright only in portrait', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      int rotation(DeviceOrientation orientation, {int sensor = 90}) =>
          uprightRotationDegrees(
            width: 1280,
            height: 720,
            sensorOrientation: sensor,
            isFrontCamera: true,
            deviceOrientation: orientation,
          );
      expect(rotation(DeviceOrientation.portraitUp), 90);
      expect(rotation(DeviceOrientation.portraitDown), 90);
      expect(rotation(DeviceOrientation.portraitUp, sensor: 270), 270);
      // In landscape the plugin has already presented the frame upright.
      expect(rotation(DeviceOrientation.landscapeLeft), 0);
      expect(rotation(DeviceOrientation.landscapeRight), 0);
    });

    test('leaves an already portrait-shaped iOS frame alone', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(
        uprightRotationDegrees(
          width: 720,
          height: 1280,
          sensorOrientation: 90,
          isFrontCamera: true,
          deviceOrientation: DeviceOrientation.portraitUp,
        ),
        0,
      );
    });

    test('combines sensor and device rotation on Android, signed by lens', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      int rotation({
        required bool front,
        required int sensor,
        required DeviceOrientation orientation,
      }) => uprightRotationDegrees(
        width: 1280,
        height: 720,
        sensorOrientation: sensor,
        isFrontCamera: front,
        deviceOrientation: orientation,
      );
      // Back camera subtracts the device rotation, front adds it. A sensor
      // mounted at 90 needs a quarter turn when the phone is held upright.
      expect(
        rotation(
          front: false,
          sensor: 90,
          orientation: DeviceOrientation.portraitUp,
        ),
        90,
      );
      expect(
        rotation(
          front: false,
          sensor: 90,
          orientation: DeviceOrientation.landscapeLeft,
        ),
        0,
      );
      expect(
        rotation(
          front: true,
          sensor: 270,
          orientation: DeviceOrientation.portraitUp,
        ),
        270,
      );
      expect(
        rotation(
          front: true,
          sensor: 270,
          orientation: DeviceOrientation.landscapeLeft,
        ),
        0,
      );
    });
  });

  group('previewIsMirrored', () {
    test('flips only where the preview and the buffers disagree', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(previewIsMirrored(isFrontCamera: true), isTrue);
      expect(previewIsMirrored(isFrontCamera: false), isFalse);
      for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(
          previewIsMirrored(isFrontCamera: true),
          isFalse,
          reason: '$platform mirrors preview and pixels together',
        );
      }
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(previewIsMirrored(isFrontCamera: false), isTrue);
    });
  });

  group('previewAspectRatio', () {
    test('inverts the sensor ratio in portrait, matching CameraPreview', () {
      expect(previewAspectRatio(16 / 9, DeviceOrientation.portraitUp), 9 / 16);
      expect(
        previewAspectRatio(16 / 9, DeviceOrientation.portraitDown),
        9 / 16,
      );
      expect(
        previewAspectRatio(16 / 9, DeviceOrientation.landscapeLeft),
        16 / 9,
      );
    });
  });

  group('PreviewTransform', () {
    PreviewTransform transform({
      required int rotation,
      bool mirror = false,
      Size frame = const Size(200, 100),
      Size view = const Size(100, 200),
    }) => PreviewTransform.fit(
      frameSize: frame,
      rotationDegrees: rotation,
      viewSize: view,
      mirror: mirror,
    );

    test('maps a quarter turn the way MediaPipe rotates the frame', () {
      // Reproduces the package's own rotation fixture: a 209x301 frame given
      // rotationDegrees 90 returns a box at (53, 106), which is the same face
      // the unrotated 301x209 frame reports at (111, 54). Mapping the rotated
      // reading through this transform has to land back on the upright one.
      final t = transform(
        rotation: 90,
        frame: const Size(209, 301),
        view: const Size(301, 209),
      );
      expect(t.uprightSize, const Size(301, 209));
      expect(t.scale, 1);
      final mapped = t.map(53 / 209, 106 / 301);
      expect(mapped.dx, closeTo(195, 0.5));
      expect(mapped.dy, closeTo(53, 0.5));
    });

    test('is the identity when nothing rotates or mirrors', () {
      final t = transform(
        rotation: 0,
        frame: const Size(100, 200),
        view: const Size(100, 200),
      );
      expect(t.map(0, 0), const Offset(0, 0));
      expect(t.map(1, 1), const Offset(100, 200));
      expect(t.map(0.25, 0.5), const Offset(25, 100));
    });

    test('mirrors x and leaves y alone', () {
      final t = transform(
        rotation: 0,
        mirror: true,
        frame: const Size(100, 200),
        view: const Size(100, 200),
      );
      expect(t.map(0.25, 0.5), const Offset(75, 100));
    });

    test('rotating a corner three quarters lands on the opposite corner', () {
      final t = transform(
        rotation: 270,
        frame: const Size(200, 100),
        view: const Size(100, 200),
      );
      expect(t.uprightSize, const Size(100, 200));
      // Top-left of the frame ends up bottom-left after a 270 turn clockwise.
      final mapped = t.map(0, 0);
      expect(mapped.dx, closeTo(0, 0.001));
      expect(mapped.dy, closeTo(200, 0.001));
    });

    test('half a turn sends each corner to its diagonal', () {
      final t = transform(
        rotation: 180,
        frame: const Size(100, 200),
        view: const Size(100, 200),
      );
      expect(t.map(0, 0), const Offset(100, 200));
      expect(t.map(1, 1), const Offset(0, 0));
    });

    test('covers the box and centres the axis that overflows', () {
      // A square frame in a tall 100x200 box has to scale up to 2x to cover it,
      // which makes it 200 wide. The excess is split either side, so the centre
      // of the frame still lands in the centre of the box.
      final t = transform(
        rotation: 0,
        frame: const Size(100, 100),
        view: const Size(100, 200),
      );
      expect(t.scale, 2);
      expect(t.offsetX, -50);
      expect(t.offsetY, 0);
      expect(t.map(0.5, 0.5), const Offset(50, 100));
      expect(t.map(0, 0), const Offset(-50, 0));
    });

    test('survives a frame or a box with no area', () {
      expect(
        transform(rotation: 0, frame: Size.zero).map(0.5, 0.5),
        isA<Offset>(),
      );
      expect(
        transform(rotation: 0, view: Size.zero).map(0.5, 0.5),
        isA<Offset>(),
      );
    });
  });
}
