import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';

import 'camera_source.dart';
import 'geometry.dart';
import 'pixels.dart';

CameraSource createCameraSource() => _NativeCameraSource();

class _NativeCameraSource extends CameraSource {
  List<CameraDescription> _cameras = const [];
  int _index = 0;
  CameraController? _controller;
  void Function(CameraFrame frame)? _onFrame;
  bool _disposed = false;

  @override
  String? error;

  @override
  bool get isRunning => _controller?.value.isStreamingImages ?? false;

  @override
  bool get canSwitch => _cameras.length > 1;

  bool get _isFront =>
      _controller?.description.lensDirection == CameraLensDirection.front;

  @override
  double get aspectRatio {
    final value = _controller?.value;
    if (value == null) return 1;
    return previewAspectRatio(value.aspectRatio, value.deviceOrientation);
  }

  @override
  bool get mirrorOverlay => previewIsMirrored(isFrontCamera: _isFront);

  @override
  Future<void> start(void Function(CameraFrame frame) onFrame) async {
    _onFrame = onFrame;
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) throw StateError('No camera found.');
      // The back camera, as Google's sample opens, where there is one.
      final back = _cameras.indexWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
      );
      _index = back < 0 ? 0 : back;
      await _open();
    } on Object catch (failure) {
      _fail(failure);
    }
  }

  @override
  Future<void> switchCamera() async {
    _index = (_index + 1) % _cameras.length;
    try {
      await _open();
    } on Object catch (failure) {
      _fail(failure);
    }
  }

  Future<void> _open() async {
    final previous = _controller;
    _controller = null;
    notifyListeners();
    await previous?.dispose();
    final controller = CameraController(
      _cameras[_index],
      ResolutionPreset.medium,
      enableAudio: false,
      // Android streams YUV; Apple platforms and desktops stream BGRA.
      imageFormatGroup: defaultTargetPlatform == TargetPlatform.android
          ? ImageFormatGroup.yuv420
          : ImageFormatGroup.bgra8888,
    );
    await controller.initialize();
    if (_disposed) {
      await controller.dispose();
      return;
    }
    _controller = controller;
    await controller.startImageStream(_onImage);
    error = null;
    notifyListeners();
  }

  void _onImage(CameraImage image) {
    final controller = _controller;
    if (controller == null) return;
    _onFrame?.call((
      // Android's YUV conversion takes about as long as inference on a slow
      // phone, so only the frames the detector runs are converted.
      image: VisionImage.deferred(() => _visionImage(image)),
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotationDegrees: uprightRotationDegrees(
        width: image.width,
        height: image.height,
        sensorOrientation: controller.description.sensorOrientation,
        isFrontCamera: _isFront,
        deviceOrientation: controller.value.deviceOrientation,
      ),
    ));
  }

  void _fail(Object failure) {
    error = failure is CameraException
        ? failure.description ?? failure.code
        : '$failure';
    notifyListeners();
  }

  @override
  Widget buildPreview() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }
    return CameraPreview(controller);
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_controller?.dispose());
    _controller = null;
    super.dispose();
  }
}

/// Copies a camera image's pixels without rotating or resizing them.
VisionImage _visionImage(CameraImage image) {
  final planes = image.planes;
  if (image.format.group == ImageFormatGroup.bgra8888 && planes.length == 1) {
    return VisionImage.fromPixels(
      pixels: planes.single.bytes,
      width: image.width,
      height: image.height,
      bytesPerRow: planes.single.bytesPerRow,
      // Some desktop cameras deliver RGBA under the BGRA group.
      format: image.format.raw == 'RGBA'
          ? VisionPixelFormat.rgba
          : VisionPixelFormat.bgra,
    );
  }
  if (image.format.group == ImageFormatGroup.yuv420 && planes.length == 3) {
    return VisionImage.fromPixels(
      pixels: yuv420ToRgba(
        width: image.width,
        height: image.height,
        y: planes[0].bytes,
        u: planes[1].bytes,
        v: planes[2].bytes,
        yRowStride: planes[0].bytesPerRow,
        uvRowStride: planes[1].bytesPerRow,
        vRowStride: planes[2].bytesPerRow,
        yPixelStride: planes[0].bytesPerPixel ?? 1,
        uvPixelStride: planes[1].bytesPerPixel ?? 1,
        vPixelStride: planes[2].bytesPerPixel ?? 1,
      ),
      width: image.width,
      height: image.height,
      format: VisionPixelFormat.rgba,
    );
  }
  throw StateError('Unsupported camera format: ${image.format.group}');
}
