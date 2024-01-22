import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

import 'package:mediapipe_core/mediapipe_core.dart';
import '../../../third_party/mediapipe/generated/mediapipe_text_bindings.dart'
    as bindings;

/// {@template TextEmbedderOptions}
/// Embedder options for MediaPipe C embedding extraction tasks.
/// {@endtemplate}
class TextEmbedderOptions {
  /// {@macro TextEmbedderOptions}
  const TextEmbedderOptions({
    required this.baseOptions,
    required this.embedderOptions,
  });

  /// Convenience constructor that looks for the model asset at the given file
  /// system location.
  ///
  /// Note: Because this constructor assumes access to the file system, it is
  /// not suitable for Flutter Web projects.
  factory TextEmbedderOptions.fromAssetPath(
    String assetPath, {
    EmbedderOptions embedderOptions = const EmbedderOptions(),
  }) {
    assert(!kIsWeb, 'fromAssetPath cannot be used on the web');
    return TextEmbedderOptions(
      baseOptions: BaseOptions.path(assetPath),
      embedderOptions: embedderOptions,
    );
  }

  /// Convenience constructor that uses a model existing in memory.
  ///
  /// Note: This constructor can be used on any target platform.
  factory TextEmbedderOptions.fromAssetBuffer(
    Uint8List assetBuffer, {
    EmbedderOptions embedderOptions = const EmbedderOptions(),
  }) =>
      TextEmbedderOptions(
        baseOptions: BaseOptions.memory(assetBuffer),
        embedderOptions: embedderOptions,
      );

  /// Container storing options universal to all MediaPipe tasks (namely, which
  /// model to use for the task).
  final BaseOptions baseOptions;

  /// Container storing options universal to all MediaPipe embedders.
  final EmbedderOptions embedderOptions;

  /// Converts this [TextEmbedderOptions] instance into its C representation.
  Pointer<bindings.TextEmbedderOptions> toStruct() {
    final struct = calloc<bindings.TextEmbedderOptions>();

    struct.ref.base_options = baseOptions.toStruct().ref;
    struct.ref.embedder_options = embedderOptions.toStruct().ref;

    return struct;
  }
}
