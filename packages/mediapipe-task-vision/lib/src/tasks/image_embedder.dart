import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_core/platform_interface.dart' as core;

import '../capabilities.dart';
import '../runner/native_tasks.dart';
import '../runner/vision_task_runner.dart';
import '../types/options.dart';
import '../types/results.dart';
import '../types/vision_types.dart';
import '../vision_task_backend.dart';

/// Google's Image Embedder: one vector per model head.
///
/// One class on every platform. Google's native runtime serves it on a
/// worker isolate on Android, iOS, macOS, Linux and Windows; its browser
/// runtime serves it through the registered web plugin.
///
/// ```dart
/// final task = await ImageEmbedder.create(
///   ImageEmbedderOptions(model: VisionModels.imageEmbedder),
/// );
/// final result = await task.embed(VisionImage.fromFile('photo.jpg'));
/// await task.dispose();
/// ```
/// Calls run one at a time, in call order. A `Future` cannot cancel native
/// work; `dispose()` waits for work already accepted and is idempotent.
final class ImageEmbedder implements VisionTask {
  ImageEmbedder._(this._task, this.delegate);
  final VisionTaskRunner<ImageEmbedderResult> _task;

  @override
  final Delegate delegate;

  @override
  RunningMode get runningMode => _task.runningMode;

  /// Resolves the model and opens Google's task off the calling isolate.
  static Future<ImageEmbedder> create(ImageEmbedderOptions options) async {
    final runner = await VisionTaskRunner.open(
      options,
      name: 'ImageEmbedder',
      backend: imageEmbedderBackendFactory,
      capabilities: queryImageEmbedderCapabilities,
      native: nativeImageEmbedder,
    );
    final task = ImageEmbedder._(runner, options.delegate);
    if (runner.overlayBackend case final overlay?) {
      overlayBackends[task] = overlay;
    }
    return task;
  }

  /// Embeds a still image, or its [regionOfInterest], with Google's
  /// preprocessing. [rotationDegrees] is clockwise and a multiple of 90.
  Future<ImageEmbedderResult> embed(
    VisionImage image, {
    int rotationDegrees = 0,
    VisionRegionOfInterest? regionOfInterest,
  }) => _task.image(image, rotationDegrees, regionOfInterest: regionOfInterest);

  /// Embeds a video frame. Requires [RunningMode.video]; timestamps are
  /// nonnegative milliseconds that strictly increase in call order.
  Future<ImageEmbedderResult> embedForVideo(
    VisionImage image, {
    required int timestampMilliseconds,
    int rotationDegrees = 0,
    VisionRegionOfInterest? regionOfInterest,
  }) => _task.video(
    image,
    rotationDegrees,
    timestampMilliseconds,
    regionOfInterest: regionOfInterest,
  );

  /// Embeds a camera frame in [RunningMode.liveStream] and returns at once;
  /// the result arrives on [results]. As in Google's runtime, one frame runs
  /// at a time and the newest one waits: a frame submitted while another
  /// waits replaces it, and [droppedFrames] counts the replaced ones.
  /// Timestamps are nonnegative milliseconds that strictly increase in call
  /// order, and a dropped frame's timestamp stays reserved. A failed check
  /// throws here.
  void embedAsync(
    VisionImage image, {
    required int timestampMilliseconds,
    int rotationDegrees = 0,
    VisionRegionOfInterest? regionOfInterest,
  }) => _task.liveStream(
    image,
    rotationDegrees,
    timestampMilliseconds,
    regionOfInterest: regionOfInterest,
  );

  /// The result of each frame [embedAsync] runs, in timestamp order. Listen
  /// before the first frame. One subscription: pausing buffers results and
  /// cancelling discards later ones. A failure arrives as a [TaskException],
  /// ends the stream and fails every later call. `dispose()` delivers the
  /// frame in flight and the waiting one, then closes the stream. Live
  /// stream mode only.
  Stream<ImageEmbedderResult> get results => _task.results;

  /// Frames [embedAsync] accepted but never ran; always 0 in the other modes.
  int get droppedFrames => _task.droppedFrames;

  /// Cosine similarity of two embeddings of the same representation and
  /// size, as Google's API computes it, in Dart so every platform agrees.
  /// Quantized bytes are read as signed 8-bit values.
  static double cosineSimilarity(Embedding first, Embedding second) =>
      core.cosineSimilarity(first, second);

  @override
  Future<void> dispose() => _task.dispose();
}
