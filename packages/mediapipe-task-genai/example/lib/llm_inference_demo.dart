// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:example/bloc.dart';
import 'package:example/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'widgets/widgets.dart';

class LlmInferenceDemo extends StatefulWidget {
  const LlmInferenceDemo({super.key});

  @override
  State<LlmInferenceDemo> createState() => _LlmInferenceDemoState();
}

class _LlmInferenceDemoState extends State<LlmInferenceDemo>
    with AutomaticKeepAliveClientMixin<LlmInferenceDemo> {
  final TextEditingController _controller = TextEditingController();
  final results = <Widget>[];

  late TranscriptBloc bloc;

  static const initialText = 'Hello, world!';

  @override
  void initState() {
    super.initState();
    bloc = TranscriptBloc(LlmModel.gemma4bCpu);
    _controller.text = initialText;
  }

  void changeSelectedModel(LlmModel model) => bloc.add(ChangeModel(model));

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return BlocListener(
      bloc: bloc,
      listener: (context, TranscriptState state) {
        if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.error!)),
          );
        }
      },
      child: BlocBuilder(
        bloc: bloc,
        builder: (context, TranscriptState state) {
          return Scaffold(
            appBar: AppBar(title: const Text('Inference')),
            drawer: Drawer(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: InferenceConfigurationPanel(
                  topK: state.topK,
                  temp: state.temperature,
                  changeTopK: (int newTopK) => bloc.add(UpdateTopK(newTopK)),
                  changeTemp: (double newTemp) =>
                      bloc.add(UpdateTemperature(newTemp)),
                ),
              ),
            ),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: <Widget>[
                    SizedBox(
                      height: 100,
                      child: ModelsRow(
                        deleteModel: () => bloc.add(const DeleteModel()),
                        downloadModel: () => bloc.add(const DownloadModel()),
                        modelInfoMap: state.modelInfoMap,
                        selected: state.selectedModel,
                        selectModel: (LlmModel model) =>
                            bloc.add(ChangeModel(model)),
                      ),
                    ),
                    // Padding(
                    //   padding: const EdgeInsets.only(top: 8),
                    //   child: statusBar,
                    // ),
                    Expanded(
                      child: KeyboardHider(
                        child: ConversationLog(transcript: state.transcript),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: _controller)),
                        ValueListenableBuilder(
                          valueListenable: _controller,
                          builder: (context, value, child) {
                            return IconButton(
                              icon: const Icon(Icons.send),
                              onPressed: _controller.text != '' &&
                                      !state.isLlmTyping
                                  ? () {
                                      setState(() {
                                        bloc.add(
                                          AddMessage(
                                            ChatMessage.user(_controller.text),
                                          ),
                                        );
                                      });
                                      _controller.clear();
                                    }
                                  : null,
                            );
                          },
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    bloc.close();
    super.dispose();
  }
}
