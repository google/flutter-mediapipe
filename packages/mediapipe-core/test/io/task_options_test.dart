// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:mediapipe_core/io_mediapipe_core.dart';
import 'package:mediapipe_core/src/io/third_party/mediapipe/generated/mediapipe_common_bindings.dart'
    as bindings;
import 'package:test/test.dart';

void main() {
  group('BaseOptions.toStruct/structToDart should', () {
    test('allocate memory in C for a modelAssetPath', () {
      using((arena) {
        final ptr = arena<bindings.BaseOptions>();
        final options = BaseOptions.path('abc');
        options.assignToStruct(ptr.ref);
        expect(ptr.ref.model_asset_path.toDartString(), 'abc');
        expectNullPtr(ptr.ref.model_asset_buffer);
      });
    });

    test('allocate memory in C for a modelAssetBuffer', () {
      using((arena) {
        final ptr = arena<bindings.BaseOptions>();
        final options = BaseOptions.memory(Uint8List.fromList([1, 2, 3]));
        options.assignToStruct(ptr.ref);
        expect(
          ptr.ref.model_asset_buffer.toUint8List(3),
          Uint8List.fromList([1, 2, 3]),
        );
        expectNullPtr(ptr.ref.model_asset_path);
      });
    });

    test('allocate memory in C for a modelAssetBuffer with a lower length', () {
      using((arena) {
        final ptr = arena<bindings.BaseOptions>();
        final options = BaseOptions.memory(Uint8List.fromList([1, 2, 0, 3]));
        options.assignToStruct(ptr.ref);
        expect(
          ptr.ref.model_asset_buffer.toUint8List(2),
          Uint8List.fromList([1, 2]),
        );
        expectNullPtr(ptr.ref.model_asset_path);
      });
    });
  });

  group('ClassifierOptions should', () {
    test('allocate memory for empty fields', () {
      using((arena) {
        final ptr = arena<bindings.ClassifierOptions>();
        final options = ClassifierOptions();

        options.assignToStruct(ptr.ref);

        expect(ptr.ref.max_results, -1);
        expect(ptr.ref.score_threshold, 0.0);
        expectNullPtr(ptr.ref.category_allowlist);
        expect(ptr.ref.category_allowlist_count, 0);
        expectNullPtr(ptr.ref.category_denylist);
        expect(ptr.ref.category_denylist_count, 0);
        expectNullPtr(ptr.ref.display_names_locale);
      });
    });

    test('allocate memory for full fields', () {
      using((arena) {
        final ptr = arena<bindings.ClassifierOptions>();
        final options = ClassifierOptions(
          displayNamesLocale: 'en',
          maxResults: 5,
          scoreThreshold: 0.9,
          categoryAllowlist: ['good', 'great', 'best'],
          categoryDenylist: ['bad', 'terrible', 'worst', 'honestly come on'],
        );
        options.assignToStruct(ptr.ref);

        expect(ptr.ref.display_names_locale.toDartString(), 'en');
        expect(ptr.ref.max_results, 5);
        expect(ptr.ref.score_threshold, greaterThan(0.8999));
        expect(ptr.ref.score_threshold, lessThan(0.90001));
        expect(ptr.ref.category_allowlist_count, 3);
        expect(
          ptr.ref.category_allowlist.toDartStrings(3),
          ['good', 'great', 'best'],
        );

        expect(ptr.ref.category_denylist_count, 4);
        expect(
          ptr.ref.category_denylist.toDartStrings(4),
          ['bad', 'terrible', 'worst', 'honestly come on'],
        );
      });
    });
  });
}

void expectNullPtr(Pointer ptr) => expect(ptr.address, nullptr.address);
