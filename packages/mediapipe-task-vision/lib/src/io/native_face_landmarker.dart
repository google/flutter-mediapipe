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
        copyVisionCategories,
        copyVisionNormalizedLandmarks,
        nativeRunningMode,
        runVisionRequest,
        setVisionBaseOptions;

/// Internal synchronous owner, used exclusively by the detector's worker isolate.
final class NativeFaceLandmarker
    implements NativeVisionTask<FaceLandmarkerResult> {
  /// Creates the official IMAGE or VIDEO task with the requested delegate.
  NativeFaceLandmarker(FaceLandmarkerOptions options)
    : _gpu = options.delegate == Delegate.gpu {
    using((arena) {
      final native = arena<mp.MpFaceLandmarkerOptions>();
      setVisionBaseOptions(
        arena,
        native.ref.base_options,
        options,
        officialGpu: true,
      );
      native.ref
        ..running_mode = nativeRunningMode(options.runningMode)
        ..num_faces = options.numFaces
        ..min_face_detection_confidence = options.minFaceDetectionConfidence
        ..min_face_presence_confidence = options.minFacePresenceConfidence
        ..min_tracking_confidence = options.minTrackingConfidence
        ..output_face_blendshapes = options.outputFaceBlendshapes
        ..output_facial_transformation_matrixes =
            options.outputFacialTransformationMatrixes;
      final output = arena<mp.MpFaceLandmarkerPtr>();
      checkVisionCreate(
        (error) => mp.MpFaceLandmarkerCreate(native, output, error),
        gpu: _gpu,
      );
      _detector = output.value;
    });
  }

  mp.MpFaceLandmarkerPtr _detector = nullptr;
  final bool _gpu;

  /// Runs one IMAGE or VIDEO request and copies every result.
  @override
  FaceLandmarkerResult process(VisionTaskInput input) => runVisionRequest(
    input,
    gpu: _gpu,
    allocate: (arena) => arena<mp.MpFaceLandmarkerResult>(),
    image: (image, processing, result, error) => mp.MpFaceLandmarkerDetectImage(
      _detector,
      image,
      processing,
      result,
      error,
    ),
    video: (image, processing, timestamp, result, error) =>
        mp.MpFaceLandmarkerDetectForVideo(
          _detector,
          image,
          processing,
          timestamp,
          result,
          error,
        ),
    closeResult: mp.MpFaceLandmarkerCloseResult,
    copy: (request, result) => FaceLandmarkerResult(
      imageWidth: mp.MpImageGetWidth(request.image),
      imageHeight: mp.MpImageGetHeight(request.image),
      timestampMilliseconds: request.timestamp,
      faceLandmarks: [
        for (var i = 0; i < result.ref.face_landmarks_count; i++)
          copyVisionNormalizedLandmarks(result.ref.face_landmarks[i]),
      ],
      faceBlendshapes: copyVisionCategories(
        result.ref.face_blendshapes,
        result.ref.face_blendshapes_count,
      ),
      facialTransformationMatrixes: [
        for (
          var i = 0;
          i < result.ref.facial_transformation_matrixes_count;
          i++
        )
          _copyMatrix(result.ref.facial_transformation_matrixes[i]),
      ],
    ),
  );

  /// Closes the task exactly once, including when native shutdown reports failure.
  @override
  void close() {
    if (_detector == nullptr) return;
    final pointer = _detector;
    _detector = nullptr;
    checkVisionCall((error) => mp.MpFaceLandmarkerClose(pointer, error));
  }
}

Matrix _copyMatrix(mp.MpMatrix value) => Matrix(
  rows: value.rows,
  columns: value.cols,
  data: value.data.asTypedList(value.rows * value.cols),
);
