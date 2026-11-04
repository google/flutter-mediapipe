import 'dart:io';

import 'package:mediapipe_core/platform_interface.dart';
import 'package:mediapipe_core/task_worker.dart';

import '../runner/checks.dart';
import '../runner/native_interface.dart';
import '../types/vision_types.dart';
import 'gpu_frame_budget.dart';

/// Google's native task on its own isolate: the shared checks, then requests
/// in submission order, with the task created, used and closed there.
final class VisionTaskWorker<R> implements NativeTaskRunner<R> {
  VisionTaskWorker._(this.checks)
    : _worker = TaskWorker(checks.name, (error) => checks.failure ??= error);

  @override
  final VisionTaskChecks checks;
  final TaskWorker<VisionTaskInput, R, Never> _worker;

  /// Construct the native owner from a top-level factory on a new isolate.
  ///
  /// [reopenAfterBytes] overrides the [GpuFrameBudget] that bounds what
  /// Google's macOS GPU path keeps, so tests can exercise the reopening.
  static Future<VisionTaskWorker<R>> create<R, O extends VisionTaskOptions>(
    O options,
    NativeVisionTask<R> Function(O) factory,
    String name, {
    int? reopenAfterBytes,
  }) async {
    final worker = VisionTaskWorker<R>._(
      VisionTaskChecks(name, options.runningMode),
    );
    await worker._worker.start((
      options,
      factory,
      reopenAfterBytes,
    ), _BudgetedTask<R, O>.new);
    return worker;
  }

  @override
  Future<R> processImage(
    VisionImage image,
    int rotationDegrees,
    VisionRegionOfInterest? regionOfInterest,
  ) async {
    checks.image(rotationDegrees);
    return _worker.run((image, rotationDegrees, null, regionOfInterest));
  }

  @override
  Future<R> processVideo(
    VisionImage image,
    int rotationDegrees,
    int timestampMilliseconds,
    VisionRegionOfInterest? regionOfInterest,
  ) async {
    checks.video(rotationDegrees, timestampMilliseconds);
    return _worker.run((
      image,
      rotationDegrees,
      timestampMilliseconds,
      regionOfInterest,
    ));
  }

  /// A queued frame starts after its checks; the worker may have died since,
  /// which [TaskWorker.run] reports.
  @override
  Future<R> processLiveFrame(VisionTaskInput input) => _worker.run(input);

  @override
  Future<void> dispose() {
    checks.markDisposing();
    return _worker.dispose();
  }
}

/// Google's task on the worker, reopened before the next frame once
/// [GpuFrameBudget] says Google's macOS GPU path has kept enough. A failed
/// reopening fails that frame and every later one.
final class _BudgetedTask<R, O extends VisionTaskOptions>
    extends WorkerTask<VisionTaskInput, R, Never> {
  _BudgetedTask((O, NativeVisionTask<R> Function(O), int?) setup)
    : _options = setup.$1,
      _create = setup.$2,
      _budget = GpuFrameBudget(setup.$1, limitBytes: setup.$3),
      _task = setup.$2(setup.$1) {
    if (_budget.limitBytes != null) _holdModel(_options);
  }

  final O _options;
  final NativeVisionTask<R> Function(O) _create;
  final GpuFrameBudget _budget;
  NativeVisionTask<R> _task;
  var _spent = false;
  Object? _broken;

  @override
  R run(VisionTaskInput input) {
    if (_broken case final error?) throw error;
    if (_spent) {
      _task.close();
      try {
        _task = _create(_options);
      } catch (error) {
        _broken = error;
        rethrow;
      }
      _spent = false;
    }
    try {
      return _task.process(input);
    } finally {
      _spent = _budget.spend(input.$1);
    }
  }

  @override
  void close() => _task.close();
}

/// Reopening reads the model again, but MediaPipe has read it by the time a
/// task exists, so the app may delete the file. Holds it in memory while the
/// file is certainly present: [VisionTaskWorker.create] has not returned.
void _holdModel(VisionTaskOptions options) {
  final path = options.modelPath;
  if (path == null) return;
  try {
    holdModelBytes(options, File(path).readAsBytesSync().asUnmodifiableView());
  } on FileSystemException {
    // MediaPipe read the file a moment ago. If it is unreadable now, reopening
    // reads it again, as without this.
  }
}
