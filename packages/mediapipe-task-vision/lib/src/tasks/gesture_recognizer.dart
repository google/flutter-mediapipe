import 'package:mediapipe_core/mediapipe_core.dart';

import '../capabilities.dart';
import '../runner/native_tasks.dart';
import '../runner/vision_task_runner.dart';
import '../types/options.dart';
import '../types/results.dart';
import '../types/vision_types.dart';
import '../vision_task_backend.dart';

/// Google's Gesture Recognizer: the gestures and landmarks of each hand.
///
/// One class on every platform. Google's native runtime serves it on a
/// worker isolate on Android, iOS, macOS, Linux and Windows; its browser
/// runtime serves it through the registered web plugin.
///
/// ```dart
/// final task = await GestureRecognizer.create(
///   GestureRecognizerOptions(model: VisionModels.gestureRecognizer),
/// );
/// final result = await task.recognize(VisionImage.fromFile('photo.jpg'));
/// await task.dispose();
/// ```
/// Calls run one at a time, in call order. A `Future` cannot cancel native
/// work; `dispose()` waits for work already accepted and is idempotent.
final class GestureRecognizer implements VisionTask {
  GestureRecognizer._(this._task, this.delegate);
  final VisionTaskRunner<GestureRecognizerResult> _task;

  @override
  final Delegate delegate;

  @override
  RunningMode get runningMode => _task.runningMode;

  /// Resolves the model and opens Google's task off the calling isolate.
  static Future<GestureRecognizer> create(
    GestureRecognizerOptions options,
  ) async {
    final runner = await VisionTaskRunner.open(
      options,
      name: 'GestureRecognizer',
      backend: gestureRecognizerBackendFactory,
      capabilities: queryGestureRecognizerCapabilities,
      native: nativeGestureRecognizer,
    );
    final task = GestureRecognizer._(runner, options.delegate);
    if (runner.overlayBackend case final overlay?) {
      overlayBackends[task] = overlay;
    }
    return task;
  }

  /// Recognizes gestures in a still image. [rotationDegrees] is clockwise
  /// and a multiple of 90.
  Future<GestureRecognizerResult> recognize(
    VisionImage image, {
    int rotationDegrees = 0,
  }) => _task.image(image, rotationDegrees);

  /// Recognizes gestures in a video frame. Requires [RunningMode.video];
  /// timestamps are nonnegative milliseconds that strictly increase in call
  /// order.
  Future<GestureRecognizerResult> recognizeForVideo(
    VisionImage image, {
    required int timestampMilliseconds,
    int rotationDegrees = 0,
  }) => _task.video(image, rotationDegrees, timestampMilliseconds);

  /// Recognizes gestures in a camera frame in [RunningMode.liveStream] and
  /// returns at once; the result arrives on [results]. As in Google's runtime,
  /// one frame runs at a time and the newest one waits: a frame submitted while
  /// another waits replaces it, and [droppedFrames] counts the replaced ones.
  /// Timestamps are nonnegative milliseconds that strictly increase in call
  /// order, and a dropped frame's timestamp stays reserved. A failed check
  /// throws here.
  void recognizeAsync(
    VisionImage image, {
    required int timestampMilliseconds,
    int rotationDegrees = 0,
  }) => _task.liveStream(image, rotationDegrees, timestampMilliseconds);

  /// The result of each frame [recognizeAsync] runs, in timestamp order. Listen
  /// before the first frame. One subscription: pausing buffers results and
  /// cancelling discards later ones. A failure arrives as a [TaskException],
  /// ends the stream and fails every later call. `dispose()` delivers the
  /// frame in flight and the waiting one, then closes the stream. Live
  /// stream mode only.
  Stream<GestureRecognizerResult> get results => _task.results;

  /// Frames [recognizeAsync] accepted but never ran; always 0 in the other
  /// modes.
  int get droppedFrames => _task.droppedFrames;

  @override
  Future<void> dispose() => _task.dispose();
}
