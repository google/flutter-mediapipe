// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

class ConversationLog extends StatelessWidget {
  const ConversationLog({required this.transcript, super.key});

  final List<ChatMessage> transcript;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return ListView.builder(
        reverse: true,
        itemCount: transcript.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(top: 6),
            child: SizedBox(
              width: constraints.maxWidth * 0.6,
              child: ChatMessageBubble(
                  message: transcript[transcript.length - index - 1]),
            ),
          );
        },
      );
    });
  }
}

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    required this.message,
    super.key,
  });

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.origin.alignmentFromTextDirection(
        Directionality.of(context),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(50)),
          color: message.backgroundColor,
        ),
        child: Text(
          message.body,
          style: const TextStyle(color: Colors.white),
          textAlign: message.origin.isLlm //
              ? TextAlign.start
              : TextAlign.end,
        ),
      ),
    );
  }
}

class ChatMessage {
  const ChatMessage._({
    required this.body,
    required this.backgroundColor,
    required this.origin,
  });

  factory ChatMessage.origin(String body, MessageOrigin origin) =>
      origin == MessageOrigin.user
          ? ChatMessage.user(body)
          : ChatMessage.llm(body);

  factory ChatMessage.llm(String body, {Color? backgroundColor}) =>
      ChatMessage._(
        body: body,
        backgroundColor: backgroundColor ?? defaultLlmBackgroundColor,
        origin: MessageOrigin.llm,
      );

  factory ChatMessage.user(String body, {Color? backgroundColor}) =>
      ChatMessage._(
        body: body,
        backgroundColor: backgroundColor ?? defaultUserBackgroundColor,
        origin: MessageOrigin.user,
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
    return ChatMessage.llm(
      '$body $continuation',
      backgroundColor: backgroundColor,
    );
  }

  final MessageOrigin origin;
  final String body;
  final Color backgroundColor;

  // Colors.blue[400]
  static const defaultLlmBackgroundColor = Color(0xFF42A5F5);

  // Colors.orange[400]
  static const defaultUserBackgroundColor = Color(0xFFFFA726);
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

/// Indicates whether the message should appear on the left, indicating it was
/// sent by the other conversation participant, or on the right, indicating it
/// was sent by the user themselves. This assumes LTR text directionality, and
/// thus the actual layout is flipped if text directionality is RTL.
enum MessageAlignment {
  start,
  end;

  bool get isStart => switch (this) {
        MessageAlignment.start => true,
        MessageAlignment.end => false,
      };
}
