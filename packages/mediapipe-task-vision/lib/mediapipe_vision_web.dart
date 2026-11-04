/// Flutter's registration of Google's browser runtime behind the vision task
/// classes. Not for applications: import `mediapipe_vision.dart`.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';
import 'package:mediapipe_core/platform_interface.dart'
    show SerialTaskQueue, classifierSettingsJson;
import 'package:mediapipe_core/web_task_bridge.dart' show loadPackageScript;
import 'package:mediapipe_vision/platform_interface.dart';
import 'package:web/web.dart' as web;

@JS('mediapipeVision.create')
external JSPromise<JSNumber> _create(JSObject options);
@JS('mediapipeVision.detect')
external JSPromise<_Detection> _detect(JSNumber id, JSObject input);
@JS('mediapipeVision.attachOverlay')
external JSPromise<JSAny?> _attachOverlay(JSNumber id, JSObject canvas);
@JS('mediapipeVision.detachOverlay')
external JSPromise<JSAny?> _detachOverlay(JSNumber id);
@JS('mediapipeVision.setOverlayOptions')
external void _setOverlayOptions(JSNumber id, JSObject options);
@JS('mediapipeVision.overlayActive')
external JSBoolean _overlayActive(JSNumber id);
@JS('mediapipeVision.close')
external JSPromise<JSAny?> _close(JSNumber id);

/// A worker result: JSON, plus the image landmarks packed when possible and
/// the masks the JSON names by index.
extension type _Detection(JSObject _) implements JSObject {
  external JSString get json;
  external JSFloat64Array? get landmarks;
  external JSArray<JSArrayBuffer>? get masks;
}

/// Flutter registration for Google's official browser runtime.
abstract final class MediaPipeVisionWeb {
  /// Installs the browser backends before the first public task is created.
  static void registerWith(Registrar registrar) {
    faceLandmarkerBackendFactory = (o) =>
        WebVisionTask.create('face_landmarker', o, o.runningMode, {
          'numFaces': o.numFaces,
          'minFaceDetectionConfidence': o.minFaceDetectionConfidence,
          'minFacePresenceConfidence': o.minFacePresenceConfidence,
          'minTrackingConfidence': o.minTrackingConfidence,
          'outputFaceBlendshapes': o.outputFaceBlendshapes,
          'outputFacialTransformationMatrixes':
              o.outputFacialTransformationMatrixes,
        }, _browser(decodeFaceLandmarkerResult));
    handLandmarkerBackendFactory = (o) =>
        WebVisionTask.create('hand_landmarker', o, o.runningMode, {
          'numHands': o.numHands,
          'minHandDetectionConfidence': o.minHandDetectionConfidence,
          'minHandPresenceConfidence': o.minHandPresenceConfidence,
          'minTrackingConfidence': o.minTrackingConfidence,
        }, _browser(decodeHandLandmarkerResult));
    poseLandmarkerBackendFactory = (o) =>
        WebVisionTask.create('pose_landmarker', o, o.runningMode, {
          'numPoses': o.numPoses,
          'minPoseDetectionConfidence': o.minPoseDetectionConfidence,
          'minPosePresenceConfidence': o.minPosePresenceConfidence,
          'minTrackingConfidence': o.minTrackingConfidence,
          'outputSegmentationMasks': o.outputSegmentationMasks,
        }, _browser(decodePoseLandmarkerResult));
    gestureRecognizerBackendFactory = (o) =>
        WebVisionTask.create('gesture_recognizer', o, o.runningMode, {
          'numHands': o.numHands,
          'minHandDetectionConfidence': o.minHandDetectionConfidence,
          'minHandPresenceConfidence': o.minHandPresenceConfidence,
          'minTrackingConfidence': o.minTrackingConfidence,
          'cannedGesturesClassifierOptions': classifierSettingsJson(
            o.cannedGesturesClassifierOptions,
          ),
          'customGesturesClassifierOptions': classifierSettingsJson(
            o.customGesturesClassifierOptions,
          ),
        }, _browser(decodeGestureRecognizerResult));
    holisticLandmarkerBackendFactory = (o) =>
        WebVisionTask.create('holistic_landmarker', o, o.runningMode, {
          'minFaceDetectionConfidence': o.minFaceDetectionConfidence,
          'minFaceSuppressionThreshold': o.minFaceSuppressionThreshold,
          'minFacePresenceConfidence': o.minFacePresenceConfidence,
          'minHandLandmarksConfidence': o.minHandLandmarksConfidence,
          'minPoseDetectionConfidence': o.minPoseDetectionConfidence,
          'minPoseSuppressionThreshold': o.minPoseSuppressionThreshold,
          'minPosePresenceConfidence': o.minPosePresenceConfidence,
          'outputFaceBlendshapes': o.outputFaceBlendshapes,
          'outputPoseSegmentationMasks': o.outputPoseSegmentationMask,
        }, _browser(decodeHolisticLandmarkerResult));
    faceDetectorBackendFactory = (o) =>
        WebVisionTask.create('face_detector', o, o.runningMode, {
          'minDetectionConfidence': o.minDetectionConfidence,
          'minSuppressionThreshold': o.minSuppressionThreshold,
        }, _browser(decodeFaceDetectorResult));
    objectDetectorBackendFactory = (o) => WebVisionTask.create(
      'object_detector',
      o,
      o.runningMode,
      classifierSettingsJson(o),
      _browser(decodeObjectDetectorResult),
    );
    imageClassifierBackendFactory = (o) => WebVisionTask.create(
      'image_classifier',
      o,
      o.runningMode,
      classifierSettingsJson(o),
      _browser(decodeImageClassifierResult),
    );
    imageEmbedderBackendFactory = (o) => WebVisionTask.create(
      'image_embedder',
      o,
      o.runningMode,
      {'l2Normalize': o.l2Normalize, 'quantize': o.quantize},
      _browser(decodeImageEmbedderResult),
    );
    interactiveSegmenterBackendFactory = (o) async => _WebInteractiveSegmenter(
      await WebVisionTask.create(
        'interactive_segmenter',
        o,
        RunningMode.image,
        const {},
        (json, _) => json['result'] as Map<String, dynamic>,
      ),
    );
    imageSegmenterBackendFactory = (o) =>
        WebVisionTask.create('image_segmenter', o, o.runningMode, {
          'outputConfidenceMasks': o.outputConfidenceMasks,
          'outputCategoryMask': o.outputCategoryMask,
          'displayNamesLocale': ?o.displayNamesLocale,
        }, _browser(decodeImageSegmenterResult));
  }
}

/// Reads a task's result: the worker's JSON and its packed landmarks.
R Function(Map<String, dynamic>, Float64List?) _browser<R>(
  R Function(VisionResultData data) decode,
) =>
    (json, landmarks) =>
        decode(VisionResultData.fromBrowser(json, landmarks: landmarks));

/// One official browser task on its own worker, with requests serialized.
final class WebVisionTask<R>
    implements VisionTaskBackend<R>, VisionTaskOverlayBackend {
  WebVisionTask._(this._id, this._decode);
  final JSNumber _id;
  final R Function(Map<String, dynamic> json, Float64List? landmarks) _decode;
  final _queue = SerialTaskQueue('MediaPipe task');

  static Future<T> _workerResult<T extends JSAny?>(JSPromise<T> promise) async {
    try {
      return await promise.toDart;
    } catch (cause) {
      throw TaskException('$cause', cause: cause);
    }
  }

  /// Creates one official browser [task] from [options] in [runningMode];
  /// [settings] are the task's own options, named as in Google's JavaScript
  /// API, and [decode] reads each result.
  static Future<WebVisionTask<R>> create<R>(
    String task,
    TaskOptions options,
    RunningMode runningMode,
    Map<String, Object?> settings,
    R Function(Map<String, dynamic> json, Float64List? landmarks) decode,
  ) async {
    await loadPackageScript('mediapipe_vision', 'assets/bridge.js');
    final modelBytes = options.modelBytes;
    final modelPath = options.modelPath;
    final id = await _workerResult(
      _create(
        {
              'task': task,
              'delegate': options.delegate.name.toUpperCase(),
              'modelBytes': modelBytes == null
                  ? null
                  : Uint8List.fromList(modelBytes).toJS,
              'modelPath': modelPath == null
                  ? null
                  : Uri.base.resolve(modelPath).toString(),
              // Google's browser tasks have no LIVE_STREAM; it runs on their
              // VIDEO graph, with its flow limiter in the task runner.
              'runningMode': runningMode == RunningMode.image
                  ? 'IMAGE'
                  : 'VIDEO',
              'runtimeBaseUrl': MediaPipeWebRuntime.resolve(Uri.base),
              ...settings,
            }.jsify()!
            as JSObject,
      ),
    );
    return WebVisionTask._(id, decode);
  }

  Future<R> _submit(Map<String, Object?> input) => _queue.add(() async {
    final detection = await _workerResult(
      _detect(_id, input.jsify()! as JSObject),
    );
    final data = jsonDecode(detection.json.toDart) as Map<String, dynamic>;
    if (detection.masks?.toDart case final masks?) {
      attachMaskBuffers(data['result'] as Map<String, dynamic>, [
        for (final mask in masks) mask.toDart,
      ]);
    }
    return _decode(data, detection.landmarks?.toDart);
  });

  @override
  Future<R> detect(
    VisionImage image,
    int rotationDegrees,
    int? timestampMilliseconds, {
    VisionRegionOfInterest? regionOfInterest,
  }) => _submit(
    image.browserFrame != null
        ? {
            'bitmap': image.browserFrame,
            'width': image.width,
            'height': image.height,
            'rotation': rotationDegrees,
            'timestamp': timestampMilliseconds,
          }
        : {
            'path': image.path == null
                ? null
                : Uri.base.resolve(image.path!).toString(),
            'pixels': image.pixels == null
                ? null
                : Uint8List.fromList(image.pixels!).toJS,
            'width': image.width,
            'height': image.height,
            'format': image.format?.name,
            'stride': image.bytesPerRow,
            'rotation': rotationDegrees,
            'timestamp': timestampMilliseconds,
            'region': switch (regionOfInterest) {
              final r? => [r.left, r.top, r.right, r.bottom],
              null => null,
            },
          },
  );

  @override
  Future<void> attachOverlay(Object canvas) async {
    await _workerResult(_attachOverlay(_id, canvas as web.HTMLCanvasElement));
  }

  @override
  Future<void> detachOverlay() async {
    await _workerResult(_detachOverlay(_id));
  }

  @override
  void setOverlayOptions({
    required bool connections,
    required bool points,
    required bool mirrored,
    required double scale,
  }) => _setOverlayOptions(
    _id,
    {
          'connections': connections,
          'points': points,
          'mirrored': mirrored,
          'scale': scale,
        }.jsify()!
        as JSObject,
  );

  @override
  bool get overlayActive => _overlayActive(_id).toDart;

  @override
  Future<void> dispose() => _queue.close(() => _workerResult(_close(_id)));
}

/// Google's stateful MagicTouch segmenter on a worker: an image, then complete
/// stroke histories, serialized with the worker's other requests.
final class _WebInteractiveSegmenter implements InteractiveSegmenterBackend {
  _WebInteractiveSegmenter(this._task);
  final WebVisionTask<Map<String, dynamic>> _task;

  @override
  Future<void> setImage(VisionImage image) => _task.detect(image, 0, null);

  @override
  Future<ConfidenceMask> segment(List<Stroke> strokes) async {
    final result = await _task._submit({
      'strokes': [
        for (final stroke in strokes)
          [
            stroke.brushMode.nativeValue,
            [
              for (final point in stroke.points) ...[point.x, point.y],
            ],
            stroke.isCompleted,
          ],
      ],
    });
    return confidenceMaskFromList(
      (result['confidenceMasks'] as List).single as List,
    );
  }

  @override
  Future<void> dispose() => _task.dispose();
}
