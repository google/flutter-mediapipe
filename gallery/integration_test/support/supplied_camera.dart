import 'dart:async';
import 'dart:ui' as ui;

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';
import 'package:mediapipe_gallery/live/live_camera_controller.dart';
import 'package:mediapipe_gallery/live/live_subjects.dart';

import 'delegate_control.dart';
import 'live_subject.dart';

/// Selects [delegate] on the page's CPU/GPU control once the page has
/// started, before any frames arrive. The gallery opens on GPU wherever it is
/// offered (or on CPU after a visible GPU refusal), so tests that start from
/// one delegate choose it rather than rely on the default.
Future<void> selectDelegate(
  WidgetTester tester,
  LiveCameraController<Object?> controller,
  Delegate delegate,
) async {
  Future<void> settle() async {
    final deadline = DateTime.now().add(const Duration(minutes: 3));
    while ((controller.changing || !controller.running) &&
        controller.error == null &&
        DateTime.now().isBefore(deadline)) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 33));
    }
    expect(controller.error, isNull);
    expect(controller.running, isTrue);
  }

  await settle();
  if (controller.delegate == delegate) return;
  await tapDelegate(tester, delegate);
  await settle();
  expect(controller.delegate, delegate);
}

/// Pumps until [controller] has processed 12 frames of a fresh task, then
/// checks the last result is one [LiveSubject.selected] subject with its
/// full set of finite landmarks.
Future<void> waitForFrames(
  WidgetTester tester,
  LiveCameraController<Object?> controller, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while ((controller.changing || controller.processedFrames < 12) &&
      controller.error == null &&
      DateTime.now().isBefore(deadline)) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 33));
  }
  expect(controller.error, isNull);
  expect(controller.processedFrames, greaterThanOrEqualTo(12));
  final subject = LiveSubject.selected;
  final landmarks = liveSubjects(controller.result);
  expect(landmarks, hasLength(1), reason: 'one ${subject.task} in view');
  expect(landmarks.single, hasLength(subject.points));
  expect(timestampOf(controller.result), greaterThan(0));
  for (final point in landmarks.single) {
    expect(point.x.isFinite && point.y.isFinite, isTrue);
  }
}

/// The input timestamp a live result reports.
int? timestampOf(Object? result) => switch (result) {
  FaceLandmarkerResult(:final timestampMilliseconds) => timestampMilliseconds,
  HandLandmarkerResult(:final timestampMilliseconds) => timestampMilliseconds,
  _ => null,
};

/// The selected subject's sample as padded RGBA and BGRA camera frames.
Future<List<CameraImageData>> sampleFrames() async {
  final bytes = await rootBundle.load(
    'assets/samples/${LiveSubject.selected.sample}',
  );
  final codec = await ui.instantiateImageCodec(
    bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
  );
  final image = (await codec.getNextFrame()).image;
  try {
    final rgba = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final source = rgba.buffer.asUint8List(
      rgba.offsetInBytes,
      rgba.lengthInBytes,
    );
    final stride = image.width * 4 + 16;
    return [
      for (final bgra in [false, true])
        CameraImageData(
          format: CameraImageFormat(
            ImageFormatGroup.bgra8888,
            raw: bgra ? 'BGRA' : 'RGBA',
          ),
          width: image.width,
          height: image.height,
          planes: [
            CameraImagePlane(
              bytes: _pad(source, image.width, image.height, stride, bgra),
              bytesPerRow: stride,
              bytesPerPixel: 4,
            ),
          ],
        ),
    ];
  } finally {
    image.dispose();
    codec.dispose();
  }
}

Uint8List _pad(Uint8List source, int width, int height, int stride, bool bgra) {
  final result = Uint8List(stride * height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final src = (y * width + x) * 4, dst = y * stride + x * 4;
      result[dst] = source[src + (bgra ? 2 : 0)];
      result[dst + 1] = source[src + 1];
      result[dst + 2] = source[src + (bgra ? 0 : 2)];
      result[dst + 3] = 255;
    }
  }
  return result;
}

/// Hosted runners have no webcam: a front RGBA and a back BGRA camera that
/// stream [frames] every 33 ms once [deliverFrames] is set.
final class SuppliedCamera extends CameraPlatform {
  SuppliedCamera(this.frames);
  final List<CameraImageData> frames;
  final _initialized = <int, StreamController<CameraInitializedEvent>>{};
  final _errors = StreamController<CameraErrorEvent>.broadcast();
  final _indices = <int, int>{};
  int _nextId = 0;
  int activeStreams = 0;
  int disposed = 0;
  bool deliverFrames = false;

  @override
  Future<List<CameraDescription>> availableCameras() async => const [
    CameraDescription(
      name: 'supplied-rgba',
      lensDirection: CameraLensDirection.front,
      sensorOrientation: 0,
    ),
    // The flip control appears only when a front and a back camera exist.
    CameraDescription(
      name: 'supplied-bgra',
      lensDirection: CameraLensDirection.back,
      sensorOrientation: 0,
    ),
  ];

  @override
  Future<int> createCamera(
    CameraDescription description,
    ResolutionPreset? preset, {
    bool enableAudio = false,
  }) async {
    final id = _nextId++;
    _indices[id] = description.name == 'supplied-rgba' ? 0 : 1;
    _initialized[id] = StreamController<CameraInitializedEvent>();
    return id;
  }

  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {
    final frame = frames[_indices[cameraId]!];
    _initialized[cameraId]!.add(
      CameraInitializedEvent(
        cameraId,
        frame.width.toDouble(),
        frame.height.toDouble(),
        ExposureMode.auto,
        false,
        FocusMode.auto,
        false,
      ),
    );
  }

  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) =>
      _initialized[cameraId]!.stream;
  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) =>
      _errors.stream.where((event) => event.cameraId == cameraId);
  @override
  Stream<CameraClosingEvent> onCameraClosing(int cameraId) =>
      const Stream.empty();
  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      Stream.value(
        const DeviceOrientationChangedEvent(DeviceOrientation.landscapeLeft),
      );
  @override
  bool supportsImageStreaming() => true;
  @override
  Widget buildPreview(int cameraId) => const ColoredBox(color: Colors.black);

  @override
  Stream<CameraImageData> onStreamedFrameAvailable(
    int cameraId, {
    CameraImageStreamOptions? options,
  }) {
    Timer? timer;
    late final StreamController<CameraImageData> stream;
    stream = StreamController<CameraImageData>(
      onListen: () {
        activeStreams++;
        timer = Timer.periodic(const Duration(milliseconds: 33), (_) {
          if (deliverFrames) stream.add(frames[_indices[cameraId]!]);
        });
      },
      onCancel: () {
        timer?.cancel();
        activeStreams--;
      },
    );
    return stream.stream;
  }

  @override
  Future<void> dispose(int cameraId) async {
    disposed++;
    await _initialized.remove(cameraId)!.close();
    _indices.remove(cameraId);
  }
}
