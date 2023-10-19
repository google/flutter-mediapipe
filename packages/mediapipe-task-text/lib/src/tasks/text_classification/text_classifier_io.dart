import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:logging/logging.dart';
import 'package:mediapipe_core/mediapipe_core.dart';

import 'text_classifier.dart';
import 'containers/containers.dart';
import '../../mediapipe_text_bindings.dart' as bindings;

final _log = Logger('TextClassifier');

/// TextClassifier implementation able to use FFI and `dart:io`.
class TextClassifier extends BaseTextClassifier {
  TextClassifier({required super.options});

  @override
  TextClassifierResult classify(String text) {
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
    TextClassifierResult.freeStruct(resultsPtr);
    return result;
  }
}
