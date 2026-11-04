import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:mediapipe_core/mediapipe_core.dart';

import '../third_party/mediapipe/vision_bindings.dart' as mp;
import '../runner/native_interface.dart';
import '../types/options.dart';
import '../types/results.dart';
import 'native_vision_task.dart';

/// Google's Image Embedder on its worker isolate.
final class NativeImageEmbedder
    implements NativeVisionTask<ImageEmbedderResult> {
  /// Creates the task with the requested delegate and mode.
  NativeImageEmbedder(ImageEmbedderOptions options)
    : _gpu = options.delegate == Delegate.gpu {
    using((arena) {
      final native = arena<mp.ImageEmbedderOptions>();
      setVisionBaseOptions(
        arena,
        native.ref.base_options,
        options,
        officialGpu: true,
      );
      native.ref.running_mode = nativeRunningMode(options.runningMode);
      native.ref.embedder_options
        ..l2_normalize = options.l2Normalize
        ..quantize = options.quantize;
      final output = arena<mp.MpImageEmbedderPtr>();
      checkVisionCreate(
        (error) => mp.MpImageEmbedderCreate(native, output, error),
        gpu: _gpu,
      );
      _task = output.value;
    });
  }
  final bool _gpu;
  mp.MpImageEmbedderPtr _task = nullptr;

  /// Runs one IMAGE or VIDEO request and copies every result.
  @override
  ImageEmbedderResult process(VisionTaskInput input) => runVisionRequest(
    input,
    gpu: _gpu,
    allocate: (arena) => arena<mp.MpEmbeddingResult>(),
    image: (image, processing, result, error) =>
        mp.MpImageEmbedderEmbedImage(_task, image, processing, result, error),
    video: (image, processing, timestamp, result, error) =>
        mp.MpImageEmbedderEmbedForVideo(
          _task,
          image,
          processing,
          timestamp,
          result,
          error,
        ),
    closeResult: mp.MpImageEmbedderCloseResult,
    copy: (request, result) => ImageEmbedderResult(
      embeddings: [
        for (var i = 0; i < result.ref.embeddings_count; i++)
          copyVisionEmbedding(result.ref.embeddings[i]),
      ],
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
    checkVisionCall((error) => mp.MpImageEmbedderClose(task, error));
  }
}
