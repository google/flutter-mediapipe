import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_core/task_worker.dart';

import '../third_party/mediapipe/vision_bindings.dart' as mp;
import '../types/options.dart';
import '../types/strokes.dart';
import '../types/vision_types.dart';
import 'native_vision_image.dart' show createVisionImage;
import 'native_vision_task.dart'
    show checkVisionCall, copyVisionConfidenceMask, setVisionBaseOptions;

/// One Interactive Segmenter session, owned by its persistent worker isolate:
/// Google's vision library on Android, iOS, macOS and Linux.
final class NativeInteractiveSegmenter
    extends WorkerTask<Object, ConfidenceMask?, Never> {
  /// Create the official CPU task and acquire its native handle.
  NativeInteractiveSegmenter(InteractiveSegmenterOptions options) {
    if (Platform.isWindows) {
      throw UnsupportedError(
        "Google's Windows library runs the Interactive Segmenter at about 25 "
        'seconds a stroke (upstream-issues.md UP-048), so the package does '
        'not offer it there.',
      );
    }
    if (options.delegate != Delegate.cpu) {
      throw UnsupportedError(
        'Interactive Segmenter supports CPU only. The official macOS runtime '
        'cannot initialize its GPU stroke shader, and Linux GPU is not '
        'validated for this task.',
      );
    }
    using((arena) {
      final native = arena<mp.MpInteractiveSegmenterOptions>();
      setVisionBaseOptions(arena, native.ref.base_options, options);
      final output = arena<mp.MpInteractiveSegmenterPtr>();
      checkVisionCall(
        (error) => mp.MpInteractiveSegmenterCreate(native, output, error),
      );
      _task = output.value;
    });
  }

  mp.MpInteractiveSegmenterPtr _task = nullptr;
  mp.MpImagePtr _image = nullptr;
  bool _hasImage = false;

  /// The worker's requests: an image to hold, or the strokes to segment it
  /// with.
  @override
  ConfidenceMask? run(Object input) {
    if (input is List<Stroke>) return segment(input);
    setImage(input as VisionImage);
    return null;
  }

  /// Replace the image, retaining native input ownership until replacement.
  void setImage(VisionImage input) {
    final next = using(
      (arena) => createVisionImage(
        arena,
        input,
        expandRgbForGpu: false,
        checked: checkVisionCall,
      ),
    );
    try {
      _hasImage = false;
      checkVisionCall(
        (error) => mp.MpInteractiveSegmenterSetImage(_task, next, error),
      );
    } catch (_) {
      mp.MpImageFree(next);
      rethrow;
    }
    if (_image != nullptr) mp.MpImageFree(_image);
    _image = next;
    _hasImage = true;
  }

  /// Submit the full history and copy the returned confidence mask.
  ConfidenceMask segment(List<Stroke> strokes) {
    if (!_hasImage) {
      throw StateError('Call setImage successfully before segment.');
    }
    return using((arena) {
      final native = arena<mp.MpStrokes>();
      final values = arena<mp.MpStroke>(strokes.length);
      native.ref
        ..strokes = values
        ..strokes_count = strokes.length;
      for (var i = 0; i < strokes.length; i++) {
        final stroke = strokes[i];
        final points = arena<mp.MpStrokePoint>(stroke.points.length);
        for (var j = 0; j < stroke.points.length; j++) {
          points[j]
            ..x = stroke.points[j].x
            ..y = stroke.points[j].y;
        }
        values[i]
          ..brush_mode = mp.MpBrushMode.fromValue(stroke.brushMode.nativeValue)
          ..points = points
          ..points_count = stroke.points.length
          ..is_completed = stroke.isCompleted;
      }
      final output = arena<mp.MpImagePtr>();
      try {
        checkVisionCall(
          (error) =>
              mp.MpInteractiveSegmenterSegment(_task, native, output, error),
        );
        if (output.value == nullptr) {
          throw StateError('MediaPipe returned no mask.');
        }
        return copyVisionConfidenceMask(arena, output.value);
      } catch (_) {
        // A native graph failure can persist. Require a fresh successful image
        // before accepting more segmentation; argument errors never reach here.
        _hasImage = false;
        rethrow;
      } finally {
        if (output.value != nullptr) mp.MpImageFree(output.value);
      }
    });
  }

  /// Release the task and retained image exactly once.
  @override
  void close() {
    if (_task == nullptr) return;
    final task = _task;
    _task = nullptr;
    _hasImage = false;
    try {
      checkVisionCall((error) => mp.MpInteractiveSegmenterClose(task, error));
    } finally {
      if (_image != nullptr) mp.MpImageFree(_image);
      _image = nullptr;
    }
  }
}
