import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_core/native_structs.dart' show nativeString;

import '../third_party/mediapipe/vision_bindings.dart' as mp;
import '../runner/native_interface.dart';
import '../types/options.dart';
import '../types/results.dart';
import 'native_vision_task.dart';

/// Google's Image Segmenter on its worker isolate.
final class NativeImageSegmenter
    implements NativeVisionTask<ImageSegmenterResult> {
  /// Creates the task with the requested delegate, mode and masks.
  NativeImageSegmenter(ImageSegmenterOptions options)
    : _gpu = options.delegate == Delegate.gpu {
    using((arena) {
      final native = arena<mp.MpImageSegmenterOptions>();
      setVisionBaseOptions(
        arena,
        native.ref.base_options,
        options,
        officialGpu: true,
      );
      native.ref
        ..running_mode = nativeRunningMode(options.runningMode)
        ..output_confidence_masks = options.outputConfidenceMasks
        ..output_category_mask = options.outputCategoryMask;
      // MpImageSegmenterCreate dereferences this pointer unconditionally and
      // segfaults on null, unlike the classifier options, whose C code checks.
      // Google's own bindings always pass a string; see upstream-issues.md
      // UP-009.
      native.ref.display_names_locale = (options.displayNamesLocale ?? '')
          .toNativeUtf8(allocator: arena)
          .cast();
      final output = arena<mp.MpImageSegmenterPtr>();
      checkVisionCreate(
        (error) => mp.MpImageSegmenterCreate(native, output, error),
        gpu: _gpu,
      );
      _task = output.value;
      _labels = _readLabels(arena);
    });
  }
  final bool _gpu;
  mp.MpImageSegmenterPtr _task = nullptr;
  List<String> _labels = const [];

  /// The model's category order, read once while the task is initialized.
  List<String> _readLabels(Arena arena) {
    final list = arena<mp.MpStringList>();
    checkVisionCall(
      (error) => mp.MpImageSegmenterGetLabels(_task, list, error),
    );
    try {
      return [
        for (var i = 0; i < list.ref.num_strings; i++)
          nativeString(list.ref.strings[i], emptyIsNull: true) ?? '',
      ];
    } finally {
      mp.MpStringListFree(list);
    }
  }

  /// Runs one IMAGE or VIDEO request and copies every result.
  @override
  ImageSegmenterResult process(VisionTaskInput input) => runVisionRequest(
    input,
    gpu: _gpu,
    allocate: (arena) => arena<mp.MpImageSegmenterResult>(),
    image: (image, processing, result, error) =>
        mp.MpImageSegmenterSegmentImage(
          _task,
          image,
          processing,
          result,
          error,
        ),
    video: (image, processing, timestamp, result, error) =>
        mp.MpImageSegmenterSegmentForVideo(
          _task,
          image,
          processing,
          timestamp,
          result,
          error,
        ),
    closeResult: mp.MpImageSegmenterCloseResult,
    copy: (request, result) => copyVisionSegmentation(
      request.arena,
      result.ref,
      request.image,
      request.timestamp,
      labels: _labels,
    ),
  );

  @override
  void close() {
    if (_task == nullptr) return;
    final task = _task;
    _task = nullptr;
    checkVisionCall((error) => mp.MpImageSegmenterClose(task, error));
  }
}
