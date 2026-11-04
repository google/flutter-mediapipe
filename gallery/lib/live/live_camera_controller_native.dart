import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';

import '../gallery_assets_io.dart';
import 'camera_geometry.dart';
import 'camera_frame.dart';
import 'camera_selection.dart';
import 'frame_timings.dart';
import 'live_task.dart';
import 'operation_queue.dart';
import 'still_image.dart';

/// A submitted camera frame, from its arrival to its result: when it arrived
/// and when the task started it, on [LiveCameraController]'s clock, what
/// converting it cost, and how to draw its result.
final class _Submitted {
  _Submitted(this.arrived, this.size, this.rotation, this.orientation);
  final int arrived;
  final Size size;
  final int rotation;
  final DeviceOrientation orientation;

  /// Set when the task starts the frame and converts it; a dropped frame is
  /// never started.
  int? started;
  double conversion = 0;
}

/// Owns camera capture and one official task in live stream mode.
///
/// Camera lifecycle, the operation queue, generation guards, timestamp
/// monotonicity, timings and error capture are the same whichever task is
/// running, so they live here once and the task supplies only [LiveTask]. The
/// task drops frames itself, as Google's live stream does: every camera frame
/// is submitted as it arrives, and converted only if the task runs it.
class LiveCameraController<T> extends ChangeNotifier {
  LiveCameraController(this.task);

  /// The task being demonstrated.
  final LiveTask<T> task;

  CameraController? _camera;
  bool _opened = false;
  final _operations = OperationQueue();
  StreamSubscription<LiveResult<T>>? _results;

  /// Frames submitted and not yet answered, by timestamp. A frame the task
  /// dropped is forgotten when a newer frame's result arrives.
  final _submitted = SplayTreeMap<int, _Submitted>();

  /// Completes when the warm-up frame in flight returns.
  Completer<void>? _warmUpFrame;
  int _droppedBeforeStart = 0;
  Future<void>? _closing;
  final _clock = Stopwatch();
  int _generation = 0;
  int _lastTimestamp = -1;
  int _timestampOffset = 0;
  bool _closed = false;
  bool _disposed = false;

  CameraController? get camera => _camera;
  bool running = false;
  bool changing = false;
  bool get initializing => false;
  void setProcessingPaused(bool paused) {}
  String? error;

  /// Set when MediaPipe refused the GPU and capture fell back to CPU.
  String? notice;
  T? result;

  /// Cameras this device offers, in the order the platform reports them.
  List<CameraDescription> cameras = const [];

  /// The selected camera, whether or not capture is running.
  CameraDescription? description;

  /// Size of the last frame as the camera delivered it, before rotation.
  Size? frameSize;

  /// The preview's width over its height, upright as the camera view lays it
  /// out, or null before the camera starts.
  double? get previewAspect {
    final value = camera?.value;
    if (value == null || !value.isInitialized) return null;
    return previewAspectRatio(value.aspectRatio, value.deviceOrientation);
  }

  /// Clockwise rotation applied to the last frame to stand it upright.
  int frameRotationDegrees = 0;

  /// Orientation the last frame's rotation was computed for.
  DeviceOrientation deviceOrientation = DeviceOrientation.portraitUp;
  DownloadAsset? _model;
  String? _warmUpSample;

  /// Supplies the model instead of the bundled one: one of Google's other
  /// official models, or a file the user uploaded. Null uses the bundled one.
  Future<Uint8List> Function()? modelLoader;

  /// Whether the demo is looking at the person holding the device.
  bool get isFrontCamera =>
      description?.lensDirection == CameraLensDirection.front;

  /// Whether there is another camera to flip to.
  bool get canSwitchCamera => hasFrontAndBackCameras(cameras);
  int processedFrames = 0;

  /// Camera frames submitted to the task since capture last started.
  int cameraFrames = 0;

  /// Camera frames the task dropped since capture last started: one frame
  /// runs and the newest one waits, so a frame that arrives while another
  /// waits replaces it.
  int get droppedFrames =>
      _opened ? task.droppedFrames - _droppedBeforeStart : 0;

  /// The task's own time for the last frame: from when it started the frame
  /// to its result.
  double inferenceMilliseconds = 0;

  /// What building the last frame's [VisionImage] cost, on this isolate, when
  /// the task started the frame.
  double conversionMilliseconds = 0;

  /// The last frame's conversion and inference together.
  double frameMilliseconds = 0;

  /// The last frame's time from the camera to its result, including its wait
  /// behind the frame before it.
  double latencyMilliseconds = 0;
  double _totalInferenceMilliseconds = 0;
  double _totalConversionMilliseconds = 0;
  double _totalFrameMilliseconds = 0;
  double _totalLatencyMilliseconds = 0;
  final _recent = RecentFrameTimings();

  /// CPU by default, deliberately. Metal wins on back-to-back frames but
  /// loses at camera cadence, because it goes cold in the ~30 ms between them.
  /// Measured on an M4 Max at 1080p with one face: tight loop 4.03 CPU vs 3.45
  /// GPU, at 33 ms spacing 9.03 CPU vs 10.80 GPU. The official Python API
  /// inverts the same way on the same runtime, so this is the delegate's
  /// behaviour rather than anything this wrapper does.
  Delegate delegate = Delegate.cpu;

  /// Mean inference time since capture last started. Starting is what happens
  /// when the delegate changes, so this compares like with like rather than
  /// mixing CPU and GPU frames into one figure.
  double get averageInferenceMilliseconds =>
      processedFrames == 0 ? 0 : _totalInferenceMilliseconds / processedFrames;

  /// Mean time spent building a [VisionImage] from the camera plane. Only
  /// the frames the task runs are converted.
  double get averageConversionMilliseconds =>
      processedFrames == 0 ? 0 : _totalConversionMilliseconds / processedFrames;

  /// Mean conversion and inference per processed frame, so plumbing shows up
  /// as the gap between this and [averageInferenceMilliseconds].
  double get averageFrameMilliseconds =>
      processedFrames == 0 ? 0 : _totalFrameMilliseconds / processedFrames;

  /// Mean time from the camera to a result.
  double get averageLatencyMilliseconds =>
      processedFrames == 0 ? 0 : _totalLatencyMilliseconds / processedFrames;
  double get framesPerSecond => _clock.elapsedMicroseconds == 0
      ? 0
      : processedFrames * 1000000 / _clock.elapsedMicroseconds;

  /// Camera frames that arrived per second while running.
  double get cameraFramesPerSecond => _clock.elapsedMicroseconds == 0
      ? 0
      : cameraFrames * 1000000 / _clock.elapsedMicroseconds;

  /// The readout's figures, over the last [recentFrames] frames, so they
  /// follow the current speed.
  double get recentInferenceMilliseconds => _recent.inferenceMilliseconds;
  double get recentFramesPerSecond => _recent.framesPerSecond;
  int get recentFrames => _recent.length;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  /// Finds the cameras and selects the one a live demo should open with.
  ///
  /// Front first: every live tile here looks at the person holding the device,
  /// so the back camera is the deliberate choice rather than the default.
  Future<List<CameraDescription>> findCameras() async {
    final found = await availableCameras();
    if (_closed) return found;
    cameras = found;
    description ??= found.isEmpty
        ? null
        : found.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front,
            orElse: () => found.first,
          );
    _changed();
    return found;
  }

  /// Flips directly between the front and back cameras.
  Future<void> switchCamera() {
    if (!canSwitchCamera || _closed) return Future.value();
    description = oppositeFacingCamera(cameras, description);
    result = null;
    frameSize = null;
    if (!running) {
      _changed();
      return Future.value();
    }
    // Holistic's VIDEO graph requires one fixed frame size. Front and back
    // cameras can deliver different sizes, so it needs a fresh task too.
    if (task is FixedFrameSizeLiveTask) {
      return start(description: description);
    }
    final selected = description!;
    final generation = ++_generation;
    running = false;
    changing = true;
    error = null;
    _changed();
    return _operations.add(() async {
      await _releaseCamera();
      if (_closed || generation != _generation) return;
      try {
        if (task case final StatefulLiveTask stateful) stateful.forgetFrames();
        await _openCamera(selected, generation);
        if (_closed || generation != _generation) {
          await _release();
          return;
        }
        _resetTimings();
        _timestampOffset = _lastTimestamp;
        running = true;
      } catch (failure) {
        if (generation == _generation) error = _message(failure);
        await _release();
      } finally {
        if (generation == _generation) {
          changing = false;
          _changed();
        }
      }
    });
  }

  /// Starts capture on the selected camera.
  ///
  /// Every argument defaults to what the last start used, so flipping the
  /// camera or changing the delegate does not make the caller restate the rest.
  /// [warmUpSample] is an image asset the task runs on before the camera
  /// starts; see [_warmUp].
  Future<void> start({
    CameraDescription? description,
    Delegate? delegate,
    DownloadAsset? model,
    String? warmUpSample,
  }) {
    if (_closed) return Future.error(StateError('Camera demo is closed.'));
    this.description = description ?? this.description;
    final chosen = delegate ?? this.delegate;
    final pinned = _model = model ?? _model;
    final sample = _warmUpSample = warmUpSample ?? _warmUpSample;
    final selected = this.description;
    if (selected == null || pinned == null) {
      return Future.error(StateError('No camera selected.'));
    }
    final generation = ++_generation;
    running = false;
    changing = true;
    error = null;
    if (chosen == Delegate.gpu) notice = null;
    result = null;
    _changed();
    return _operations.add(() async {
      final keepCamera = _camera != null && description == null;
      if (keepCamera) {
        await _releaseTask();
      } else {
        await _release();
      }
      if (_closed || generation != _generation) return;
      var fallBack = false;
      try {
        this.delegate = chosen;
        final loader = modelLoader;
        final bytes = loader != null
            ? await loader()
            : await GalleryAssets.modelBytes(pinned);
        await task.open(chosen, bytes);
        _opened = true;
        _results = task.results.listen(_onResult, onError: _onResultError);
        if (_closed || generation != _generation) {
          await _release();
          return;
        }
        final warmedUpTo = task is FixedFrameSizeLiveTask
            ? -1
            : await _warmUp(sample);
        if (_closed || generation != _generation) {
          await _release();
          return;
        }
        if (!keepCamera) await _openCamera(selected, generation);
        if (_closed || generation != _generation) {
          await _release();
          return;
        }
        _resetTimings();
        _timestampOffset = 0;
        _lastTimestamp = warmedUpTo;
        running = true;
      } catch (failure) {
        if (generation == _generation) {
          // The package never swaps delegates itself; the demo does, visibly.
          if (chosen == Delegate.gpu && _refusedGpu(failure)) {
            notice = 'GPU unavailable, using CPU. ${_message(failure)}';
            fallBack = true;
          } else {
            error = _message(failure);
          }
        }
        await _release();
      } finally {
        if (generation == _generation) {
          changing = false;
          _changed();
        }
      }
      if (fallBack && !_closed && generation == _generation) {
        unawaited(start(delegate: Delegate.cpu));
      }
    });
  }

  Future<void> _openCamera(CameraDescription selected, int generation) async {
    final camera = CameraController(
      selected,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: defaultTargetPlatform == TargetPlatform.android
          ? ImageFormatGroup.yuv420
          : ImageFormatGroup.bgra8888,
    );
    _camera = camera;
    await camera.initialize();
    if (_closed || generation != _generation) return;
    camera.addListener(_cameraChanged);
    frameSize = null;
    frameRotationDegrees = 0;
    // The callback reads the current generation so a delegate change can keep
    // this camera and its image stream alive while replacing only the task.
    await camera.startImageStream((image) => _onFrame(image, _generation));
  }

  void _resetTimings() {
    processedFrames = 0;
    cameraFrames = 0;
    _droppedBeforeStart = _opened ? task.droppedFrames : 0;
    inferenceMilliseconds = 0;
    conversionMilliseconds = 0;
    frameMilliseconds = 0;
    latencyMilliseconds = 0;
    _totalInferenceMilliseconds = 0;
    _totalConversionMilliseconds = 0;
    _totalFrameMilliseconds = 0;
    _totalLatencyMilliseconds = 0;
    _recent.clear();
    // Results of frames from before, such as the other camera's, are not
    // shown.
    _submitted.clear();
    _clock
      ..reset()
      ..start();
  }

  void _cameraChanged() {
    final description = _camera?.value.errorDescription;
    if (description != null && running) {
      error = description;
      unawaited(stop());
    }
  }

  /// Stamps and submits every frame as it arrives; the task decides which
  /// frames run, and converts a frame when it starts it.
  void _onFrame(CameraImage image, int generation) {
    if (!running || _closed || generation != _generation) return;
    final timestamp = math.max(
      _timestampOffset + _clock.elapsedMilliseconds,
      _lastTimestamp + 1,
    );
    _lastTimestamp = timestamp;
    final arrived = _clock.elapsedMicroseconds;
    try {
      // The frame arrives in sensor layout on mobile, so work out the turn that
      // stands it upright. MediaPipe applies it and still answers in the
      // delivered frame's coordinates, so the overlay takes the same turn.
      final orientation = _camera?.value.deviceOrientation ?? deviceOrientation;
      final rotation = uprightRotationDegrees(
        width: image.width,
        height: image.height,
        sensorOrientation: _camera?.description.sensorOrientation ?? 0,
        isFrontCamera: isFrontCamera,
        deviceOrientation: orientation,
      );
      final submitted = _submitted[timestamp] = _Submitted(
        arrived,
        Size(image.width.toDouble(), image.height.toDouble()),
        rotation,
        orientation,
      );
      cameraFrames++;
      // Android's YUV conversion takes about as long as inference on a slow
      // phone, so only the frames the task runs pay for it. The camera
      // plugin's planes are Dart copies, safe to hold until then.
      final frame = VisionImage.deferred(() {
        final conversion = Stopwatch()..start();
        final converted = visionImageFromCamera(image);
        submitted
          ..conversion = conversion.elapsedMicroseconds / 1000
          ..started = _clock.elapsedMicroseconds;
        return converted;
      });
      task.submit(frame, timestamp, rotationDegrees: rotation);
    } catch (failure) {
      error = _message(failure);
      unawaited(stop());
    }
  }

  void _onResult(LiveResult<T> live) {
    if (_warmUpFrame case final warmUp?) {
      _warmUpFrame = null;
      warmUp.complete();
      return;
    }
    final now = _clock.elapsedMicroseconds;
    // Frames submitted before this one and still unanswered were dropped.
    final frame = _submitted.remove(live.timestamp);
    _submitted.removeWhere((timestamp, _) => timestamp < live.timestamp);
    if (frame == null || !running || _closed) return;
    result = live.result;
    frameSize = frame.size;
    frameRotationDegrees = frame.rotation;
    deviceOrientation = frame.orientation;
    // Split so the readout distinguishes the task's own work from what this
    // demo spends getting a camera frame to it: building the VisionImage
    // here, and the hop the task makes to its worker or platform thread.
    conversionMilliseconds = frame.conversion;
    inferenceMilliseconds = (now - (frame.started ?? frame.arrived)) / 1000;
    frameMilliseconds = conversionMilliseconds + inferenceMilliseconds;
    latencyMilliseconds = (now - frame.arrived) / 1000;
    _totalConversionMilliseconds += conversionMilliseconds;
    _totalInferenceMilliseconds += inferenceMilliseconds;
    _totalFrameMilliseconds += frameMilliseconds;
    _totalLatencyMilliseconds += latencyMilliseconds;
    _recent.add(inference: inferenceMilliseconds, finishedMicroseconds: now);
    processedFrames++;
    _changed();
  }

  void _onResultError(Object failure) {
    if (_warmUpFrame case final warmUp?) {
      _warmUpFrame = null;
      warmUp.completeError(failure);
      return;
    }
    if (_closed || !running) return;
    error = _message(failure);
    unawaited(stop());
  }

  /// Runs one warm-up frame and waits for its result: nothing else is in
  /// flight, so the task runs it.
  Future<void> _warmUpWith(VisionImage image, int timestamp) {
    final done = _warmUpFrame = Completer<void>();
    task.submit(image, timestamp, rotationDegrees: 0);
    return done.future;
  }

  /// Runs the task on [sample], then on a blank frame of its size, before the
  /// camera starts. Its first call loads every model the task chains, and on
  /// GPU compiles their shaders; on the camera's first frame that stall made
  /// the start the slowest, most skipped part of a demo. Models past a
  /// detector run only once it finds something, hence a sample with a
  /// subject; the blank frame then clears the tracking the sample left.
  /// Returns the last timestamp used, which camera frames continue after.
  Future<int> _warmUp(String? sample) async {
    if (sample == null) return -1;
    final data = await rootBundle.load(sample);
    // Object Detector's sample is 4K: in full, its pixels and the blank frame
    // after them took some 130 MB of Android's Java heap and could exhaust it.
    final codec = await decodeScaledDown(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      1280,
    );
    final image = (await codec.getNextFrame()).image;
    try {
      final rgba = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      final width = image.width, height = image.height;
      await _warmUpWith(
        VisionImage.fromPixels(
          pixels: rgba.buffer.asUint8List(
            rgba.offsetInBytes,
            rgba.lengthInBytes,
          ),
          width: width,
          height: height,
          format: VisionPixelFormat.rgba,
        ),
        0,
      );
      await _warmUpWith(
        VisionImage.fromPixels(
          pixels: Uint8List(width * height * 4),
          width: width,
          height: height,
          format: VisionPixelFormat.rgba,
        ),
        1,
      );
    } finally {
      image.dispose();
      codec.dispose();
    }
    if (task case final StatefulLiveTask stateful) stateful.forgetFrames();
    return 1;
  }

  Future<void> stop() {
    if (_closed) return _closing ?? Future.value();
    final generation = ++_generation;
    running = false;
    changing = true;
    result = null;
    _clock.stop();
    _changed();
    return _operations.add(() async {
      await _release();
      if (generation == _generation) {
        changing = false;
        _changed();
      }
    });
  }

  Future<void> _release() async {
    await _releaseCamera();
    await _releaseTask();
  }

  Future<void> _releaseCamera() async {
    final camera = _camera;
    _camera = null;
    camera?.removeListener(_cameraChanged);
    // Tell the view now, before any await: CameraPreview listens to the
    // controller and would otherwise rebuild on it after dispose() and throw.
    // Rebuilding the ancestor first unmounts that preview instead.
    if (camera != null) _changed();
    if (camera != null) {
      try {
        if (camera.value.isStreamingImages) await camera.stopImageStream();
      } catch (failure) {
        error ??= _message(failure);
      } finally {
        try {
          await camera.dispose();
        } catch (failure) {
          error ??= _message(failure);
        }
      }
    }
    frameSize = null;
    _clock.stop();
  }

  /// Closes the task once the frames already submitted have run; their results
  /// are not shown, since capture has stopped.
  Future<void> _releaseTask() async {
    if (_opened) {
      _droppedBeforeStart = 0;
      _opened = false;
      try {
        await task.close();
      } catch (failure) {
        error ??= _message(failure);
      }
    }
    await _results?.cancel();
    _results = null;
    _submitted.clear();
  }

  /// Stops capture, then closes the task after the frames it holds.
  Future<void> close() {
    if (_closing != null) return _closing!;
    _closed = true;
    _generation++;
    running = false;
    return _closing = _operations.add(_release);
  }

  @override
  void dispose() {
    unawaited(close());
    _disposed = true;
    super.dispose();
  }
}

bool _refusedGpu(Object error) => switch (error) {
  TaskException(:final gpuUnavailable) => gpuUnavailable,
  _ => false,
};

String _message(Object error) {
  if (error is CameraException) {
    if (error.code.toLowerCase().contains('access') ||
        error.code.toLowerCase().contains('permission')) {
      final settings = switch (defaultTargetPlatform) {
        TargetPlatform.windows => 'Settings → Privacy & security → Camera',
        TargetPlatform.linux => 'your desktop or camera device permissions',
        TargetPlatform.android => 'Settings → Apps → Permissions → Camera',
        _ => 'System Settings → Privacy & Security → Camera',
      };
      return 'Camera access is unavailable. Allow this app in $settings, '
          'then try again.';
    }
    return error.description ?? error.code;
  }
  return error.toString();
}
