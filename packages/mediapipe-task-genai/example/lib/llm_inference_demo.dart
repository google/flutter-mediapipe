// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:example/llm_model.dart';
import 'package:example/model_location_provider.dart';
import 'package:flutter/material.dart';
import 'package:mediapipe_genai/mediapipe_genai.dart';
import 'package:provider/provider.dart';
import 'widgets/widgets.dart';

class LlmInferenceDemo extends StatefulWidget {
  const LlmInferenceDemo({super.key});

  @override
  State<LlmInferenceDemo> createState() => _LlmInferenceDemoState();
}

class _LlmInferenceDemoState extends State<LlmInferenceDemo>
    with AutomaticKeepAliveClientMixin<LlmInferenceDemo> {
  final TextEditingController _controller = TextEditingController();
  Completer<LlmInferenceEngine?> _completer = Completer<LlmInferenceEngine?>();
  final results = <Widget>[];

  LlmInferenceEngine? _engine;

  Map<LlmModel, List<ChatMessage>> transcript = {};

  @override
  void initState() {
    super.initState();
    _controller.text = 'Hello, world!';
  }

  void changeSelectedModel(LlmModel model) {
    _engine = null;
    if (!_completer.isCompleted) {
      // If we changing models during a download, abort the previous request.
      _completer.complete(null);
    }
    _completer = Completer<LlmInferenceEngine?>();
    provider.selectedModel = model;
  }

  ModelLocationProvider get provider =>
      Provider.of<ModelLocationProvider>(context, listen: false);
  LlmModel get selectedModel => provider.selectedModel;

  Future<void> _initEngine() async {
    String modelPath = await _downloadModel(selectedModel);
    print('using model at $modelPath');

    _engine = LlmInferenceEngine(
      LlmInferenceOptions(
        modelPath: modelPath,
        maxTokens: 10,
        temperature: 0.5,
        topK: 10,
      ),
    );
    _completer.complete(_engine);
  }

  void _sendToLlm(String message) {
    if (_engine == null) {
      _initEngine();
    }
    _completer.future.then(
      (engine) async {
        if (engine == null) {
          // The download was aborted or failed.
          return;
        }
        print('engine ready. sending $message');
        _addMessageToTranscript('', MessageOrigin.llm);
        final messageIndex = transcript.length - 1;
        final responseStream = engine.generateResponse(message);
        await for (final String chunk in responseStream) {
          print('received $chunk in Flutter');
          transcript[selectedModel]![messageIndex] =
              transcript[selectedModel]![messageIndex].continueBody(chunk);
        }
      },
    );
  }

  _addMessageToTranscript(String message, MessageOrigin origin) {
    if (!transcript.containsKey(selectedModel)) {
      transcript[selectedModel] = <ChatMessage>[];
    }
    transcript[selectedModel]!.add(ChatMessage.origin(message, origin));
  }

  Future<String> _downloadModel(LlmModel model) async {
    final provider = context.read<ModelLocationProvider>();
    return provider.getModelLocation(model);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: <Widget>[
              SizedBox(
                height: 100,
                child: ModelsRow(selected: selectedModel),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ModelStatusBar(
                  selectedModel,
                  download: () => _downloadModel(selectedModel),
                  delete: () => provider.delete(selectedModel),
                ),
              ),
              Expanded(
                child: ConversationLog(
                  transcript: transcript[selectedModel] ?? [],
                ),
              ),
              Row(
                children: [
                  Expanded(child: TextField(controller: _controller)),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () {
                      setState(() {
                        _addMessageToTranscript(
                            _controller.text, MessageOrigin.user);
                      });
                      _sendToLlm(_controller.text);
                      _controller.clear();
                    },
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class ModelsRow extends StatelessWidget {
  const ModelsRow({super.key, required this.selected});

  final LlmModel selected;

  @override
  Widget build(BuildContext context) {
    return ListView(
      scrollDirection: Axis.horizontal,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: ModelsRowEntry(
            LlmModel.gemma4bCpu,
            isSelected: LlmModel.gemma4bCpu == selected,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: ModelsRowEntry(
            LlmModel.gemma4bGpu,
            isSelected: LlmModel.gemma4bGpu == selected,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: ModelsRowEntry(
            LlmModel.gemma8bCpu,
            isSelected: LlmModel.gemma8bCpu == selected,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: ModelsRowEntry(
            LlmModel.gemma8bGpu,
            isSelected: LlmModel.gemma8bGpu == selected,
          ),
        ),
      ],
    );
  }
}

class ModelsRowEntry extends StatelessWidget {
  const ModelsRowEntry(
    this.model, {
    required this.isSelected,
    super.key,
  });

  final LlmModel model;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ModelLocationProvider>();
    final path = provider.pathFor(model);
    final binarySize = path != null ? provider.binarySize(path) : null;
    final Color borderColor = binarySize != null //
        ? Colors.green
        : Colors.orange;

    return Container(
      height: 100,
      width: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        border: isSelected //
            ? Border.all(color: borderColor, width: 3)
            : null,
        color: Colors.grey[200],
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(model.displayName),
        ),
      ),
    );
  }
}

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
