// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_text/mediapipe_text.dart';
import '../../third_party/mediapipe/generated/mediapipe_text_bindings.dart'
    as bindings;

final _log = Logger('TextClassifierExecutor');

/// Actual executor for the text classification task.
@visibleForTesting
class TextClassifierExecutor {
  /// Generative constructor.
  TextClassifierExecutor(this.options);

  /// Configuration object for tasks completed by this classifier.
  final TextClassifierOptions options;

  Pointer<Void>? _textClassifierPointer;
  Pointer<bindings.TextClassifierOptions>? _optionsPtr;
  Pointer<bindings.TextClassifierResult>? _resultsPtr;
  Pointer<Pointer<Char>>? _createErrorMessage;
  Pointer<Pointer<Char>>? _classifyErrorMessage;
  Pointer<Pointer<Char>>? _closeErrorMessage;

  /// Pointer to the classifier in C memory, used to verify correct disposal.
  @visibleForTesting
  Pointer<Void>? get textClassifierPointer => _textClassifierPointer;

  /// Pointer to the classifier options in C memory, used to verify correct
  /// disposal.
  @visibleForTesting
  Pointer<bindings.TextClassifierOptions>? get optionsPtr => _optionsPtr;

  /// Pointer to the classification results in C memory, used to verify correct
  /// disposal.
  @visibleForTesting
  Pointer<bindings.TextClassifierResult>? get resultsPtr => _resultsPtr;

  /// Pointer to a possible error message in C memory for creating the
  /// classifier, used to verify correct disposal.
  @visibleForTesting
  Pointer<Pointer<Char>>? get createErrorMessage => _createErrorMessage;

  /// Pointer to a possible error message in C memory for classification, used
  /// to verify correct disposal.
  @visibleForTesting
  Pointer<Pointer<Char>>? get classifyErrorMessage => _classifyErrorMessage;

  /// Pointer to a possible error message in C memory for closing the classifer,
  /// used to verify correct disposal.
  @visibleForTesting
  Pointer<Pointer<Char>>? get closeErrorMessage => _closeErrorMessage;

  /// Sends a `String` value to MediaPipe for classification. Blocks the main
  /// event loop for the duration of the task, so use this with caution.
  TextClassifierResult classify(String text) {
    _createClassifier();
    _classifyString(text);
    return _processResult();
  }

  /// Creates a TextClassifier in C memory if one is not already on hand.
  void _createClassifier() {
    if (isNotNullOrNullPointer(_textClassifierPointer)) return;

    // Allocate and hydrate the configuration object
    _optionsPtr = options.toStruct();
    _createErrorMessage = calloc<Pointer<Char>>();
    _textClassifierPointer = bindings.text_classifier_create(
      _optionsPtr!,
      _createErrorMessage!,
    );
    _handleErrorMessage(_createErrorMessage!);
    _createErrorMessage = null;
  }

  // Performs the actual classification.
  void _classifyString(String text) {
    _resultsPtr = calloc<bindings.TextClassifierResult>();

    // Actually classify the text
    _log.fine('Classifying $text');
    _classifyErrorMessage = calloc<Pointer<Char>>();
    final classificationStatus = bindings.text_classifier_classify(
      _textClassifierPointer!,
      prepareString(text),
      _resultsPtr!,
      _classifyErrorMessage!,
    );
    _handleErrorMessage(_classifyErrorMessage!, classificationStatus);
    _classifyErrorMessage = null;
  }

  /// Converts the result from classification into a pure-Dart
  /// [TextClassificationResult] object.
  TextClassifierResult _processResult() {
    // Convert the results into pure-Dart objects and free all memory
    final result = TextClassifierResult.structToDart(_resultsPtr!.ref);
    _log.fine('Text classification result: $result');
    bindings.text_classifier_close_result(_resultsPtr!);
    _resultsPtr = null;
    return result;
  }

  /// Throws an exception if the [errorMessage] is non-empty.
  ///
  /// Also frees the memory backing [errorMessage], meaning that calling this
  /// method completely handles the potential error.
  void _handleErrorMessage(Pointer<Pointer<Char>> errorMessage, [int? status]) {
    String? exception;
    if (errorMessage.isNotNullPointer && errorMessage[0].isNotNullPointer) {
      final dartErrorMessage = toDartStrings(errorMessage, 1);
      _log.severe('dartErrorMessage: $dartErrorMessage');
      exception = status == null
          ? 'Error: $dartErrorMessage'
          : 'Error: Status $status :: $dartErrorMessage';
    }
    calloc.free(errorMessage[0]);
    calloc.free(errorMessage);
    if (exception != null) {
      throw Exception(exception);
    }
  }

  /// Releases all pointers to objects held in C memory.
  void close() {
    if (isNotNullOrNullPointer(_textClassifierPointer)) {
      _closeErrorMessage = calloc<Pointer<Char>>();
      final closingStatus = bindings.text_classifier_close(
        _textClassifierPointer!,
        _closeErrorMessage!,
      );
      _textClassifierPointer = null;
      _handleErrorMessage(_closeErrorMessage!, closingStatus);
      _closeErrorMessage = null;
    }
    if (isNotNullOrNullPointer(_optionsPtr)) {
      TextClassifierOptions.freeStruct(_optionsPtr!);
      _optionsPtr = null;
    }
  }
}
