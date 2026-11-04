/// A task on the browser adapter (Google's JavaScript runtime): the shared
/// checks, then the backend, in submission order.
library;

import '../types/vision_types.dart';
import '../vision_task_backend.dart';
import 'checks.dart';
import 'live_stream.dart';

/// Validation and ordering for every task that runs through a backend.
final class SdkVisionTask<R> {
  /// Wraps [_backend]; [name] appears in errors.
  SdkVisionTask(this._backend, RunningMode runningMode, {required String name})
    : _checks = VisionTaskChecks(name, runningMode);

  final VisionTaskBackend<R> _backend;
  final VisionTaskChecks _checks;
  Future<void>? _disposing;

  /// The backend's browser overlay, when it draws.
  VisionTaskOverlayBackend? get overlayBackend => switch (_backend) {
    final VisionTaskOverlayBackend overlay => overlay,
    _ => null,
  };

  /// IMAGE inference; [regionOfInterest] only for the tasks that accept one.
  Future<R> image(
    VisionImage image, {
    int rotationDegrees = 0,
    VisionRegionOfInterest? regionOfInterest,
  }) async {
    _checks.image(rotationDegrees);
    return _backend.detect(
      image,
      rotationDegrees,
      null,
      regionOfInterest: regionOfInterest,
    );
  }

  /// VIDEO inference with a strictly increasing timestamp.
  Future<R> video(
    VisionImage image, {
    required int timestampMilliseconds,
    int rotationDegrees = 0,
    VisionRegionOfInterest? regionOfInterest,
  }) async {
    _checks.video(rotationDegrees, timestampMilliseconds);
    return _backend.detect(
      image,
      rotationDegrees,
      timestampMilliseconds,
      regionOfInterest: regionOfInterest,
    );
  }

  /// The checks every request gets; a live stream applies them itself, when
  /// each frame is submitted.
  VisionTaskChecks get checks => _checks;

  /// Runs a live stream frame, whose checks passed when it was submitted.
  Future<R> liveFrame(LiveFrame frame) {
    final (image, rotationDegrees, timestampMilliseconds, region) = frame;
    return _backend.detect(
      image,
      rotationDegrees,
      timestampMilliseconds,
      regionOfInterest: region,
    );
  }

  /// Finishes queued requests and releases the task; repeated calls are safe.
  Future<void> dispose() {
    _checks.markDisposing();
    return _disposing ??= _backend.dispose();
  }
}
