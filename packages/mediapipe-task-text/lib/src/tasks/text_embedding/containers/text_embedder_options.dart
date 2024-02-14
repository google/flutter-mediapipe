import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

import 'package:mediapipe_core/mediapipe_core.dart';
import '../../../third_party/mediapipe/generated/mediapipe_text_bindings.dart'
    as bindings;

/// {@template TextEmbedderOptions}
/// Embedder options for MediaPipe C embedding extraction tasks.
/// {@endtemplate}
class TextEmbedderOptions extends TaskOptions<bindings.TextEmbedderOptions> {
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
  @override
  Pointer<bindings.TextEmbedderOptions> toStruct() {
    final ptr = calloc<bindings.TextEmbedderOptions>();
    assignToStruct(ptr.ref);
    return ptr;
  }

  @override
  void assignToStruct(bindings.TextEmbedderOptions struct) {
    baseOptions.assignToStruct(struct.base_options);
    embedderOptions.assignToStruct(struct.embedder_options);
  }

  /// Releases all C memory held by this [bindings.TextEmbedderOptions] struct.
  static void freeStruct(Pointer<bindings.TextEmbedderOptions> ptr) {
    BaseOptions.freeStruct(ptr.ref.base_options);
    EmbedderOptions.freeStruct(ptr.ref.embedder_options);
    calloc.free(ptr);
  }

  @override
  List<Object?> get props => [baseOptions, embedderOptions];
}
