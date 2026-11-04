import 'package:mediapipe_core/mediapipe_core.dart';

import '../capabilities.dart';
import '../runner/native_tasks.dart';
import '../runner/vision_task_runner.dart';
import '../types/options.dart';
import '../types/results.dart';
import '../types/vision_types.dart';
import '../vision_task_backend.dart';

/// Google's Face Landmarker: 478 landmarks per face, with optional
/// blendshapes and transformation matrixes.
///
/// One class on every platform. Google's native runtime serves it on a
/// worker isolate on Android, iOS, macOS, Linux and Windows; its browser
/// runtime serves it through the registered web plugin.
///
/// ```dart
/// final task = await FaceLandmarker.create(
///   FaceLandmarkerOptions(model: VisionModels.faceLandmarker),
/// );
/// final result = await task.detect(VisionImage.fromFile('photo.jpg'));
/// await task.dispose();
/// ```
/// Calls run one at a time, in call order. A `Future` cannot cancel native
/// work; `dispose()` waits for work already accepted and is idempotent.
final class FaceLandmarker implements VisionTask {
  FaceLandmarker._(this._task, this.delegate);
  final VisionTaskRunner<FaceLandmarkerResult> _task;

  @override
  final Delegate delegate;

  @override
  RunningMode get runningMode => _task.runningMode;

  /// Resolves the model and opens Google's task off the calling isolate.
  static Future<FaceLandmarker> create(FaceLandmarkerOptions options) async {
    final runner = await VisionTaskRunner.open(
      options,
      name: 'FaceLandmarker',
      backend: faceLandmarkerBackendFactory,
      native: nativeFaceLandmarker,
      capabilities: queryFaceLandmarkerCapabilities,
    );
    final task = FaceLandmarker._(runner, options.delegate);
    if (runner.overlayBackend case final overlay?) {
      overlayBackends[task] = overlay;
    }
    return task;
  }

  /// Locates face landmarks in a still image. [rotationDegrees] is clockwise
  /// and a multiple of 90; Google applies it, and coordinates stay in the
  /// input's frame.
  Future<FaceLandmarkerResult> detect(
    VisionImage image, {
    int rotationDegrees = 0,
  }) => _task.image(image, rotationDegrees);

  /// Locates face landmarks in a video frame. Requires [RunningMode.video];
  /// timestamps are nonnegative milliseconds that strictly increase in call
  /// order, and a submitted timestamp stays reserved even if that frame
  /// fails.
  Future<FaceLandmarkerResult> detectForVideo(
    VisionImage image, {
    required int timestampMilliseconds,
    int rotationDegrees = 0,
  }) => _task.video(image, rotationDegrees, timestampMilliseconds);

  /// Locates face landmarks in a camera frame in [RunningMode.liveStream] and
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
  Stream<FaceLandmarkerResult> get results => _task.results;

  /// Frames [detectAsync] accepted but never ran; always 0 in the other modes.
  int get droppedFrames => _task.droppedFrames;

  @override
  Future<void> dispose() => _task.dispose();
}
