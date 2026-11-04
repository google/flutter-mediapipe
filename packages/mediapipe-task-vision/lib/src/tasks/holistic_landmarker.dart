import 'package:mediapipe_core/mediapipe_core.dart';

import '../capabilities.dart';
import '../runner/native_tasks.dart';
import '../runner/vision_task_runner.dart';
import '../types/options.dart';
import '../types/results.dart';
import '../types/vision_types.dart';
import '../vision_task_backend.dart';

/// Google's Holistic Landmarker: face, pose and hand landmarks of one person.
///
/// One class on every platform. Google's native runtime serves it on a
/// worker isolate on Android, iOS, macOS, Linux and Windows; its browser
/// runtime serves it through the registered web plugin.
///
/// ```dart
/// final task = await HolisticLandmarker.create(
///   HolisticLandmarkerOptions(model: VisionModels.holisticLandmarker),
/// );
/// final result = await task.detect(VisionImage.fromFile('photo.jpg'));
/// await task.dispose();
/// ```
/// Calls run one at a time, in call order. A `Future` cannot cancel native
/// work; `dispose()` waits for work already accepted and is idempotent.
final class HolisticLandmarker implements VisionTask {
  HolisticLandmarker._(this._task, this.delegate);
  final VisionTaskRunner<HolisticLandmarkerResult> _task;

  @override
  final Delegate delegate;

  @override
  RunningMode get runningMode => _task.runningMode;

  /// Resolves the model and opens Google's task off the calling isolate.
  static Future<HolisticLandmarker> create(
    HolisticLandmarkerOptions options,
  ) async {
    final runner = await VisionTaskRunner.open(
      options,
      name: 'HolisticLandmarker',
      backend: holisticLandmarkerBackendFactory,
      capabilities: queryHolisticLandmarkerCapabilities,
      native: nativeHolisticLandmarker,
    );
    final task = HolisticLandmarker._(runner, options.delegate);
    if (runner.overlayBackend case final overlay?) {
      overlayBackends[task] = overlay;
    }
    return task;
  }

  /// Locates face, pose and hand landmarks in a still image.
  /// [rotationDegrees] is clockwise and a multiple of 90.
  Future<HolisticLandmarkerResult> detect(
    VisionImage image, {
    int rotationDegrees = 0,
  }) => _task.image(image, rotationDegrees);

  /// Locates landmarks in a video frame. Requires [RunningMode.video];
  /// timestamps are nonnegative milliseconds that strictly increase in call
  /// order.
  Future<HolisticLandmarkerResult> detectForVideo(
    VisionImage image, {
    required int timestampMilliseconds,
    int rotationDegrees = 0,
  }) => _task.video(image, rotationDegrees, timestampMilliseconds);

  /// Locates landmarks in a camera frame in [RunningMode.liveStream] and
  /// returns at once; the result arrives on [results]. As in Google's runtime,
  /// one frame runs at a time and the newest one waits: a frame submitted while
  /// another waits replaces it, and [droppedFrames] counts the replaced ones.
  /// Timestamps are nonnegative milliseconds that strictly increase in call
  /// order, and a dropped frame's timestamp stays reserved. A failed check
  /// throws here.
  void detectAsync(
    VisionImage image, {
    required int timestampMilliseconds,
    int rotationDegrees = 0,
  }) => _task.liveStream(image, rotationDegrees, timestampMilliseconds);

  /// The result of each frame [detectAsync] runs, in timestamp order. Listen
  /// before the first frame. One subscription: pausing buffers results and
  /// cancelling discards later ones. A failure arrives as a [TaskException],
  /// ends the stream and fails every later call. `dispose()` delivers the
  /// frame in flight and the waiting one, then closes the stream. Live
  /// stream mode only.
  Stream<HolisticLandmarkerResult> get results => _task.results;

  /// Frames [detectAsync] accepted but never ran; always 0 in the other modes.
  int get droppedFrames => _task.droppedFrames;

  @override
  Future<void> dispose() => _task.dispose();
}
