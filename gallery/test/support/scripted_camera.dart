import 'dart:async';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';
import 'package:mediapipe_vision/platform_interface.dart';
import 'package:mediapipe_gallery/live/live_task.dart';
import 'package:mediapipe_gallery/live/task_settings.dart';

/// A camera platform the test drives by hand: frames arrive when the test
/// says, initialization can be held open, and every lifecycle call is counted.
final class ScriptedCamera extends CameraPlatform {
  ScriptedCamera({this.cameras = defaultCameras});

  static const defaultCameras = [
    CameraDescription(
      name: 'front',
      lensDirection: CameraLensDirection.front,
      sensorOrientation: 0,
    ),
    CameraDescription(
      name: 'back',
      lensDirection: CameraLensDirection.back,
      sensorOrientation: 0,
    ),
  ];

  final List<CameraDescription> cameras;
  final _initialized = <int, StreamController<CameraInitializedEvent>>{};
  final _ready = <int>{};
  final _errors = StreamController<CameraErrorEvent>.broadcast();
  final _streams = <int, StreamController<CameraImageData>>{};
  final created = <String>[];
  int _nextId = 0;
  int disposed = 0;
  int activeStreams = 0;

  /// When set, `initializeCamera` waits on it before reporting ready.
  Completer<void>? initializeGate;

  /// When set, `initializeCamera` fails as a camera the user refused does.
  bool denyAccess = false;

  /// Delivers one frame to every active stream.
  void emit([CameraImageData? frame]) {
    for (final stream in _streams.values) {
      stream.add(frame ?? smallFrame());
    }
  }

  /// Reports a runtime camera failure to the owning controller.
  void fail(String description) {
    for (final id in _streams.keys) {
      _errors.add(CameraErrorEvent(id, description));
    }
  }

  /// A padded BGRA frame, 4 pixels high and [width] (4 by default) wide,
  /// small enough to build hundreds of.
  static CameraImageData smallFrame({int width = 4}) {
    const height = 4;
    final stride = width * 4 + 8;
    return CameraImageData(
      format: const CameraImageFormat(ImageFormatGroup.bgra8888, raw: 'BGRA'),
      width: width,
      height: height,
      planes: [
        CameraImagePlane(
          bytes: Uint8List(stride * height),
          bytesPerRow: stride,
          bytesPerPixel: 4,
        ),
      ],
    );
  }

  @override
  Future<List<CameraDescription>> availableCameras() async => cameras;

  @override
  Future<int> createCamera(
    CameraDescription description,
    ResolutionPreset? preset, {
    bool enableAudio = false,
  }) async {
    final id = _nextId++;
    created.add(description.name);
    _initialized[id] = StreamController<CameraInitializedEvent>();
    return id;
  }

  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {
    await initializeGate?.future;
    if (denyAccess) {
      throw CameraException('CameraAccessDenied', 'Camera access was denied.');
    }
    _ready.add(cameraId);
    _initialized[cameraId]!.add(
      CameraInitializedEvent(
        cameraId,
        4,
        4,
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
        const DeviceOrientationChangedEvent(DeviceOrientation.portraitUp),
      );
  @override
  bool supportsImageStreaming() => true;
  @override
  Widget buildPreview(int cameraId) => const SizedBox.shrink();

  @override
  Stream<CameraImageData> onStreamedFrameAvailable(
    int cameraId, {
    CameraImageStreamOptions? options,
  }) {
    late final StreamController<CameraImageData> stream;
    stream = StreamController<CameraImageData>(
      onListen: () {
        activeStreams++;
        _streams[cameraId] = stream;
      },
      onCancel: () {
        activeStreams--;
        _streams.remove(cameraId);
      },
    );
    return stream.stream;
  }

  @override
  Future<void> dispose(int cameraId) async {
    disposed++;
    // A platform's initialization stream never closes, so a camera that
    // failed to initialize leaves the plugin waiting rather than failing.
    final initialized = _initialized.remove(cameraId);
    if (_ready.remove(cameraId)) await initialized?.close();
  }
}

/// A task whose inference the test completes by hand: a real [FaceDetector]
/// in live stream mode on a platform backend the test drives, so the
/// package's own frame dropping runs under the controller. Each result
/// carries the value its frame was finished with.
class ScriptedTask implements LiveTask<int>, StatefulLiveTask {
  @override
  final settings = TaskSettingValues('scripted');

  final opened = <Delegate>[];

  /// Times the controller asked the task to forget the frames it has seen.
  int forgot = 0;

  /// The timestamps and rotations of the frames the task ran, in order.
  final timestamps = <int>[];
  final rotations = <int>[];

  /// The widths of the frames the task ran.
  final widths = <int>[];
  int closed = 0;

  /// Times Google's task (the backend) was released.
  int released = 0;

  /// Frames the task ran.
  int get detectCalls => timestamps.length;

  /// Running frames, oldest first; finish one to release it.
  final pending = <Completer<int>>[];

  /// When set, every frame fails with this instead of waiting.
  Object? failure;

  /// When set, opening with that delegate throws this error.
  (Delegate, Object)? openFailure;

  FaceDetector? _task;

  @override
  String get name => 'scripted';

  @override
  Future<void> open(
    Delegate delegate,
    Uint8List modelBytes, {
    RunningMode mode = RunningMode.liveStream,
  }) async {
    opened.add(delegate);
    if (openFailure case (
      final refused,
      final error,
    ) when refused == delegate) {
      throw error;
    }
    faceDetectorBackendFactory = (_) async => _ScriptedBackend(this);
    try {
      _task = await FaceDetector.create(
        FaceDetectorOptions(
          modelBytes: modelBytes,
          runningMode: mode,
          delegate: delegate,
        ),
      );
    } finally {
      faceDetectorBackendFactory = null;
    }
  }

  @override
  Future<int> detectImage(VisionImage image) async => 1;

  @override
  Future<int> detectFrame(
    VisionImage frame,
    int timestampMilliseconds, {
    required int rotationDegrees,
  }) async => throw UnimplementedError('The camera tests feed no video file.');

  @override
  void submit(
    VisionImage frame,
    int timestampMilliseconds, {
    required int rotationDegrees,
  }) => _task!.detectAsync(
    frame,
    timestampMilliseconds: timestampMilliseconds,
    rotationDegrees: rotationDegrees,
  );

  @override
  Stream<LiveResult<int>> get results => _task!.results.map(
    (r) => (timestamp: r.timestampMilliseconds!, result: r.imageHeight),
  );

  @override
  int get droppedFrames => _task?.droppedFrames ?? 0;

  /// Completes the oldest running frame with [value].
  void finish([int value = 1]) => pending.removeAt(0).complete(value);

  @override
  void forgetFrames() => forgot++;

  @override
  Future<void> close() async {
    closed++;
    final task = _task;
    _task = null;
    await task?.dispose();
  }
}

/// Google's task as [ScriptedTask] drives it.
final class _ScriptedBackend implements VisionTaskBackend<FaceDetectorResult> {
  _ScriptedBackend(this._task);
  final ScriptedTask _task;

  @override
  Future<FaceDetectorResult> detect(
    VisionImage image,
    int rotationDegrees,
    int? timestampMilliseconds, {
    VisionRegionOfInterest? regionOfInterest,
  }) async {
    _task.timestamps.add(timestampMilliseconds!);
    _task.rotations.add(rotationDegrees);
    _task.widths.add(image.width!);
    if (_task.failure case final failure?) throw failure;
    final value = Completer<int>();
    _task.pending.add(value);
    return FaceDetectorResult(
      imageWidth: image.width!,
      imageHeight: await value.future,
      detections: const [],
      timestampMilliseconds: timestampMilliseconds,
    );
  }

  @override
  Future<void> dispose() async => _task.released++;
}
