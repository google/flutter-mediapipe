import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:mediapipe_core/mediapipe_core.dart';

import '../third_party/mediapipe/vision_bindings.dart' as mp;
import '../runner/native_interface.dart';
import '../types/options.dart';
import '../types/results.dart';
import 'native_vision_task.dart';

/// Google's Pose Landmarker on its worker isolate.
final class NativePoseLandmarker
    implements NativeVisionTask<PoseLandmarkerResult> {
  /// Creates the task with the requested delegate, mode and masks.
  NativePoseLandmarker(PoseLandmarkerOptions options)
    : _gpu = options.delegate == Delegate.gpu,
      _masks = options.outputSegmentationMasks {
    using((arena) {
      final native = arena<mp.MpPoseLandmarkerOptions>();
      setVisionBaseOptions(
        arena,
        native.ref.base_options,
        options,
        officialGpu: true,
      );
      native.ref.running_mode = nativeRunningMode(options.runningMode);
      native.ref
        ..num_poses = options.numPoses
        ..min_pose_detection_confidence = options.minPoseDetectionConfidence
        ..min_pose_presence_confidence = options.minPosePresenceConfidence
        ..min_tracking_confidence = options.minTrackingConfidence
        ..output_segmentation_masks = options.outputSegmentationMasks;
      final output = arena<mp.MpPoseLandmarkerPtr>();
      checkVisionCreate(
        (error) => mp.MpPoseLandmarkerCreate(native, output, error),
        gpu: _gpu,
      );
      _task = output.value;
    });
  }
  final bool _gpu;
  final bool _masks;
  mp.MpPoseLandmarkerPtr _task = nullptr;

  /// Runs one IMAGE or VIDEO request and copies every result.
  @override
  PoseLandmarkerResult process(VisionTaskInput input) => runVisionRequest(
    input,
    gpu: _gpu,
    allocate: (arena) => arena<mp.MpPoseLandmarkerResult>(),
    image: (image, processing, result, error) =>
        mp.MpPoseLandmarkerDetectImage(_task, image, processing, result, error),
    video: (image, processing, timestamp, result, error) =>
        mp.MpPoseLandmarkerDetectForVideo(
          _task,
          image,
          processing,
          timestamp,
          result,
          error,
        ),
    closeResult: mp.MpPoseLandmarkerCloseResult,
    copy: (request, result) => PoseLandmarkerResult(
      poseLandmarks: [
        for (var i = 0; i < result.ref.pose_landmarks_count; i++)
          copyVisionNormalizedLandmarks(result.ref.pose_landmarks[i]),
      ],
      poseWorldLandmarks: [
        for (var i = 0; i < result.ref.pose_world_landmarks_count; i++)
          copyVisionWorldLandmarks(result.ref.pose_world_landmarks[i]),
      ],
      segmentationMasks: _masks && result.ref.segmentation_masks_count > 0
          ? [
              for (var i = 0; i < result.ref.segmentation_masks_count; i++)
                copyVisionConfidenceMask(
                  request.arena,
                  result.ref.segmentation_masks[i],
                ),
            ]
          : null,
      imageWidth: mp.MpImageGetWidth(request.image),
      imageHeight: mp.MpImageGetHeight(request.image),
      timestampMilliseconds: request.timestamp,
    ),
  );

  @override
  void close() {
    if (_task == nullptr) return;
    final task = _task;
    _task = nullptr;
    checkVisionCall((error) => mp.MpPoseLandmarkerClose(task, error));
  }
}
