// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:example/bloc.dart';
import 'package:example/model_selection_screen.dart';
import 'package:example/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mediapipe_genai/mediapipe_genai.dart';
// import 'fake_inference_engine.dart';
import 'widgets/widgets.dart';

class LlmInferenceDemo extends StatefulWidget {
  const LlmInferenceDemo({super.key});

  @override
  State<LlmInferenceDemo> createState() => _LlmInferenceDemoState();
}

class _LlmInferenceDemoState extends State<LlmInferenceDemo>
    with AutomaticKeepAliveClientMixin<LlmInferenceDemo> {
  final results = <Widget>[];

  late TranscriptBloc bloc;

  @override
  void initState() {
    super.initState();
    bloc = TranscriptBloc(
      engineBuilder: LlmInferenceEngine.new,
      // engineBuilder: FakeInferenceEngine.new,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return MultiBlocListener(
      listeners: [
        // Error listener
        BlocListener<TranscriptBloc, TranscriptState>(
          bloc: bloc,
          listener: (context, TranscriptState state) {
            if (state.error != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.error!)),
              );
            }
          },
        ),
      ],
      child: BlocBuilder(
        bloc: bloc,
        builder: (context, TranscriptState state) {
          return Scaffold(
            appBar: AppBar(title: const Text('Inference')),
            body: SafeArea(
              child: ModelSelectionScreen(
                modelsReady: state.modelsReady,
                deleteModel: (LlmModel model) => bloc.add(DeleteModel(model)),
                downloadModel: (LlmModel model) =>
                    bloc.add(DownloadModel(model)),
                modelInfoMap: state.modelInfoMap,
                selectModel: (LlmModel model) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        bloc,
                        model: model,
                        key: ValueKey(model.displayName),
                      ),
                    ),
                  );
                },
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
