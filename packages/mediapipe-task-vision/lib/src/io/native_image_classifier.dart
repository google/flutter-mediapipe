import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:mediapipe_core/mediapipe_core.dart';

import '../third_party/mediapipe/vision_bindings.dart' as mp;
import '../runner/native_interface.dart';
import '../types/options.dart';
import '../types/results.dart';
import 'native_vision_task.dart';

/// Google's Image Classifier on its worker isolate.
final class NativeImageClassifier
    implements NativeVisionTask<ImageClassifierResult> {
  /// Creates the task with the requested delegate and mode.
  NativeImageClassifier(ImageClassifierOptions options)
    : _gpu = options.delegate == Delegate.gpu {
    using((arena) {
      final native = arena<mp.MpImageClassifierOptions>();
      setVisionBaseOptions(
        arena,
        native.ref.base_options,
        options,
        officialGpu: true,
      );
      native.ref.running_mode = nativeRunningMode(options.runningMode);
      setVisionClassifierOptions(arena, native.ref.classifier_options, options);
      final output = arena<mp.MpImageClassifierPtr>();
      checkVisionCreate(
        (error) => mp.MpImageClassifierCreate(native, output, error),
        gpu: _gpu,
      );
      _task = output.value;
    });
  }
  final bool _gpu;
  mp.MpImageClassifierPtr _task = nullptr;

  /// Runs one IMAGE or VIDEO request and copies every result.
  @override
  ImageClassifierResult process(VisionTaskInput input) => runVisionRequest(
    input,
    gpu: _gpu,
    allocate: (arena) => arena<mp.MpImageClassifierResult>(),
    image: (image, processing, result, error) =>
        mp.MpImageClassifierClassifyImage(
          _task,
          image,
          processing,
          result,
          error,
        ),
    video: (image, processing, timestamp, result, error) =>
        mp.MpImageClassifierClassifyForVideo(
          _task,
          image,
          processing,
          timestamp,
          result,
          error,
        ),
    closeResult: mp.MpImageClassifierCloseResult,
    copy: (request, result) => ImageClassifierResult(
      classifications: copyVisionClassifications(result.ref),
      imageWidth: mp.MpImageGetWidth(request.image),
      imageHeight: mp.MpImageGetHeight(request.image),
      timestampMilliseconds: request.timestamp,
    ),
    region: true,
  );

  @override
  void close() {
    if (_task == nullptr) return;
    final task = _task;
    _task = nullptr;
    checkVisionCall((error) => mp.MpImageClassifierClose(task, error));
  }
}
