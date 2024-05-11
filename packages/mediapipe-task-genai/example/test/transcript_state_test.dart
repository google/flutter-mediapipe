// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:example/models/models.dart';
import 'package:example/bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TranscriptState should', () {
    test('have a new hash code after receiving a new message', () {
      final initial = TranscriptState.initial();
      final updated = initial.addMessage(
        ChatMessage.user('Hello'),
        LlmModel.gemma4bCpu,
      );
      expect(initial.transcript, isNot(equals(updated.transcript)));
      expect(
        initial.transcript.hashCode,
        isNot(equals(updated.transcript.hashCode)),
      );
      expect(initial.hashCode, isNot(equals(updated.hashCode)));
    });

    test('have a new hash code after extending a message', () {
      var initial = TranscriptState.initial();
      initial = initial.addMessage(
        ChatMessage.llm('Hello'),
        LlmModel.gemma4bCpu,
      );
      final updated = initial.extendMessage(
        ', world!',
        index: 0,
        model: LlmModel.gemma4bCpu,
        first: false,
        last: true,
      );
      expect(initial.transcript, isNot(equals(updated.transcript)));
      expect(
        initial.transcript.hashCode,
        isNot(equals(updated.transcript.hashCode)),
      );
      expect(initial.hashCode, isNot(equals(updated.hashCode)));
    });

    test('have a new hash code after extending a message', () {
      var initial = TranscriptState.initial();
      initial = initial.addMessage(
        ChatMessage.llm('Hello'),
        LlmModel.gemma4bCpu,
      );
      final updated = initial.completeMessage(LlmModel.gemma4bCpu);
      expect(initial.transcript, isNot(equals(updated.transcript)));
      expect(
        initial.transcript.hashCode,
        isNot(equals(updated.transcript.hashCode)),
      );
      expect(initial.hashCode, isNot(equals(updated.hashCode)));
    });
  });
}
