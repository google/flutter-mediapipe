/// Drawing a task's results into a browser canvas from the task's own worker,
/// without a round trip through Dart.
library;

import 'package:mediapipe_core/mediapipe_core.dart';

import 'types/vision_types.dart';
import 'vision_task_backend.dart';

/// A canvas the browser worker draws a task's landmarks or boxes into.
///
/// Exists on every platform; off the web, or for a task whose runtime does
/// not draw, [attach] throws [RuntimeUnavailableException] and the app keeps
/// its own painter. Disposing the task ends the drawing too.
///
/// ```dart
/// final overlay = await BrowserOverlay.attach(task, canvasElement);
/// overlay.configure(connections: true, points: false, mirrored: true);
/// ```
final class BrowserOverlay {
  BrowserOverlay._(this._backend);
  final VisionTaskOverlayBackend _backend;
  var _detached = false;

  /// Transfers [canvas] (a browser `HTMLCanvasElement`) to [task]'s worker.
  /// The canvas belongs to the worker afterwards and cannot be drawn into
  /// from the page.
  static Future<BrowserOverlay> attach(VisionTask task, Object canvas) async {
    final backend = overlayBackends[task];
    if (backend == null) {
      throw const RuntimeUnavailableException(
        'This task has no browser overlay.',
        fix:
            'Overlays draw in browsers for the landmark and detector tasks; '
            'keep painting results from Dart elsewhere.',
      );
    }
    await backend.attachOverlay(canvas);
    return BrowserOverlay._(backend);
  }

  /// Chooses what the worker draws: the landmark [connections], the landmark
  /// [points], a [mirrored] preview and the canvas [scale] relative to the
  /// frame.
  void configure({
    required bool connections,
    required bool points,
    bool mirrored = false,
    double scale = 1,
  }) {
    if (_detached) throw StateError('BrowserOverlay has been detached.');
    _backend.setOverlayOptions(
      connections: connections,
      points: points,
      mirrored: mirrored,
      scale: scale,
    );
  }

  /// Whether the worker is drawing into the canvas: false after a detach, or
  /// when the browser could not transfer the canvas or drawing failed, in
  /// which case the app's own painter should take over.
  bool get active => !_detached && _backend.overlayActive;

  /// Stops drawing. The canvas stays as it was last drawn; a new canvas can
  /// be attached afterwards.
  Future<void> detach() async {
    if (_detached) return;
    _detached = true;
    await _backend.detachOverlay();
  }
}
