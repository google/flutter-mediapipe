import 'dart:io';

import 'package:mediapipe_core/mediapipe_core.dart';

import '../types/options.dart';
import '../types/vision_types.dart';

/// Bounds the frames Google's macOS GPU path keeps after processing them.
///
/// On macOS a GPU task copies every input image into a new pixel buffer and
/// wraps it in a texture from its OpenGL context's texture cache. MediaPipe
/// flushes that cache only when the context closes, so the task keeps each
/// frame it has processed: 1.2 MB a frame from a 640x480 camera, until an
/// allocation fails inside MediaPipe and aborts the app (UP-032 in
/// upstream-issues.md). Closing the task releases them all.
///
/// A worker counts each image it processes and, once [limitBytes] of frames
/// have gone to the GPU, closes its native task and opens an identical one.
/// It holds the model in memory from the first open, so a reopen still works
/// after the app deletes the model file.
/// On an M4 Max that takes about 20 ms for Face Detector and up to 800 ms for
/// Object Detector, and a video task then starts tracking from a detection.
///
/// Face Detector's budget is half the others'. Since 1.1.0 its GPU inference
/// runs on LiteRT, which on GitHub's virtual Mac (where LiteRT cannot create
/// a Metal residency set) keeps about twice each frame, 2.5 MB at 640x480.
final class GpuFrameBudget {
  /// The budget for a task created with [options]: [limitBytes] when given,
  /// otherwise, for a macOS GPU task, 512 MiB for Face Detector and 1 GiB for
  /// the others, and none elsewhere.
  GpuFrameBudget(VisionTaskOptions options, {int? limitBytes})
    : limitBytes =
          limitBytes ??
          (Platform.isMacOS && options.delegate == Delegate.gpu
              ? (options is FaceDetectorOptions ? 1 << 29 : 1 << 30)
              : null);

  /// Frame bytes after which the task reopens, or null when it never does.
  final int? limitBytes;
  var _bytes = 0;

  /// Counts [image] and reports whether the task should reopen now.
  bool spend(VisionImage image) {
    final limit = limitBytes;
    if (limit == null) return false;
    // MediaPipe converts every image to 4-byte pixels for the GPU. A file's
    // size is known only once MediaPipe decodes it; count a 12 MP photo.
    _bytes += (image.width ?? 4000) * (image.height ?? 3000) * 4;
    if (_bytes < limit) return false;
    _bytes = 0;
    return true;
  }
}
