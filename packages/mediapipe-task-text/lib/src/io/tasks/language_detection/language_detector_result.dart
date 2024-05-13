// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ffi';
import 'package:mediapipe_core/io.dart';
import 'package:mediapipe_text/interface.dart';
import '../../third_party/mediapipe/generated/mediapipe_text_bindings.dart'
    as bindings;

/// {@macro LanguageDetectionResult}
class LanguageDetectorResult extends BaseLanguageDetectorResult
    with IOTaskResult {
  /// {@macro LanguageDetectionResult}
  LanguageDetectorResult({
    required Iterable<LanguagePrediction> predictions,
  })  : _predictions = predictions,
        _pointer = null;

  /// {@template LanguageDetectorResult.native}
  /// Initializes a [LanguageDetectorResult] instance as a wrapper around native
  /// memory.
  ///
  /// See also:
  ///  * [TextEmbedderExecutor.embed] where this is called.
  /// {@endtemplate}
  LanguageDetectorResult.native(this._pointer);

  final Pointer<bindings.LanguageDetectorResult>? _pointer;

  Iterable<LanguagePrediction>? _predictions;
  @override
  Iterable<LanguagePrediction> get predictions =>
      _predictions ??= _getpredictions();
  Iterable<LanguagePrediction> _getpredictions() {
    if (_pointer.isNullOrNullPointer) {
      throw Exception(
        'Could not determine value for LanguageDetectorResult.predictions',
      );
    }
    return LanguagePrediction.fromNativeArray(
      _pointer!.ref.predictions,
      _pointer.ref.predictions_count,
    );
  }
}

/// {@macro LanguagePrediction}
class LanguagePrediction extends BaseLanguagePrediction {
  /// {@macro LanguagePrediction}
  LanguagePrediction({
    required String languageCode,
    required double probability,
  })  : _languageCode = languageCode,
        _probability = probability,
        _pointer = null;

  /// Initializes a [LanguagePrediction] instance as a wrapper around native
  /// memory.
  ///
  /// {@macro Container.memoryManagement}
  LanguagePrediction.native(this._pointer);

  final Pointer<bindings.LanguageDetectorPrediction>? _pointer;

  String? _languageCode;

  @override
  String get languageCode => _languageCode ??= _getLanguageCode();
  String _getLanguageCode() {
    if (_pointer.isNullOrNullPointer) {
      throw Exception(
        'Could not determine value for '
        'LanguagePrediction.languageCode',
      );
    }
    if (_pointer!.ref.language_code.isNullPointer) {
      throw Exception('Corrupted memory in LanguagePrediction');
    }
    return _pointer.ref.language_code.toDartString();
  }

  double? _probability;
  @override
  double get probability => _probability ??= _getProbability();
  double _getProbability() {
    if (_pointer.isNullOrNullPointer) {
      throw Exception(
        'Could not determine value for '
        'LanguageDetector.probability',
      );
    }
    return _pointer!.ref.probability;
  }

  /// Accepts a pointer to a list of structs, and a count representing the length
  /// of the list, and returns a list of pure-Dart [Category] instances.
  static Iterable<LanguagePrediction> fromNativeArray(
    Pointer<bindings.LanguageDetectorPrediction> structs,
    int count,
  ) sync* {
    for (int i = 0; i < count; i++) {
      yield LanguagePrediction.native(structs + i);
    }
  }
}
