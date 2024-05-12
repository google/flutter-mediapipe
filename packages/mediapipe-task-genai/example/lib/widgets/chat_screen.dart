// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:chat_bubbles/chat_bubbles.dart';
import 'package:example/bloc.dart';
import 'package:example/models/models.dart';
import 'package:example/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen(this.bloc, {required this.model, super.key});

  final TranscriptBloc bloc;
  final LlmModel model;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();

  static const initialText = 'Hello, world!';

  @override
  void initState() {
    if (widget.bloc.state.transcript[widget.model]!.isEmpty) {
      _controller.text = initialText;
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final bloc = widget.bloc;
    return BlocBuilder<TranscriptBloc, TranscriptState>(
      bloc: bloc,
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(title: Text(widget.model.displayName)),
          endDrawer: Drawer(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: InferenceConfigurationPanel(
                topK: state.topK,
                temp: state.temperature,
                maxTokens: state.maxTokens,
                updateTopK: (val) => bloc.add(UpdateTopK(val)),
                updateTemp: (val) => bloc.add(UpdateTemperature(val)),
                updateMaxTokens: (val) => bloc.add(UpdateMaxTokens(val)),
              ),
            ),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: <Widget>[
                  Expanded(
                    child: KeyboardHider(
                      child: ChatTranscript(state.transcript[widget.model]!),
                    ),
                  ),
                  ChatInput(
                    controller: _controller,
                    isLlmTyping: state.isLlmTyping,
                    submit: (String value) {
                      bloc.add(
                        AddMessage(ChatMessage.user(value), widget.model),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class ChatTranscript extends StatefulWidget {
  const ChatTranscript(
    this.transcript, {
    super.key,
  });

  final List<ChatMessage> transcript;

  @override
  State<ChatTranscript> createState() => _ChatTranscriptState();
}

class _ChatTranscriptState extends State<ChatTranscript> {
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

            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: message.displayString != ''
                  ? ChatMessageBubble(
                      message: message,
                      width: constraints.maxWidth * 0.8,
                      key: ValueKey('message-${message.id}'),
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
          flex: 6,
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
