import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:mediapipe_core/mediapipe_core.dart';

import '../third_party/mediapipe/vision_bindings.dart' as mp;
import '../runner/native_interface.dart';
import '../types/options.dart';
import '../types/results.dart';
import 'native_vision_task.dart';

/// [options] as Google's C Holistic Landmarker options, which
/// [NativeHolisticLandmarker] creates the task with; the options test reads
/// each field back.
void fillHolisticLandmarkerOptions(
  Arena arena,
  mp.MpHolisticLandmarkerOptions native,
  HolisticLandmarkerOptions options,
) {
  setVisionBaseOptions(arena, native.base_options, options, officialGpu: true);
  native
    ..running_mode = nativeRunningMode(options.runningMode)
    ..min_face_detection_confidence = options.minFaceDetectionConfidence
    ..min_face_suppression_threshold = options.minFaceSuppressionThreshold
    ..min_face_presence_confidence = options.minFacePresenceConfidence
    ..output_face_blendshapes = options.outputFaceBlendshapes
    ..output_pose_segmentation_masks = options.outputPoseSegmentationMask
    // Every official library, including the wheels' (Linux, Windows and
    // the official macOS runtime), reads the header's order. Google's
    // Python ctypes do not, so its references are generated with the
    // header's order too (UP-005 in upstream-issues.md).
    ..min_hand_landmarks_confidence = options.minHandLandmarksConfidence
    ..min_pose_detection_confidence = options.minPoseDetectionConfidence
    ..min_pose_suppression_threshold = options.minPoseSuppressionThreshold
    ..min_pose_presence_confidence = options.minPosePresenceConfidence;
}

/// Google's Holistic Landmarker on its worker isolate.
final class NativeHolisticLandmarker
    implements NativeVisionTask<HolisticLandmarkerResult> {
  /// Creates the task with the requested delegate and mode.
  NativeHolisticLandmarker(HolisticLandmarkerOptions options)
    : _gpu = options.delegate == Delegate.gpu {
    using((arena) {
      final native = arena<mp.MpHolisticLandmarkerOptions>();
      fillHolisticLandmarkerOptions(arena, native.ref, options);
      final output = arena<mp.MpHolisticLandmarkerPtr>();
      checkVisionCreate(
        (error) => mp.MpHolisticLandmarkerCreate(native, output, error),
        gpu: _gpu,
      );
      _task = output.value;
    });
  }
  final bool _gpu;
  mp.MpHolisticLandmarkerPtr _task = nullptr;

  /// Runs one IMAGE or VIDEO request and copies every result.
  @override
  HolisticLandmarkerResult process(VisionTaskInput input) => runVisionRequest(
    input,
    gpu: _gpu,
    allocate: (arena) => arena<mp.MpHolisticLandmarkerResult>(),
    image: (image, processing, result, error) =>
        mp.MpHolisticLandmarkerDetectImage(
          _task,
          image,
          processing,
          result,
          error,
        ),
    video: (image, processing, timestamp, result, error) =>
        mp.MpHolisticLandmarkerDetectForVideo(
          _task,
          image,
          processing,
          timestamp,
          result,
          error,
        ),
    closeResult: mp.MpHolisticLandmarkerCloseResult,
    copy: (request, result) => HolisticLandmarkerResult(
      faceLandmarks: copyVisionNormalizedLandmarks(result.ref.face_landmarks),
      poseLandmarks: copyVisionNormalizedLandmarks(result.ref.pose_landmarks),
      poseWorldLandmarks: copyVisionWorldLandmarks(
        result.ref.pose_world_landmarks,
      ),
      leftHandLandmarks: copyVisionNormalizedLandmarks(
        result.ref.left_hand_landmarks,
      ),
      rightHandLandmarks: copyVisionNormalizedLandmarks(
        result.ref.right_hand_landmarks,
      ),
      leftHandWorldLandmarks: copyVisionWorldLandmarks(
        result.ref.left_hand_world_landmarks,
      ),
      rightHandWorldLandmarks: copyVisionWorldLandmarks(
        result.ref.right_hand_world_landmarks,
      ),
      faceBlendshapes: result.ref.face_blendshapes.categories_count == 0
          ? null
          : [
              for (
                var i = 0;
                i < result.ref.face_blendshapes.categories_count;
                i++
              )
                copyVisionCategory(result.ref.face_blendshapes.categories[i]),
            ],
      poseSegmentationMask: result.ref.pose_segmentation_mask == nullptr
          ? null
          : copyVisionConfidenceMask(
              request.arena,
              result.ref.pose_segmentation_mask,
            ),
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
    checkVisionCall((error) => mp.MpHolisticLandmarkerClose(task, error));
  }
}
