import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/widgets.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';
import 'package:web/web.dart' as web;

import 'camera_source.dart';

CameraSource createCameraSource() => _WebCameraSource();

extension type _VideoFrameCallbacks(JSObject object) implements JSObject {
  external int requestVideoFrameCallback(JSFunction callback);
}

extension type _TrackSettings(JSObject object) implements JSObject {
  external String? get facingMode;
  external String? get deviceId;
}

/// `getUserMedia` into a `<video>`, read with `createImageBitmap`.
class _WebCameraSource extends CameraSource {
  final _video = web.HTMLVideoElement()
    ..autoplay = true
    ..muted = true
    ..playsInline = true
    ..style.width = '100%'
    ..style.height = '100%'
    ..style.objectFit = 'cover';
  web.MediaStream? _stream;
  List<String> _deviceIds = const [];
  String? _deviceId;
  void Function(CameraFrame frame)? _onFrame;
  Size? _size;
  bool _mirrored = false;
  double _lastTime = -1;
  int _generation = 0;
  bool _disposed = false;

  @override
  String? error;

  @override
  bool get isRunning => _size != null;

  @override
  bool get canSwitch => _deviceIds.length > 1;

  @override
  double get aspectRatio {
    final size = _size;
    return size == null ? 1 : size.width / size.height;
  }

  // The preview is mirrored with CSS while frames are not.
  @override
  bool get mirrorOverlay => _mirrored;

  @override
  Future<void> start(void Function(CameraFrame frame) onFrame) async {
    _onFrame = onFrame;
    await _open();
  }

  @override
  Future<void> switchCamera() async {
    final next = (_deviceIds.indexOf(_deviceId ?? '') + 1) % _deviceIds.length;
    _deviceId = _deviceIds[next];
    await _open();
  }

  Future<void> _open() async {
    final generation = ++_generation;
    _close();
    try {
      final stream = _stream = await web.window.navigator.mediaDevices
          .getUserMedia(
            web.MediaStreamConstraints(
              video: {
                'width': {'ideal': 640},
                'height': {'ideal': 480},
                if (_deviceId case final id?) 'deviceId': {'exact': id},
              }.jsify()!,
            ),
          )
          .toDart;
      if (_disposed || generation != _generation) {
        _stop(stream);
        return;
      }
      final settings = _TrackSettings(
        stream.getVideoTracks().toDart.first.getSettings(),
      );
      _deviceId = settings.deviceId;
      // Webcams that report no facing mode face the user, as laptop ones do.
      _mirrored = settings.facingMode != 'environment';
      _video
        ..srcObject = stream
        ..style.transform = _mirrored ? 'scaleX(-1)' : '';
      await _video.play().toDart;
      if (_video.videoWidth == 0) await _video.onLoadedMetadata.first;
      if (_disposed || generation != _generation) return;
      // Labels and ids are listed only once the user has allowed a camera.
      final devices = await web.window.navigator.mediaDevices
          .enumerateDevices()
          .toDart;
      _deviceIds = [
        for (final device in devices.toDart)
          if (device.kind == 'videoinput') device.deviceId,
      ];
      _size = Size(_video.videoWidth.toDouble(), _video.videoHeight.toDouble());
      error = null;
      notifyListeners();
      _schedule(generation);
    } on Object catch (failure) {
      final text = '$failure';
      error = text.contains('NotAllowedError')
          ? 'Camera permission denied. Allow camera access in the browser.'
          : text.contains('NotFoundError')
          ? 'No camera found.'
          : text;
      notifyListeners();
    }
  }

  /// Calls [_onVideoFrame] for each new frame, or each animation frame
  /// where the browser has no `requestVideoFrameCallback`.
  void _schedule(int generation) {
    if (_disposed || generation != _generation) return;
    if (_video.has('requestVideoFrameCallback')) {
      _VideoFrameCallbacks(_video).requestVideoFrameCallback(
        ((JSAny? _, JSAny? _) => _onVideoFrame(generation)).toJS,
      );
    } else {
      web.window.requestAnimationFrame(
        ((double _) => _onVideoFrame(generation)).toJS,
      );
    }
  }

  void _onVideoFrame(int generation) {
    if (_disposed || generation != _generation) return;
    _schedule(generation);
    final size = _size;
    if (size == null || _video.currentTime == _lastTime) return;
    _lastTime = _video.currentTime;
    _onFrame?.call((
      // The bitmap is made only if the detector runs this frame, and the
      // detector closes it.
      image: VisionImage.deferred(() async {
        final bitmap = await web.window.createImageBitmap(_video).toDart;
        return VisionImage.fromBrowserFrame(
          bitmap,
          width: bitmap.width,
          height: bitmap.height,
        );
      }),
      size: size,
      rotationDegrees: 0,
    ));
  }

  void _close() {
    if (_stream case final stream?) _stop(stream);
    _stream = null;
    _video.srcObject = null;
    _size = null;
    _lastTime = -1;
  }

  static void _stop(web.MediaStream stream) {
    for (final track in stream.getTracks().toDart) {
      track.stop();
    }
  }

  @override
  Widget buildPreview() => HtmlElementView.fromTagName(
    tagName: 'div',
    onElementCreated: (element) {
      final container = element as web.HTMLElement;
      container.style
        ..width = '100%'
        ..height = '100%'
        ..pointerEvents = 'none';
      container.append(_video);
    },
  );

  @override
  void dispose() {
    _disposed = true;
    _close();
    super.dispose();
  }
}
