// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:mediapipe_core/interface.dart';

/// Anchor class for all result objects from MediaPipe tasks.
abstract class TaskResult {
  /// {@template TaskResult.dispose}
  /// Releases platform memory if any is held.
  /// {@endtemplate}
  void dispose();
}

/// {@template ClassifierResult}
/// Container for classification results across any MediaPipe task.
/// {@endtemplate}
abstract class BaseClassifierResult extends TaskResult {
  /// {@template ClassifierResult.classifications}
  /// The classification results for each head of the model.
  /// {@endtemplate}
  List<BaseClassifications> get classifications;

  /// Convenience helper for the first [Classifications] object.
  BaseClassifications? get firstClassification =>
      classifications.isNotEmpty ? classifications.first : null;

  @override
  String toString() {
    final classificationStrings =
        classifications.map((cat) => cat.toString()).join(', ');
    return '$runtimeType(classifications=[$classificationStrings])';
  }
}

/// {@template TimestampedClassifierResult}
/// Container for classification results that may describe a slice of time
/// within a larger, streaming data source (.e.g, a video or audio file).
/// {@endtemplate}
mixin TimestampedResult {
  /// The optional timestamp (as a [Duration]) of the start of the chunk of data
  /// corresponding to these results.
  ///
  /// This is only used for classification on time series (e.g. audio
  /// classification). In these use cases, the amount of data to process might
  /// exceed the maximum size that the model can process: to solve this, the
  /// input data is split into multiple chunks starting at different timestamps.
  Duration? get timestamp;
}
