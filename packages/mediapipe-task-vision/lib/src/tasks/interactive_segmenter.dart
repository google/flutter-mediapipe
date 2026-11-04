import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_core/platform_interface.dart';

import '../runner/checks.dart';
import '../runner/native_tasks.dart';
import '../types/options.dart';
import '../types/strokes.dart';
import '../types/vision_types.dart';
import '../vision_task_backend.dart';

/// Google's stateful MagicTouch Interactive Segmenter: an image, then the
/// mask of the object a stroke history selects.
///
/// One class on every platform. Google's vision library serves it on a
/// worker isolate on Android, iOS, macOS and Linux; Google's browser runtime
/// serves it through the registered web adapter. Google's Windows library
/// has it too, but runs a stroke in about 25 seconds, so the capability
/// query reports Windows as unavailable (upstream-issues.md UP-048).
///
/// ```dart
/// final task = await InteractiveSegmenter.create(
///   InteractiveSegmenterOptions(model: VisionModels.interactiveSegmenter),
/// );
/// await task.setImage(VisionImage.fromFile('photo.jpg'));
/// final mask = await task.segment([
///   Stroke(
///     brushMode: BrushMode.positive,
///     points: [const NormalizedKeypoint(x: 0.5, y: 0.4)],
///   ),
/// ]);
/// await task.dispose();
/// ```
/// Calls run one at a time, in call order, including calls queued before an
/// earlier one completes. A `Future` cannot cancel native work; `dispose()`
/// waits for work already accepted and is idempotent.
final class InteractiveSegmenter implements VisionTask {
  InteractiveSegmenter._(this._backend, this.delegate)
    : _checks = VisionTaskChecks('InteractiveSegmenter', RunningMode.image);
  final InteractiveSegmenterBackend _backend;
  final VisionTaskChecks _checks;
  Future<void>? _disposing;

  @override
  final Delegate delegate;

  /// Always [RunningMode.image]: the task segments one image at a time.
  @override
  RunningMode get runningMode => RunningMode.image;

  /// Resolves the model and opens Google's task off the calling isolate.
  static Future<InteractiveSegmenter> create(
    InteractiveSegmenterOptions options,
  ) async {
    await resolveTaskModel(options);
    final backend = interactiveSegmenterBackendFactory != null
        ? await interactiveSegmenterBackendFactory!(options)
        : await openNativeInteractiveSegmenter(options);
    return InteractiveSegmenter._(backend, options.delegate);
  }

  /// Replaces the image and resets the stroke session. Strokes submitted
  /// afterwards apply to this image.
  Future<void> setImage(VisionImage image) async {
    _checks.open();
    refuseDeferredImage(image);
    return _backend.setImage(image);
  }

  /// Segments with the full current stroke history, in the image's
  /// normalized coordinates, and returns the selected object's confidence
  /// mask. Submit a shorter history to undo strokes; an empty history is
  /// rejected because Google's graph cannot take it, so clear the overlay in
  /// the app and call [setImage] to start over.
  Future<ConfidenceMask> segment(List<Stroke> strokes) async {
    _checks.open();
    if (strokes.isEmpty || strokes.length > 0xffffffff) {
      throw ArgumentError('Supply at least one stroke.');
    }
    return _backend.segment(List.unmodifiable(strokes));
  }

  @override
  Future<void> dispose() {
    _checks.markDisposing();
    return _disposing ??= _backend.dispose();
  }
}
