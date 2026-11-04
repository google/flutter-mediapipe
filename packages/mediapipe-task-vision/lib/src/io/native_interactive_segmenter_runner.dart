import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_core/task_worker.dart';

import '../types/options.dart';
import '../types/strokes.dart';
import '../types/vision_types.dart';
import '../vision_task_backend.dart';
import 'native_interactive_segmenter.dart';

/// Google's stateful MagicTouch segmenter on a persistent worker isolate:
/// the image and stroke histories travel to the worker in submission order,
/// where Google's vision library keeps the session, on Android, iOS, macOS
/// and Linux.
final class NativeInteractiveSegmenterRunner
    implements InteractiveSegmenterBackend {
  NativeInteractiveSegmenterRunner._();

  final _worker = TaskWorker<Object, ConfidenceMask?, Never>(
    'InteractiveSegmenter',
  );

  /// Loads the task bundle off the calling isolate.
  static Future<NativeInteractiveSegmenterRunner> open(
    InteractiveSegmenterOptions options,
  ) async {
    final runner = NativeInteractiveSegmenterRunner._();
    await runner._worker.start(options, NativeInteractiveSegmenter.new);
    return runner;
  }

  @override
  Future<void> setImage(VisionImage image) => _worker.run(image);

  @override
  Future<ConfidenceMask> segment(List<Stroke> strokes) async =>
      (await _worker.run(strokes))!;

  @override
  Future<void> dispose() => _worker.dispose();
}
