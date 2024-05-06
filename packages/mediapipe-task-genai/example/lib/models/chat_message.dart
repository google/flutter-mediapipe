// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

part 'chat_message.freezed.dart';

@Freezed()
class ChatMessage with _$ChatMessage {
  const ChatMessage._();
  const factory ChatMessage({
    required String id,
    required String body,
    required MessageOrigin origin,
    required int cursorPosition,

    /// Always true for a user's message, but only true for the LLM once it has
    /// finished composing its reply.
    required bool isComplete,
  }) = _ChatMessage;

  factory ChatMessage.origin(String body, MessageOrigin origin) =>
      origin == MessageOrigin.user
          ? ChatMessage.user(body)
          : ChatMessage.llm(body);

  factory ChatMessage.llm(String body, {int? cursorPosition}) => ChatMessage(
        body: body,
        origin: MessageOrigin.llm,
        cursorPosition: cursorPosition ?? 0,
        isComplete: false,
        id: const Uuid().v4(),
      );

  factory ChatMessage.user(String body) => ChatMessage(
        body: body,
        origin: MessageOrigin.user,
        cursorPosition: body.length,
        isComplete: true,
        id: const Uuid().v4(),
      );

  ChatMessage continueBody(String continuation) {
    assert(() {
      if (origin.isUser) {
        throw Exception(
          'Only expected to extend messages from the LLM. '
          'Did you call continueBody on the wrong ChatMessage?',
        );
      }
      return true;
    }());
    return copyWith(body: '$body $continuation');
  }

  ChatMessage complete() {
    assert(() {
      if (origin.isUser) {
        throw Exception(
          'Only expected to complete messages from the LLM. '
          'Did you call complete() on the wrong ChatMessage?',
        );
      }
      return true;
    }());
    return copyWith(isComplete: true);
  }

  bool get displayingFullString => cursorPosition == body.length;

  // String get displayString => body.substring(0, cursorPosition);
  String get displayString => body;

  ChatMessage advanceCursor() => copyWith(cursorPosition: cursorPosition + 1);
}

enum MessageOrigin {
  user,
  llm;

  bool get isUser => switch (this) {
        MessageOrigin.user => true,
        MessageOrigin.llm => false,
      };

  bool get isLlm => switch (this) {
        MessageOrigin.user => false,
        MessageOrigin.llm => true,
      };

  Alignment alignmentFromTextDirection(TextDirection textDirection) =>
      switch (textDirection) {
        TextDirection.ltr =>
          isUser ? Alignment.centerRight : Alignment.centerLeft,
        TextDirection.rtl =>
          isUser ? Alignment.centerLeft : Alignment.centerRight,
      };
}
