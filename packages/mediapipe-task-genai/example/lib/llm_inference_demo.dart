// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math';
import 'package:example/llm_model.dart';
import 'package:example/model_location_provider.dart';
import 'package:flutter/material.dart';
import 'package:mediapipe_genai/mediapipe_genai.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
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

  int maxTokens = 10;
  ValueNotifier<double> temperature = ValueNotifier<double>(0.5);
  ValueNotifier<int> topK = ValueNotifier<int>(10);
  int sequenceBatchSize = 10;
  late int randomSeed;

  @override
  void initState() {
    super.initState();
    randomSeed = Random().nextInt(1 << 32);
    _controller.text = 'Hello, world!';
  }

  void changeSelectedModel(LlmModel model) {
    _engine = null;
    if (!_completer.isCompleted) {
      // If we change models during a download, abort the previous request.
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

    late LlmInferenceOptions options;
    if (selectedModel.hardware == Hardware.gpu) {
      options = LlmInferenceOptions.gpu(
        modelPath: modelPath,
        maxTokens: maxTokens,
        temperature: temperature.value,
        topK: topK.value,
        sequenceBatchSize: sequenceBatchSize,
      );
    } else {
      options = LlmInferenceOptions.cpu(
        modelPath: modelPath,
        cacheDir:
            (await path_provider.getApplicationCacheDirectory()).absolute.path,
        maxTokens: maxTokens,
        temperature: temperature.value,
        topK: topK.value,
      );
    }

    _engine = LlmInferenceEngine(options);
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
      appBar: AppBar(title: const Text('Inference')),
      drawer: Drawer(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: InferenceConfigurationPanel(topK: topK, temp: temperature),
        ),
      ),
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
