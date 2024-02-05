// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:test/test.dart';

void main() {
  group('Floats should', () {
    test('convert into Doubles', () {
      final floats = malloc<Float>(2);
      floats[0] = 1.0;
      floats[1] = 2.0;
      final doubles = toDartListDouble(floats, length: 2);
      expect(doubles[0], closeTo(1.0, 0.00001));
      expect(doubles[1], closeTo(2.0, 0.00001));
      malloc.free(floats);
    });

    test('be converted from doubles', () {
      final doubles = <double>[0.9, 1.1];

      final floats = doubles.toNative();
      expect(floats[0], closeTo(0.9, 0.00001));
      expect(floats[1], closeTo(1.1, 0.00001));

      final restoredDoubles = toDartListDouble(floats, length: 2);
      expect(restoredDoubles[0], closeTo(0.9, 0.00001));
      expect(restoredDoubles[1], closeTo(1.1, 0.00001));
      malloc.free(floats);
    });
  });

  group('Ints should', () {
    test('convert into Dart ints', () {
      final chars = malloc<Char>(2);
      chars[0] = 1;
      chars[1] = 2;
      final normalInts = toUint8List(chars, length: 2);
      expect(normalInts[0], 1);
      expect(normalInts[1], 2);
      malloc.free(chars);
    });

    test('be converted from Dart ints', () {
      final chars = prepareUint8List(Uint8List.fromList([3, 4]));
      expect(chars[0], 3);
      expect(chars[1], 4);
      malloc.free(chars);
    });
  });
}
