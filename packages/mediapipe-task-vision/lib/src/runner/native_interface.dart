/// What the task runner needs from Google's native runtime, declared without
/// `dart:ffi` or `dart:isolate` so every platform compiles it.
library;

import '../types/vision_types.dart';
import 'checks.dart';

/// Input transported to a native task's worker without sharing native
/// pointers: the image, its rotation, the timestamp of a VIDEO or live stream
/// frame and the region of interest of the tasks that accept one.
typedef VisionTaskInput = (VisionImage, int, int?, VisionRegionOfInterest?);

/// Google's native task, created, used and closed on its worker isolate only.
abstract interface class NativeVisionTask<R> {
  /// Processes one input and returns an owned Dart result.
  R process(VisionTaskInput input);

  /// Closes idempotently, including after a failed call.
  void close();
}

/// Google's native task behind a worker, as the runner drives it.
abstract interface class NativeTaskRunner<R> {
  /// The checks every request gets; a live stream applies them itself, when
  /// each frame is submitted.
  VisionTaskChecks get checks;

  /// Runs a still image.
  Future<R> processImage(
    VisionImage image,
    int rotationDegrees,
    VisionRegionOfInterest? regionOfInterest,
  );

  /// Runs a video frame.
  Future<R> processVideo(
    VisionImage image,
    int rotationDegrees,
    int timestampMilliseconds,
    VisionRegionOfInterest? regionOfInterest,
  );

  /// Runs a live stream frame, whose checks passed when it was submitted.
  Future<R> processLiveFrame(VisionTaskInput input);

  /// Drains queued requests and releases the task exactly once.
  Future<void> dispose();
}
