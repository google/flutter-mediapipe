// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:mediapipe_core/interface.dart';

/// {@template TextClassifierOptions}
/// Configuration object for a MediaPipe text classifier.
///
/// See also:
///  * [MediaPipe's TextClassifierOptions documentation](https://developers.google.com/mediapipe/api/solutions/js/tasks-text.textclassifieroptions)
/// {@endtemplate}
abstract class BaseTextClassifierOptions extends BaseTaskOptions {
  /// Contains parameter options for how this classifier should behave,
  /// including allow and denylists, thresholds, maximum results, etc.
  ///
  /// See also:
  ///  * [BaseClassifierOptions] for each available field.
  BaseClassifierOptions get classifierOptions;

  @override
  String toString() => 'TextClassifierOptions(baseOptions: $baseOptions, '
      'classifierOptions: $classifierOptions)';

  @override
  List<Object?> get props => [baseOptions, classifierOptions];
}
