// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ffi';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:mediapipe_core/mediapipe_core.dart';

void main() {
  group('BaseOptions constructor should', () {
    test('enforce exactly one of modelPath and modelBuffer', () {
      expect(
        () => BaseOptions(
          modelAssetPath: 'abc',
          modelAssetBuffer: Uint8List.fromList([1, 2, 3]),
        ),
        throwsA(TypeMatcher<AssertionError>()),
      );

      expect(BaseOptions.new, throwsA(TypeMatcher<AssertionError>()));
    });
  });

  group('BaseOptions.toStruct/fromStruct should', () {
    test('allocate memory in C for a modelAssetPath', () {
      final options = BaseOptions(modelAssetPath: 'abc');
      final struct = options.toStruct();
      expect(toDartString(struct.ref.model_asset_path), 'abc');
      expectNullPtr(struct.ref.model_asset_buffer);
    });

    test('allocate memory in C for a modelAssetBuffer', () {
      final options = BaseOptions(
        modelAssetBuffer: Uint8List.fromList([1, 2, 3]),
      );
      final struct = options.toStruct();
      expect(
        toUint8List(struct.ref.model_asset_buffer),
        Uint8List.fromList([1, 2, 3]),
      );
      expectNullPtr(struct.ref.model_asset_path);
    });

    test('allocate memory in C for a modelAssetBuffer containing 0', () {
      final options = BaseOptions(
        modelAssetBuffer: Uint8List.fromList([1, 2, 0, 3]),
      );
      final struct = options.toStruct();
      expect(
        toUint8List(struct.ref.model_asset_buffer),
        Uint8List.fromList([1, 2]),
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
      expect(struct.ref.category_allowlist, isA<Pointer<Never>>());
      expect(struct.ref.category_allowlist_count, 0);
      expect(struct.ref.category_denylist, isA<Pointer<Never>>());
      expect(struct.ref.category_denylist_count, 0);
      expectNullPtr(struct.ref.display_names_locale);

      // TODO: Could we do something like this?
      // (right now, this segfaults)
      // expect(struct.ref.display_names_locale.cast<Uint8>().asTypedList(1),
      //     Uint8List.fromList([0]));
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

      expect(toDartString(struct.ref.display_names_locale), 'en');
      expect(struct.ref.max_results, 5);
      expect(struct.ref.score_threshold, greaterThan(0.8999));
      expect(struct.ref.score_threshold, lessThan(0.90001));
      expect(
        toDartStrings(
          struct.ref.category_allowlist,
          struct.ref.category_allowlist_count,
        ),
        ['good', 'great', 'best'],
      );
      expect(struct.ref.category_allowlist_count, 3);

      expect(
        toDartStrings(
          struct.ref.category_denylist,
          struct.ref.category_denylist_count,
        ),
        ['bad', 'terrible', 'worst', 'honestly come on'],
      );
      expect(struct.ref.category_denylist_count, 4);
    });
  });
}

void expectNullPtr(Pointer ptr) => expect(ptr.address, equals(0));
