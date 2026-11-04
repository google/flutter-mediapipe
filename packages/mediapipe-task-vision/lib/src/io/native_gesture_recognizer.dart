import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:mediapipe_core/mediapipe_core.dart';

import '../third_party/mediapipe/vision_bindings.dart' as mp;
import '../runner/native_interface.dart';
import '../types/options.dart';
import '../types/results.dart';
import 'native_vision_task.dart';

/// [options] as Google's C Gesture Recognizer options, which
/// [NativeGestureRecognizer] creates the task with; the options test reads each
/// field back.
void fillGestureRecognizerOptions(
  Arena arena,
  mp.MpGestureRecognizerOptions native,
  GestureRecognizerOptions options,
) {
  setVisionBaseOptions(arena, native.base_options, options, officialGpu: true);
  native.running_mode = nativeRunningMode(options.runningMode);
  native
    ..num_hands = options.numHands
    ..min_hand_detection_confidence = options.minHandDetectionConfidence
    ..min_hand_presence_confidence = options.minHandPresenceConfidence
    ..min_tracking_confidence = options.minTrackingConfidence;
  setVisionClassifierOptions(
    arena,
    native.canned_gestures_classifier_options,
    options.cannedGesturesClassifierOptions,
  );
  setVisionClassifierOptions(
    arena,
    native.custom_gestures_classifier_options,
    options.customGesturesClassifierOptions,
  );
}

/// Google's Gesture Recognizer on its worker isolate.
final class NativeGestureRecognizer
    implements NativeVisionTask<GestureRecognizerResult> {
  /// Creates the task with the requested delegate and mode.
  NativeGestureRecognizer(GestureRecognizerOptions options)
    : _gpu = options.delegate == Delegate.gpu {
    using((arena) {
      final native = arena<mp.MpGestureRecognizerOptions>();
      fillGestureRecognizerOptions(arena, native.ref, options);
      final output = arena<mp.MpGestureRecognizerPtr>();
      checkVisionCreate(
        (error) => mp.MpGestureRecognizerCreate(native, output, error),
        gpu: _gpu,
      );
      _task = output.value;
    });
  }
  final bool _gpu;
  mp.MpGestureRecognizerPtr _task = nullptr;

  /// Runs one IMAGE or VIDEO request and copies every result.
  @override
  GestureRecognizerResult process(VisionTaskInput input) => runVisionRequest(
    input,
    gpu: _gpu,
    allocate: (arena) => arena<mp.MpGestureRecognizerResult>(),
    image: (image, processing, result, error) =>
        mp.MpGestureRecognizerRecognizeImage(
          _task,
          image,
          processing,
          result,
          error,
        ),
    video: (image, processing, timestamp, result, error) =>
        mp.MpGestureRecognizerRecognizeForVideo(
          _task,
          image,
          processing,
          timestamp,
          result,
          error,
        ),
    closeResult: mp.MpGestureRecognizerCloseResult,
    copy: (request, result) => GestureRecognizerResult(
      gestures: copyVisionCategories(
        result.ref.gestures,
        result.ref.gestures_count,
        // Canned and custom classifiers number their own labels, so the
        // merged index is meaningless. The official bindings report -1.
        index: -1,
      ),
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
    checkVisionCall((error) => mp.MpGestureRecognizerClose(task, error));
  }
}
