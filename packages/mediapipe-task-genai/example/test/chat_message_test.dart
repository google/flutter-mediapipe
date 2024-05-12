// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:example/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

void main() {
  group('ChatMessage should', () {
    test('have collection equality', () {
      final message = ChatMessage.user('');
      final message2 = ChatMessage.llm('');
      expect(
        const DeepCollectionEquality().hash([message]),
        const DeepCollectionEquality().hash([message]),
      );
      expect(
        const DeepCollectionEquality().hash([message]),
        isNot(equals(const DeepCollectionEquality().hash([message2]))),
      );
    });
  });
}
