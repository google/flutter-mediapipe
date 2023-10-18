import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:mediapipe_core/mediapipe_core.dart';
import '../../../mediapipe_text_bindings.dart' as bindings;

class TextClassifierOptions {
  const TextClassifierOptions({
    required this.baseOptions,
    ClassifierOptions? classifierOptions,
  }) : classifierOptions = classifierOptions ?? const ClassifierOptions();

  /// Convenience constructor that looks for the model asset at the given file
  /// system location.
  ///
  /// Note: Because this constructor assumes access to the file system, it is
  /// not suitable for Flutter Web projects.
  factory TextClassifierOptions.fromAssetPath(
    String assetPath, {
    ClassifierOptions? classifierOptions,
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
    ClassifierOptions? classifierOptions,
  }) =>
      TextClassifierOptions(
        baseOptions: BaseOptions(modelAssetBuffer: assetBuffer),
        classifierOptions: classifierOptions,
      );

  final BaseOptions baseOptions;
  final ClassifierOptions classifierOptions;

  Pointer<bindings.TextClassifierOptions> toStruct() {
    final struct = calloc<bindings.TextClassifierOptions>();

    struct.ref.base_options = baseOptions.toStruct().ref;
    struct.ref.classifier_options = classifierOptions.toStruct().ref;

    return struct;
  }
}
