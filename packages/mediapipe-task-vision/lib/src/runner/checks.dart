/// The one set of input checks every vision task runs, on every platform,
/// before a request reaches Google's runtime, so the same call fails the
/// same way everywhere.
library;

import 'package:mediapipe_core/platform_interface.dart'
    show checkStreamTimestamp;

import '../types/vision_types.dart';

/// Validates mode, rotation, timestamps and lifecycle for one task.
final class VisionTaskChecks {
  /// [name] appears in errors.
  VisionTaskChecks(this.name, this.runningMode);

  /// The task's name, as its errors say it.
  final String name;

  /// The mode the task was created in.
  final RunningMode runningMode;

  int? _lastTimestamp;
  bool _disposing = false;

  /// A failure that ended the task; every later call rethrows it.
  Object? failure;

  /// Whether disposal has begun.
  bool get disposing => _disposing;

  /// Rejects every later request.
  void markDisposing() => _disposing = true;

  /// Checks a still-image request.
  void image(int rotationDegrees) {
    _open();
    requireMode(RunningMode.image);
    _rotation(rotationDegrees);
  }

  /// Checks a video request and reserves its timestamp, even if the frame
  /// then fails, so submission order stays monotonic.
  void video(int rotationDegrees, int timestampMilliseconds) {
    _open();
    requireMode(RunningMode.video);
    _rotation(rotationDegrees);
    _timestamp(timestampMilliseconds);
  }

  /// Checks a live stream frame and reserves its timestamp at submission,
  /// whether the frame then runs or is dropped: Google's runtime records the
  /// timestamp before its flow limiter sees the frame. A frame needs a
  /// results listener, since Google's runtime requires one at creation.
  void liveStream(
    int rotationDegrees,
    int timestampMilliseconds, {
    required bool listening,
  }) {
    _open();
    requireMode(RunningMode.liveStream);
    if (!listening) {
      throw StateError(
        'Listen to $name.results before submitting the first frame.',
      );
    }
    _rotation(rotationDegrees);
    _timestamp(timestampMilliseconds);
  }

  /// Checks a request that has no mode of its own, such as a stroke
  /// segmentation.
  void open() => _open();

  void _open() {
    if (_disposing) throw StateError('$name has been disposed.');
    if (failure case final error?) throw error;
  }

  /// Rejects a call that belongs to another running mode.
  void requireMode(RunningMode expected) {
    if (runningMode != expected) {
      throw StateError(
        '$name was created in ${runningMode.name} mode; this method requires '
        '${expected.name} mode.',
      );
    }
  }

  void _timestamp(int timestampMilliseconds) {
    checkStreamTimestamp(timestampMilliseconds, _lastTimestamp);
    _lastTimestamp = timestampMilliseconds;
  }

  void _rotation(int rotationDegrees) {
    if (rotationDegrees % 90 != 0 ||
        rotationDegrees < -0x80000000 ||
        rotationDegrees > 0x7fffffff) {
      throw ArgumentError.value(
        rotationDegrees,
        'rotationDegrees',
        'Must be a multiple of 90 that fits a C int',
      );
    }
  }
}
