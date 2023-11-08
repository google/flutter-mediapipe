import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:mediapipe_core/mediapipe_core.dart';
import '../../../third_party/mediapipe/generated/mediapipe_text_bindings.dart'
    as bindings;

/// Configuration object for a MediaPipe text classifier.
///
/// See also:
///  * [MediaPipe's TextClassifierOptions documentation](https://developers.google.com/mediapipe/api/solutions/js/tasks-text.textclassifieroptions)
class TextClassifierOptions {
  /// Generative constructor.
  const TextClassifierOptions({
    required this.baseOptions,
    this.classifierOptions = const ClassifierOptions(),
  });

  /// Convenience constructor that looks for the model asset at the given file
  /// system location.
  ///
  /// Note: Because this constructor assumes access to the file system, it is
  /// not suitable for Flutter Web projects.
  factory TextClassifierOptions.fromAssetPath(
    String assetPath, {
    ClassifierOptions classifierOptions = const ClassifierOptions(),
  }) {
    assert(!kIsWeb, 'fromAssetPath cannot be used on the web');
    return TextClassifierOptions(
      baseOptions: BaseOptions(modelAssetPath: assetPath),
      classifierOptions: classifierOptions,
    );
  }

  /// Convenience constructor that uses a model existing in memory.
  ///
  /// Note: This constructor can be used on any target platform.
  factory TextClassifierOptions.fromAssetBuffer(
    Uint8List assetBuffer, {
    ClassifierOptions classifierOptions = const ClassifierOptions(),
  }) =>
      TextClassifierOptions(
        baseOptions: BaseOptions(modelAssetBuffer: assetBuffer),
        classifierOptions: classifierOptions,
      );

  /// Container storing options universal to all MediaPipe tasks (namely, which
  /// model to use for the task).
  final BaseOptions baseOptions;

  /// Container storing options universal to all MediaPipe classifiers.
  final ClassifierOptions classifierOptions;

  /// Converts this [ImageClassifierOptions] instance into its C representation.
  Pointer<bindings.TextClassifierOptions> toStruct() {
    final struct = calloc<bindings.TextClassifierOptions>();

    struct.ref.base_options = baseOptions.toStruct().ref;
    struct.ref.classifier_options = classifierOptions.toStruct().ref;

    return struct;
  }

  /// Releases all C memory held by this [bindings.TextClassifierOptions] struct.
  static void freeStruct(Pointer<bindings.TextClassifierOptions> ptr) {
    BaseOptions.freeStruct(ptr.ref.base_options);
    ClassifierOptions.freeStruct(ptr.ref.classifier_options);
    calloc.free(ptr);
  }
}
