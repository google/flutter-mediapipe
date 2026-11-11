import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';

import 'camera/camera_source.dart';
import 'detector_helper.dart';
import 'overlay.dart';

/// The Camera tab: detection on the live camera in live stream mode.
class CameraPage extends StatefulWidget {
  const CameraPage({
    super.key,
    required this.settings,
    required this.inferenceMilliseconds,
    required this.onError,
  });

  final ValueNotifier<DetectorSettings> settings;
  final ValueNotifier<int?> inferenceMilliseconds;
  final void Function(String message) onError;

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> with WidgetsBindingObserver {
  late final _helper = ObjectDetectorHelper(
    runningMode: RunningMode.liveStream,
    settings: widget.settings.value,
    onError: _onDetectorError,
  );
  StreamSubscription<ResultBundle>? _results;
  CameraSource? _camera;

  /// The size and rotation of each frame awaiting its result, by timestamp.
  final _pending = <int, ({Size size, int rotationDegrees})>{};
  ObjectDetectorResult? _result;
  Size _resultSize = Size.zero;
  int _resultRotation = 0;

  // Phones release the camera in the background; desktops keep it while the
  // window is unfocused.
  static bool get _isPhone =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.settings.addListener(_onSettingsChanged);
    _results = _helper.liveResults.listen(_onResult);
    unawaited(_setUpDetector());
    _startCamera();
  }

  Future<void> _setUpDetector() async {
    try {
      await _helper.setupObjectDetector();
    } on Object catch (error) {
      widget.onError('$error');
    }
  }

  void _onDetectorError(String message, {bool gpuError = false}) {
    // The helper switched to the CPU; show that in the settings too.
    if (gpuError) widget.settings.value = _helper.settings;
    widget.onError(message);
  }

  void _onSettingsChanged() {
    if (widget.settings.value == _helper.settings) return;
    _helper.settings = widget.settings.value;
    setState(() => _result = null);
    unawaited(_setUpDetector());
  }

  void _startCamera() {
    final camera = _camera = CameraSource.create()..addListener(_rebuild);
    unawaited(camera.start(_onFrame));
  }

  /// Releases the camera once the detector is closed: a frame the detector
  /// accepted reads the camera when it runs, which can be after this call.
  Future<void> _stopCamera() async {
    final camera = _camera?..removeListener(_rebuild);
    _camera = null;
    _pending.clear();
    await _helper.clearObjectDetector();
    camera?.dispose();
  }

  /// Moves to the next camera, with the detector closed meanwhile for the
  /// same reason.
  Future<void> _switchCamera(CameraSource camera) async {
    _pending.clear();
    setState(() => _result = null);
    await _helper.clearObjectDetector();
    await camera.switchCamera();
    await _setUpDetector();
  }

  void _rebuild() => setState(() {});

  void _onFrame(CameraFrame frame) {
    if (!_helper.isReady) return;
    try {
      final timestamp = _helper.detectLivestreamFrame(
        frame.image,
        rotationDegrees: frame.rotationDegrees,
      );
      _pending[timestamp] = (
        size: frame.size,
        rotationDegrees: frame.rotationDegrees,
      );
    } on Object catch (error) {
      widget.onError('$error');
    }
  }

  void _onResult(ResultBundle bundle) {
    final timestamp = bundle.result.timestampMilliseconds;
    final frame = _pending.remove(timestamp);
    // Frames before this one that never got a result were dropped.
    _pending.removeWhere((pending, _) => pending < (timestamp ?? 0));
    if (frame == null || !mounted) return;
    widget.inferenceMilliseconds.value = bundle.inferenceMilliseconds;
    setState(() {
      _result = bundle.result;
      _resultSize = frame.size;
      _resultRotation = frame.rotationDegrees;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isPhone) return;
    if (state == AppLifecycleState.inactive && _camera != null) {
      unawaited(_stopCamera());
      setState(() => _result = null);
    } else if (state == AppLifecycleState.resumed && _camera == null) {
      unawaited(_setUpDetector());
      setState(_startCamera);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.settings.removeListener(_onSettingsChanged);
    unawaited(_results?.cancel());
    unawaited(_stopCamera().whenComplete(_helper.close));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    final Widget body;
    if (camera?.error case final error?) {
      body = Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Camera unavailable: $error',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white),
        ),
      );
    } else if (camera == null || !camera.isRunning) {
      body = const CircularProgressIndicator();
    } else {
      body = DetectionView(
        frameSize: _resultSize,
        aspectRatio: camera.aspectRatio,
        rotationDegrees: _resultRotation,
        mirror: camera.mirrorOverlay,
        result: _result,
        child: camera.buildPreview(),
      );
    }
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        children: [
          Center(child: body),
          if (camera != null && camera.canSwitch)
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton.small(
                tooltip: 'Switch camera',
                onPressed: () => _switchCamera(camera),
                child: const Icon(Icons.cameraswitch),
              ),
            ),
        ],
      ),
    );
  }
}
