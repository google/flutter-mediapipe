import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:mediapipe_core/mediapipe_core.dart';

import '../third_party/mediapipe/vision_bindings.dart' as mp;
import '../runner/native_interface.dart';
import '../types/options.dart';
import '../types/results.dart';
import 'native_vision_task.dart'
    show
        checkVisionCall,
        checkVisionCreate,
        copyVisionDetection,
        nativeRunningMode,
        runVisionRequest,
        setVisionBaseOptions;

/// [options] as Google's C Face Detector options, which [NativeFaceDetector]
/// creates the task with; the options test reads each field back.
void fillFaceDetectorOptions(
  Arena arena,
  mp.MpFaceDetectorOptions native,
  FaceDetectorOptions options,
) {
  setVisionBaseOptions(arena, native.base_options, options, officialGpu: true);
  native
    ..running_mode = nativeRunningMode(options.runningMode)
    ..min_detection_confidence = options.minDetectionConfidence
    ..min_suppression_threshold = options.minSuppressionThreshold;
}

/// Internal synchronous owner, used exclusively by the detector's worker isolate.
final class NativeFaceDetector implements NativeVisionTask<FaceDetectorResult> {
  /// Creates the official IMAGE or VIDEO task with the requested delegate.
  NativeFaceDetector(FaceDetectorOptions options)
    : _gpu = options.delegate == Delegate.gpu {
    using((arena) {
      final native = arena<mp.MpFaceDetectorOptions>();
      fillFaceDetectorOptions(arena, native.ref, options);
      final output = arena<mp.MpFaceDetectorPtr>();
      checkVisionCreate(
        (error) => mp.MpFaceDetectorCreate(native, output, error),
        gpu: _gpu,
      );
      _detector = output.value;
    });
  }

  mp.MpFaceDetectorPtr _detector = nullptr;
  final bool _gpu;

  /// Runs one IMAGE or VIDEO request and copies every result.
  @override
  FaceDetectorResult process(VisionTaskInput input) => runVisionRequest(
    input,
    gpu: _gpu,
    allocate: (arena) => arena<mp.MpFaceDetectorResult>(),
    image: (image, processing, result, error) => mp.MpFaceDetectorDetectImage(
      _detector,
      image,
      processing,
      result,
      error,
    ),
    video: (image, processing, timestamp, result, error) =>
        mp.MpFaceDetectorDetectForVideo(
          _detector,
          image,
          processing,
          timestamp,
          result,
          error,
        ),
    closeResult: mp.MpFaceDetectorCloseResult,
    copy: (request, result) => FaceDetectorResult(
      imageWidth: mp.MpImageGetWidth(request.image),
      imageHeight: mp.MpImageGetHeight(request.image),
      timestampMilliseconds: request.timestamp,
      detections: [
        for (var i = 0; i < result.ref.detections_count; i++)
          copyVisionDetection(result.ref.detections[i]),
      ],
    ),
  );

  /// Closes the task exactly once, including when native shutdown reports failure.
  @override
  void close() {
    if (_detector == nullptr) return;
    final pointer = _detector;
    _detector = nullptr;
    checkVisionCall((error) => mp.MpFaceDetectorClose(pointer, error));
  }
}
