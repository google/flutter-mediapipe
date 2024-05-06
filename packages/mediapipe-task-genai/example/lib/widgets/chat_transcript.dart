// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:chat_bubbles/chat_bubbles.dart';
import 'package:example/models/models.dart';
import 'package:example/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class ConversationLog extends StatefulWidget {
  const ConversationLog({required this.transcript, super.key});

  final List<ChatMessage> transcript;

  @override
  State<ConversationLog> createState() => _ConversationLogState();
}

class _ConversationLogState extends State<ConversationLog> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ListView.builder(
          reverse: true,
          itemCount: widget.transcript.length,
          itemBuilder: (context, index) {
            final messageIndex = widget.transcript.length - index - 1;
            final message = widget.transcript[messageIndex];

            if (!message.displayingFullString) {
              Future.delayed(const Duration(milliseconds: 50)).then((_) {
                SchedulerBinding.instance.addPostFrameCallback(
                  (_) {
                    setState(message.advanceCursor);
                  },
                  debugLabel: 'Updating ChatMessage',
                );
              });
            }

            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: message.displayString != ''
                  ? SizedBox(
                      width: constraints.maxWidth * 0.7,
                      child: ChatMessageBubble(
                        message: message,
                        width: constraints.maxWidth * 0.6,
                        key: ValueKey('message-${message.id}'),
                      ),
                    )
                  : const TypingIndicator(
                      showIndicator: true,
                    ),
            );
          },
        );
      },
    );
  }
}

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    required this.message,
    required this.width,
    super.key,
  });

  final ChatMessage message;
  final double width;

  // Colors.blue[400]
  static const llmBgColor = Color(0xFF42A5F5);

  // Colors.orange[400]
  static const userBgColor = Color(0xFFFFA726);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (message.origin.isUser) Flexible(flex: 2, child: Container()),
        Flexible(
          flex: 4,
          child: BubbleSpecialThree(
            text: message.displayString,
            color: message.origin.isUser ? userBgColor : llmBgColor,
            isSender: message.origin.isUser,
            textStyle: const TextStyle(color: Colors.white),
            sent: message.isComplete,
            delivered: message.isComplete,
            seen: message.isComplete,
          ),
        ),
        if (message.origin.isLlm) Flexible(flex: 2, child: Container()),
      ],
    );
  }
}
