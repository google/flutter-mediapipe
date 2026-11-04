import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mediapipe_vision/platform_interface.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';
import 'package:mediapipe_gallery/live/live_camera_controller.dart';
import 'package:mediapipe_gallery/live/live_tasks.dart';
import 'package:mediapipe_gallery/live/live_camera_view.dart';
import 'package:mediapipe_gallery/main.dart';

import 'support/delegate_control.dart';
import 'support/gallery_tiles.dart';
import 'support/no_camera.dart';
import 'support/sdk_frames.dart';
import 'package:mediapipe_gallery/bundled_model_assets.dart';
import 'support/device_log.dart';

/// `skip` on emulators: SwiftShader GL accepts a GPU task, then TFLite's GL
/// delegate fails on the first frame (see test_android_sdk_tasks.sh). GPU is
/// then a phone check, as for the other SDK suites.
const _gpu = String.fromEnvironment('SDK_GPU', defaultValue: 'optional');
const _delegates = [Delegate.cpu, if (_gpu != 'skip') Delegate.gpu];
const _switches = [
  Delegate.cpu,
  if (_gpu != 'skip') ...[Delegate.gpu, Delegate.cpu],
];

// Face Landmarker through mediapipe_vision on Google's vision library. Runs on
// the iOS simulator and Android emulator in CI (CPU), and on phones (CPU and
// GPU).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'official SDK CPU and GPU: face pixels, padding, optional outputs',
    (tester) async {
      await tester.runAsync(() async {
        expect(Platform.isAndroid || Platform.isIOS, isTrue);
        expect(
          faceLandmarkerBackendFactory,
          isNull,
          reason:
              "Android and iOS run Google's C library through FFI, not a "
              'plugin backend',
        );
        final assets = await GalleryAssets.unpack();
        final model = await loadBundledModel('face_landmarker.task');
        final frame = await loadSample('portrait.jpg');
        final references = <FaceLandmarkerResult>[];
        for (final delegate in _delegates) {
          final task = await FaceLandmarker.create(
            FaceLandmarkerOptions(
              modelBytes: model,
              delegate: delegate,
              outputFaceBlendshapes: true,
              outputFacialTransformationMatrixes: true,
            ),
          );
          try {
            final reference = await task.detect(frame.image);
            _face(reference, optional: true);
            references.add(reference);
            final copied = reference.faceLandmarks.single.first.x;
            for (final format in VisionPixelFormat.values) {
              final channels = format.channels;
              final stride = frame.width * channels + 16;
              final pixels = Uint8List(stride * frame.height);
              for (var y = 0; y < frame.height; y++) {
                for (var x = 0; x < frame.width; x++) {
                  final src = (y * frame.width + x) * 4;
                  final dst = y * stride + x * channels;
                  pixels[dst] = frame
                      .pixels[src + (format == VisionPixelFormat.bgra ? 2 : 0)];
                  pixels[dst + 1] = frame.pixels[src + 1];
                  pixels[dst + 2] = frame
                      .pixels[src + (format == VisionPixelFormat.bgra ? 0 : 2)];
                  if (channels == 4) pixels[dst + 3] = 255;
                }
              }
              final padded = await task.detect(
                VisionImage.fromPixels(
                  pixels: pixels,
                  width: frame.width,
                  height: frame.height,
                  format: format,
                  bytesPerRow: stride,
                ),
              );
              expect(
                _delta(reference, padded),
                lessThan(1e-5),
                reason: format.name,
              );
            }
            _face(
              await task.detect(
                VisionImage.fromFile(assets.path('portrait.jpg')),
              ),
              optional: true,
            );
            final blank = await task.detect(blankImage());
            expect(blank.faceLandmarks, isEmpty);
            expect(blank.faceBlendshapes, isEmpty);
            expect(blank.facialTransformationMatrixes, isEmpty);
            expect(reference.faceLandmarks.single.first.x, copied);
            _report('image', {
              'delegate': delegate.name,
              'landmarks': 478,
              'blendshapes': reference.faceBlendshapes.single.length,
              'matrix': reference.facialTransformationMatrixes.single.data,
            });
          } finally {
            await task.dispose();
          }
          await task.dispose();
          await expectLater(task.detect(frame.image), throwsStateError);
        }
        if (references.length == 2) {
          final delta = _delta(references[0], references[1]);
          expect(
            delta,
            lessThan(0.03),
            reason: 'CPU/GPU must detect the same face geometry',
          );
          _report('cpu_gpu', {'max_landmark_delta': delta});
        }
        await expectLater(
          FaceLandmarker.create(
            FaceLandmarkerOptions(
              modelBytes: Uint8List.fromList([1, 2, 3]),
              delegate: _delegates.last,
            ),
          ),
          throwsA(isA<TaskException>()),
        );
      });
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  testWidgets('official SDK VIDEO: tracking, rotation, queued frames, cleanup', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final frame = await loadSample('portrait.jpg');
      for (final delegate in _switches) {
        final task = await FaceLandmarker.create(
          FaceLandmarkerOptions(
            model: VisionModels.faceLandmarker,
            delegate: delegate,
            runningMode: RunningMode.video,
          ),
        );
        try {
          await expectLater(task.detect(frame.image), throwsStateError);
          await expectLater(
            task.detectForVideo(frame.image, timestampMilliseconds: -1),
            throwsArgumentError,
          );
          await expectLater(
            task.detectForVideo(
              frame.image,
              timestampMilliseconds: 0,
              rotationDegrees: 45,
            ),
            throwsArgumentError,
          );
          final results = await Future.wait([
            task.detectForVideo(frame.image, timestampMilliseconds: 0),
            task.detectForVideo(frame.image, timestampMilliseconds: 33),
          ]);
          _face(results.first);
          expect(results.map((r) => r.timestampMilliseconds), [0, 33]);
          await expectLater(
            task.detectForVideo(frame.image, timestampMilliseconds: 33),
            throwsArgumentError,
          );
          for (var i = 2; i < 20; i++) {
            final result = await task.detectForVideo(
              frame.image,
              timestampMilliseconds: i * 33,
            );
            _face(result);
            expect(result.timestampMilliseconds, i * 33);
          }
          final empty = await task.detectForVideo(
            blankImage(),
            timestampMilliseconds: 660,
          );
          expect(empty.faceLandmarks, isEmpty);
          _face(
            await task.detectForVideo(frame.image, timestampMilliseconds: 693),
          );
          _report('video', {
            'delegate': delegate.name,
            'face_frames': 21,
            'blank_frames': 1,
            'queued_frames': 2,
          });
        } finally {
          await task.dispose();
        }
      }
      // A camera can deliver a rotated sensor buffer. Rotate its pixels back
      // before asking MediaPipe for the turn; geometry must remain in input space.
      for (final delegate in _delegates) {
        final task = await FaceLandmarker.create(
          FaceLandmarkerOptions(
            modelBytes: await loadBundledModel('face_landmarker.task'),
            delegate: delegate,
          ),
        );
        try {
          for (final turn in [0, 90, 180, 270]) {
            final rotated = rotatedImage(frame, (360 - turn) % 360);
            _face(await task.detect(rotated, rotationDegrees: turn));
          }
        } finally {
          await task.dispose();
        }
      }
    });
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('camera: CPU to GPU to CPU, front and back', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Text('Testing Android Face Landmarker')),
      ),
    );
    await tester.runAsync(() async {
      final controller = LiveCameraController<FaceLandmarkerResult>(
        FaceLandmarkerLiveTask(),
      );
      try {
        final cameras = await camerasOrNone(controller.findCameras);
        // The iOS simulator has no camera; Android emulators emulate one,
        // except where SDK_CAMERA says the job runs without.
        if (cameras.isEmpty && (Platform.isIOS || runsWithoutCamera)) {
          _report('camera', {'cameras': 0});
          return;
        }
        expect(cameras, isNotEmpty);
        for (final delegate in _switches) {
          await controller.start(
            delegate: delegate,
            model: VisionModels.faceLandmarker,
          );
          await _frames(controller);
          _cameraReport(controller);
        }
        if (controller.canSwitchCamera) {
          await controller.switchCamera();
          await _frames(controller);
          _cameraReport(controller);
          await controller.start(delegate: _delegates.last);
          await _frames(controller);
          _cameraReport(controller);
        }
      } finally {
        await controller.close();
        controller.dispose();
      }
    });
  }, timeout: const Timeout(Duration(minutes: 4)));

  testWidgets('gallery opens Face Landmarker and switches CPU/GPU', (
    tester,
  ) async {
    await tester.pumpWidget(const GalleryApp());
    final tile = await scrollToGalleryTile(tester, 'Face Landmarker');
    expect(tile, findsOneWidget);
    await tester.tap(tile);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(LiveCameraView), findsOneWidget);
    final controller = tester
        .widget<LiveCameraView>(find.byType(LiveCameraView))
        .controller;
    Future<void> waitFor(Delegate delegate) async {
      final deadline = DateTime.now().add(const Duration(seconds: 35));
      while ((controller.delegate != delegate ||
              controller.changing ||
              controller.processedFrames < 20) &&
          controller.error == null &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      expect(controller.error, isNull);
      expect(controller.delegate, delegate);
      expect(controller.processedFrames, greaterThanOrEqualTo(20));
      expect(controller.result, isA<FaceLandmarkerResult>());
    }

    // A simulator may have no camera; the demo must then say so.
    final deadline = DateTime.now().add(const Duration(seconds: 35));
    while (controller.cameras.isEmpty &&
        controller.error == null &&
        controller.processedFrames == 0 &&
        DateTime.now().isBefore(deadline)) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
    if (controller.cameras.isEmpty && (Platform.isIOS || runsWithoutCamera)) {
      expectNoCameraMessage();
      _report('gallery', {'cameras': 0});
      await tester.runAsync(controller.close);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      return;
    }
    // The page opens on GPU where it is offered (or on CPU after a visible
    // GPU refusal); the switches below start from CPU, so select it.
    await tester.runAsync(() async {
      final deadline = DateTime.now().add(const Duration(seconds: 90));
      while ((controller.changing || !controller.running) &&
          controller.error == null &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    });
    await tester.pump();
    expect(controller.error, isNull);
    if (controller.delegate != Delegate.cpu) {
      await tapDelegate(tester, Delegate.cpu);
    }
    await tester.runAsync(() => waitFor(Delegate.cpu));
    await tester.pump();
    // With SDK_GPU=skip (emulators) the demo may offer no GPU, and none is
    // switched to below. Elsewhere tapDelegate fails if GPU is not offered.
    for (final delegate in _switches.skip(1)) {
      await tapDelegate(tester, delegate);
      await tester.runAsync(() => waitFor(delegate));
      await tester.pump();
    }
    _report('gallery', {
      'delegates': [for (final delegate in _switches) delegate.name],
      'frames_per_stage': 20,
    });
    await controller.close();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
  }, timeout: const Timeout(Duration(minutes: 3)));
}

void _face(FaceLandmarkerResult result, {bool optional = false}) {
  expect(result.faceLandmarks, hasLength(1));
  expect(result.faceLandmarks.single, hasLength(478));
  for (final point in result.faceLandmarks.single) {
    expect(point.x.isFinite && point.y.isFinite && point.z.isFinite, isTrue);
  }
  if (optional) {
    expect(result.faceBlendshapes.single, hasLength(52));
    final matrix = result.facialTransformationMatrixes.single;
    expect(matrix.data, hasLength(16));
    for (final value in matrix.data) {
      expect(value.isFinite, isTrue);
    }
    // Column-major contract: the affine bottom row is [0,0,0,1].
    for (var c = 0; c < 4; c++) {
      expect(matrix.at(3, c), closeTo(c == 3 ? 1 : 0, 1e-5));
    }
  }
}

double _delta(FaceLandmarkerResult a, FaceLandmarkerResult b) {
  _face(a);
  _face(b);
  var maximum = 0.0;
  for (var i = 0; i < 478; i++) {
    final p = a.faceLandmarks.single[i], q = b.faceLandmarks.single[i];
    maximum = math.max(
      maximum,
      math.max(
        (p.x - q.x).abs(),
        math.max((p.y - q.y).abs(), (p.z - q.z).abs()),
      ),
    );
  }
  return maximum;
}

Future<void> _frames(
  LiveCameraController<FaceLandmarkerResult> controller,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 35));
  // At least three seconds of capture, so the rates in the report settle.
  final measured = DateTime.now().add(const Duration(seconds: 3));
  while ((controller.processedFrames < 20 ||
          DateTime.now().isBefore(measured)) &&
      controller.error == null &&
      DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  expect(controller.error, isNull);
  expect(controller.processedFrames, greaterThanOrEqualTo(20));
  expect(controller.result!.imageWidth, greaterThan(0));
  expect(controller.result!.imageHeight, greaterThan(0));
  expect(controller.result!.timestampMilliseconds, isNotNull);
}

void _cameraReport(LiveCameraController<FaceLandmarkerResult> c) =>
    _report('camera', {
      'delegate': c.delegate.name,
      'lens': c.description!.lensDirection.name,
      'rotation': c.frameRotationDegrees,
      'frames': c.processedFrames,
      'width': c.result!.imageWidth,
      'height': c.result!.imageHeight,
      'faces': c.result!.faceLandmarks.length,
      'mean_inference_ms': c.averageInferenceMilliseconds,
      'camera_frames': c.cameraFrames,
      'dropped_frames': c.droppedFrames,
      'mean_conversion_ms': c.averageConversionMilliseconds,
      'mean_frame_ms': c.averageFrameMilliseconds,
      'mean_latency_ms': c.averageLatencyMilliseconds,
      'fps': c.framesPerSecond,
      'camera_fps': c.cameraFramesPerSecond,
    });

void _report(String event, Map<String, Object?> data) =>
    logRecord('SDK_FACE_LANDMARKER', {'event': event, ...data});
