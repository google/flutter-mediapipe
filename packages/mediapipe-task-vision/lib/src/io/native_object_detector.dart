import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_core/native_structs.dart' show nativeStrings;

import '../third_party/mediapipe/vision_bindings.dart' as mp;
import '../runner/native_interface.dart';
import '../types/options.dart';
import '../types/results.dart';
import 'native_vision_task.dart';

/// Google's Object Detector on its worker isolate.
final class NativeObjectDetector
    implements NativeVisionTask<ObjectDetectorResult> {
  /// Creates the task with the requested delegate and mode.
  NativeObjectDetector(ObjectDetectorOptions options)
    : _gpu = options.delegate == Delegate.gpu {
    using((arena) {
      final native = arena<mp.MpObjectDetectorOptions>();
      setVisionBaseOptions(
        arena,
        native.ref.base_options,
        options,
        officialGpu: true,
      );
      native.ref
        ..running_mode = nativeRunningMode(options.runningMode)
        ..max_results = options.maxResults
        ..score_threshold = options.scoreThreshold
        ..category_allowlist = nativeStrings(arena, options.categoryAllowlist)
        ..category_allowlist_count = options.categoryAllowlist.length
        ..category_denylist = nativeStrings(arena, options.categoryDenylist)
        ..category_denylist_count = options.categoryDenylist.length;
      if (options.displayNamesLocale case final locale?) {
        native.ref.display_names_locale = locale
            .toNativeUtf8(allocator: arena)
            .cast();
      }
      final output = arena<mp.MpObjectDetectorPtr>();
      checkVisionCreate(
        (error) => mp.MpObjectDetectorCreate(native, output, error),
        gpu: _gpu,
      );
      _task = output.value;
    });
  }
  final bool _gpu;
  mp.MpObjectDetectorPtr _task = nullptr;

  /// Runs one IMAGE or VIDEO request and copies every result.
  @override
  ObjectDetectorResult process(VisionTaskInput input) => runVisionRequest(
    input,
    gpu: _gpu,
    allocate: (arena) => arena<mp.MpObjectDetectorResult>(),
    image: (image, processing, result, error) =>
        mp.MpObjectDetectorDetectImage(_task, image, processing, result, error),
    video: (image, processing, timestamp, result, error) =>
        mp.MpObjectDetectorDetectForVideo(
          _task,
          image,
          processing,
          timestamp,
          result,
          error,
        ),
    closeResult: mp.MpObjectDetectorCloseResult,
    copy: (request, result) => ObjectDetectorResult(
      imageWidth: mp.MpImageGetWidth(request.image),
      imageHeight: mp.MpImageGetHeight(request.image),
      timestampMilliseconds: request.timestamp,
      detections: [
        for (var i = 0; i < result.ref.detections_count; i++)
          copyVisionDetection(result.ref.detections[i]),
      ],
    ),
  );

  @override
  void close() {
    if (_task == nullptr) return;
    final task = _task;
    _task = nullptr;
    checkVisionCall((error) => mp.MpObjectDetectorClose(task, error));
  }
}
