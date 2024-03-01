// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:mediapipe_core/src/io/native_memory_manager.dart';
import 'package:test/test.dart';

void main() {
  group('NativeStringManager should', () {
    test('allocate and deallocate correctly', () {
      final mgr = NativeStringManager();
      expect(mgr.isFreed, true);
      mgr.memory;
      expect(mgr.isNotFreed, true);
      // Cannot call `free` because we lack a native function to actually
      // hydrate this string
      // mgr.free();
      // expect(mgr.isFreed, true);
    });

    // TODO: add a native function which hydrates this string in the same way
    //       as MediaPipe hydrates error_msg parameters
  });

  group('DartStringMemoryManager should', () {
    test('allocate and deallocate correctly', () {
      final mgr = DartStringMemoryManager('test');
      expect(mgr.isFreed, true);
      mgr.memory;
      expect(mgr.isNotFreed, true);
      mgr.free();
      expect(mgr.isFreed, true);
    });

    // TODO: add a native function which mutates this string
  });
}
