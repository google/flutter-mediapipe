// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ffi';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:mediapipe_core/mediapipe_core.dart';

void main() {
  group('BaseOptions.toStruct/structToDart should', () {
    test('allocate memory in C for a modelAssetPath', () {
      final options = BaseOptions.path('abc');
      final struct = options.toStruct();
      expect(struct.ref.model_asset_path.toDartString(), 'abc');
      expectNullPtr(struct.ref.model_asset_buffer);
    });

    test('allocate memory in C for a modelAssetBuffer', () {
      final options = BaseOptions.memory(Uint8List.fromList([1, 2, 3]));
      final struct = options.toStruct();
      expect(
        struct.ref.model_asset_buffer.toUint8List(3),
        Uint8List.fromList([1, 2, 3]),
      );
      expectNullPtr(struct.ref.model_asset_path);
    });

    test('allocate memory in C for a modelAssetBuffer containing 0', () {
      final options = BaseOptions.memory(Uint8List.fromList([1, 2, 0, 3]));
      final struct = options.toStruct();
      expect(
        struct.ref.model_asset_buffer.toUint8List(4),
        Uint8List.fromList([1, 2, 0, 3]),
      );
      expectNullPtr(struct.ref.model_asset_path);
    });
  });

  group('ClassOptions should', () {
    test('allocate memory for empty fields', () {
      final options = ClassifierOptions();

      final struct = options.toStruct();

      expect(struct.ref.max_results, -1);
      expect(struct.ref.score_threshold, 0.0);
      expectNullPtr(struct.ref.category_allowlist);
      expect(struct.ref.category_allowlist_count, 0);
      expectNullPtr(struct.ref.category_denylist);
      expect(struct.ref.category_denylist_count, 0);
      expectNullPtr(struct.ref.display_names_locale);
    });

    test('allocate memory for full fields', () {
      final options = ClassifierOptions(
        displayNamesLocale: 'en',
        maxResults: 5,
        scoreThreshold: 0.9,
        categoryAllowlist: ['good', 'great', 'best'],
        categoryDenylist: ['bad', 'terrible', 'worst', 'honestly come on'],
      );

      final struct = options.toStruct();

      expect(struct.ref.display_names_locale.toDartString(), 'en');
      expect(struct.ref.max_results, 5);
      expect(struct.ref.score_threshold, greaterThan(0.8999));
      expect(struct.ref.score_threshold, lessThan(0.90001));
      expect(
        struct.ref.category_allowlist.toDartStrings(
          struct.ref.category_allowlist_count,
        ),
        ['good', 'great', 'best'],
      );
      expect(struct.ref.category_allowlist_count, 3);

      expect(
        struct.ref.category_denylist.toDartStrings(
          struct.ref.category_denylist_count,
        ),
        ['bad', 'terrible', 'worst', 'honestly come on'],
      );
      expect(struct.ref.category_denylist_count, 4);
    });
  });
}

void expectNullPtr(Pointer ptr) => expect(ptr.address, equals(0));
