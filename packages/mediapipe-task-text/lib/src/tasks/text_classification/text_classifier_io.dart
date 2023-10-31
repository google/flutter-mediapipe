import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:mediapipe_core/mediapipe_core.dart';

import 'text_classifier.dart';
import 'containers/containers.dart';
import '../../mediapipe_text_bindings.dart' as bindings;

final _log = Logger('TextClassifier');

/// TextClassifier implementation able to use FFI and `dart:io`.
class TextClassifier extends BaseTextClassifier {
  /// Generative constructor.
  TextClassifier({required super.options});

  /// Sends a `String` value to MediaPipe for classification. Uses an Isolate
  /// on mobile and desktop, and a web worker on web, to add concurrency and avoid
  /// blocking the UI thread while this task completes.
  ///
  /// See also:
  ///  * [classify_sync] for a synchronous alternative
  @override
  Future<TextClassifierResult> classify(String text) async =>
      compute<String, TextClassifierResult>(classifySync, text);

  /// Sends a `String` value to MediaPipe for classification. Blocks the main
  /// event loop for the duration of the task, so use this with caution.
  ///
  /// See also:
  ///  * [classify] for a concurrent alternative
  @override
  TextClassifierResult classifySync(String text) {
    // Allocate and hydrate the configuration object
    final optionsPtr = options.toStruct();
    _log.finest('optionsPtr: $optionsPtr');
    final classifierPtr = bindings.text_classifier_create(optionsPtr);
    _log.finest('classifierPtr: $classifierPtr');

    // Allocate the container for our results
    final resultsPtr = calloc<bindings.TextClassifierResult>();
    _log.finest('resultsPtr: $resultsPtr');

    // Actually classify the text
    bindings.text_classifier_classify(
      classifierPtr,
      prepareString(text),
      resultsPtr,
    );

    // Convert the results into pure-Dart objects and free all memory
    final result = TextClassifierResult.fromStruct(resultsPtr.ref);
    _log.fine('Text classification result: $result');
    bindings.text_classifier_close(classifierPtr);
    TextClassifierOptions.freeStruct(optionsPtr);
    calloc.free(optionsPtr);
    TextClassifierResult.freeStruct(resultsPtr);
    return result;
  }
}
