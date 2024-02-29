// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:mediapipe_core/interface.dart';

/// {@template TextClassifierResult}
/// Container with results of MediaPipe's `classifyText` task.
///
/// See also:
///  * [MediaPipe's textClassifierResult documentation](https://developers.google.com/mediapipe/api/solutions/java/com/google/mediapipe/tasks/text/textclassifier/TextClassifierResult)
/// {@endtemplate}
abstract class ITextClassifierResult extends IClassifierResult {
  /// {@macro TextClassifierResult}
  ITextClassifierResult();

  /// {@macro ClassifierResult.fake}
  // ITextClassifierResult.fake({required List<IClassifications> classifications})
  //     : super.fake(classifications: classifications);
}
