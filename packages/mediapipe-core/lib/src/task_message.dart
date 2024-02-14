// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ffi' as ffi;

/// {@template TaskMessage}
/// {@endtemplate}
abstract class TaskMessage {
  /// {@macro TaskMessage}
  const TaskMessage();

  /// Uses FFI bindings to call the appropriate method for this task.
  int run(
    ffi.Pointer<ffi.Void> worker,
    ffi.Pointer<ffi.Struct> result,
    ffi.Pointer<ffi.Pointer<ffi.Char>> errorMsg,
  );
}
