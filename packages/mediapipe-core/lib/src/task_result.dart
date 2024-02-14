// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ffi';

/// {@template TaskResult}
///
/// {@endtemplate}
abstract class TaskResult {
  /// {@macro TaskResult}
  const TaskResult();

  ///
  static TaskResult structToDart(Struct struct) {
    throw UnimplementedError();
  }

  ///
  void free();
}
