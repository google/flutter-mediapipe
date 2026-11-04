import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:mediapipe_core/mediapipe_core.dart';

import '../third_party/mediapipe/vision_bindings.dart' as mp;
import '../runner/native_interface.dart';
import '../types/options.dart';
import '../types/results.dart';
import 'native_vision_task.dart';

/// [options] as Google's C Hand Landmarker options, which
/// [NativeHandLandmarker] creates the task with; the options test reads each
/// field back.
void fillHandLandmarkerOptions(
  Arena arena,
  mp.MpHandLandmarkerOptions native,
  HandLandmarkerOptions options,
) {
  setVisionBaseOptions(arena, native.base_options, options, officialGpu: true);
  native.running_mode = nativeRunningMode(options.runningMode);
  native
    ..num_hands = options.numHands
    ..min_hand_detection_confidence = options.minHandDetectionConfidence
    ..min_hand_presence_confidence = options.minHandPresenceConfidence
    ..min_tracking_confidence = options.minTrackingConfidence;
}

/// Google's Hand Landmarker on its worker isolate.
final class NativeHandLandmarker
    implements NativeVisionTask<HandLandmarkerResult> {
  /// Creates the task with the requested delegate and mode.
  NativeHandLandmarker(HandLandmarkerOptions options)
    : _gpu = options.delegate == Delegate.gpu {
    using((arena) {
      final native = arena<mp.MpHandLandmarkerOptions>();
      fillHandLandmarkerOptions(arena, native.ref, options);
      final output = arena<mp.MpHandLandmarkerPtr>();
      checkVisionCreate(
        (error) => mp.MpHandLandmarkerCreate(native, output, error),
        gpu: _gpu,
      );
      _task = output.value;
    });
  }
  final bool _gpu;
  mp.MpHandLandmarkerPtr _task = nullptr;

  /// Runs one IMAGE or VIDEO request and copies every result.
  @override
  HandLandmarkerResult process(VisionTaskInput input) => runVisionRequest(
    input,
    gpu: _gpu,
    allocate: (arena) => arena<mp.MpHandLandmarkerResult>(),
    image: (image, processing, result, error) =>
        mp.MpHandLandmarkerDetectImage(_task, image, processing, result, error),
    video: (image, processing, timestamp, result, error) =>
        mp.MpHandLandmarkerDetectForVideo(
          _task,
          image,
          processing,
          timestamp,
          result,
          error,
        ),
    closeResult: mp.MpHandLandmarkerCloseResult,
    copy: (request, result) => HandLandmarkerResult(
      handedness: copyVisionCategories(
        result.ref.handedness,
        result.ref.handedness_count,
      ),
      handLandmarks: [
        for (var i = 0; i < result.ref.hand_landmarks_count; i++)
          copyVisionNormalizedLandmarks(result.ref.hand_landmarks[i]),
      ],
      handWorldLandmarks: [
        for (var i = 0; i < result.ref.hand_world_landmarks_count; i++)
          copyVisionWorldLandmarks(result.ref.hand_world_landmarks[i]),
      ],
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
    checkVisionCall((error) => mp.MpHandLandmarkerClose(task, error));
  }
}
