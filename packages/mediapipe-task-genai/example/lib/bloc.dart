// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';
import 'package:example/model_location_provider.dart';
import 'package:example/models/models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:logging/logging.dart';
import 'package:mediapipe_genai/mediapipe_genai.dart';
import 'package:path_provider/path_provider.dart' as path_provider;

part 'bloc.freezed.dart';

typedef Emit = Emitter<TranscriptState>;
final _log = Logger('TranscriptBloc');

class TranscriptBloc extends Bloc<TranscriptEvent, TranscriptState> {
  TranscriptBloc(LlmModel selectedModel)
      : modelProvider = ModelLocationProvider.fromEnvironment(
          selectedModel,
        ),
        super(TranscriptState.initial(selectedModel)) {
    on<TranscriptEvent>(
      (event, emit) {
        event.map(
          addMessage: (e) => _addMessage(e, emit),
          extendMessage: (e) => _extendMessage(e, emit),
          changeModel: (e) => _changeModel(e, emit),
          checkForModel: (e) => _checkForModel(e, emit),
          completeResponse: (e) => _completeResponse(e, emit),
          downloadModel: (e) => _downloadModel(e, emit),
          deleteModel: (e) => _deleteModel(e, emit),
          setPercentDownloaded: (e) => _setPercentDownloaded(e, emit),
          updateTemperature: (e) => _updateTemperature(e, emit),
          updateTopK: (e) => _updateTopK(e, emit),
          initEngine: (e) => _initEngine(e, emit),
        );
      },
    );
    final cacheDirFuture = path_provider.getApplicationCacheDirectory();
    modelProvider.ready.then((_) async {
      cacheDir = (await cacheDirFuture).absolute.path;
      add(CheckForModel(selectedModel));
    });
  }

  late final String cacheDir;

  /// Utility which knows how to download and store the model file.
  ModelLocationProvider modelProvider;

  /// Container for one message log per [LlmModel]. Mutable data type.
  final Map<LlmModel, List<ChatMessage>> transcript = {};

  List<ChatMessage> get currentTranscript {
    if (!transcript.containsKey(state.selectedModel)) {
      transcript[state.selectedModel] = <ChatMessage>[];
    }
    return transcript[state.selectedModel]!;
  }

  Future<void> _checkForModel(CheckForModel event, Emit emit) async {
    final existingPath = modelProvider.pathFor(event.model);
    ModelInfo modelInfo = existingPath != null
        ? ModelInfo(
            path: existingPath,
            downloadedBytes: modelProvider.binarySize(existingPath),
            downloadPercent: null,
          )
        : const ModelInfo();
    _emitNewModelInfo(event.model, modelInfo, emit);
    if (existingPath != null) {
      add(const InitEngine());
    }
  }

  void _setPercentDownloaded(SetPercentDownloaded event, Emit emit) async {
    _emitNewModelInfo(
      event.model,
      state.modelInfoMap[event.model]!.copyWith(
        downloadPercent: event.percentDownloaded,
        downloadedBytes: null,
        path: null,
      ),
      emit,
    );
  }

  /// Copies the `state.modelInfo` map, slots the provided [info] into the
  /// correct place, and emits a copy of [state] with that new map.
  /// However, if you have already made other modifications to a state object
  /// (via copying), consider passing that copied value to the [overrideState]
  /// parameter.
  ///
  /// See also:
  ///   * [_emitCurrentTranscript] for the transcript version of this method.
  void _emitNewModelInfo(
    LlmModel model,
    ModelInfo info,
    Emit emit, [
    TranscriptState? overrideState,
  ]) {
    final stateToEmit = overrideState ?? state;
    // Copy the map of `ModelInfo` objects
    final modelInfoMap = Map<LlmModel, ModelInfo>.from(state.modelInfoMap);

    // Update the map copy
    modelInfoMap[model] = info;

    // Emit a copy of `state` with the new ModelInfo map
    emit(stateToEmit.copyWith(modelInfoMap: modelInfoMap));
  }

  Future<void> _updateTemperature(UpdateTemperature event, Emit emit) async {
    final newState = state.copyWith(engine: null, temperature: event.value);
    emit(newState);
  }

  Future<void> _updateTopK(UpdateTopK event, Emit emit) async {
    final newState = state.copyWith(engine: null, topK: event.value);
    emit(newState);
  }

  Future<void> _initEngine(InitEngine event, Emit emit) async {
    late LlmInferenceOptions options;
    final modelPath = modelProvider.pathFor(state.selectedModel);
    if (modelPath == null) {
      throw Exception('Called _initEngine before model was downloaded');
    }
    if (state.selectedModel.hardware == Hardware.gpu) {
      options = LlmInferenceOptions.gpu(
        modelPath: modelPath,
        maxTokens: state.maxTokens,
        temperature: state.temperature,
        topK: state.topK,
        sequenceBatchSize: state.sequenceBatchSize,
      );
    } else {
      options = LlmInferenceOptions.cpu(
        modelPath: modelPath,
        cacheDir: cacheDir,
        maxTokens: state.maxTokens,
        temperature: state.temperature,
        topK: state.topK,
      );
    }
    final engine = LlmInferenceEngine(options);
    emit(state.copyWith(engine: engine));
  }

  void _changeModel(ChangeModel event, Emit emit) {
    if (!transcript.containsKey(event.model)) {
      transcript[event.model] = <ChatMessage>[];
    }
    emit(
      state.copyWith(
        selectedModel: event.model,
        transcript: transcript[event.model]!,
        engine: null,
      ),
    );

    add(CheckForModel(event.model));
  }

  Future<void> _downloadModel(DownloadModel event, Emit emit) async {
    assert(
      await modelProvider.downloadExistsForModel(state.selectedModel) == false,
      'The UI should not ask to download an existing model. Model exists for '
      '${state.selectedModel} at ${modelProvider.pathFor(state.selectedModel)}.',
    );

    // Hold onto this variable in case the user switches the active model while
    // we are downloading.
    final modelToDownload = state.selectedModel;

    late final Future<String> modelLocationFuture;
    late final Stream<int>? downloadStream;
    try {
      // Request the model download and, once a string value is returned,
      // mark that the model is available and that the download is complete.
      (modelLocationFuture, downloadStream) =
          await modelProvider.getModelLocation(modelToDownload);
    } on Exception catch (e, s) {
      _log.severe('Error: $e');
      _log.severe('Stack trace: $s');
      emit(
        state.copyWith(
          error: 'Unable to download ${modelToDownload.displayName}',
        ),
      );
      await Future.delayed(const Duration(milliseconds: 100));
      emit(state.copyWith(error: null));
    }

    if (downloadStream != null) {
      await for (final percent in downloadStream) {
        add(SetPercentDownloaded(modelToDownload, percent));
      }
    }

    await modelLocationFuture;
    add(CheckForModel(modelToDownload));
  }

  Future<void> _deleteModel(DeleteModel event, Emit emit) async {
    final modelToDelete = state.selectedModel;
    emit(state.copyWith(engine: null));
    await modelProvider.delete(modelToDelete);
    add(CheckForModel(modelToDelete));
  }

  void _completeResponse(e, emit) {
    currentTranscript.last = currentTranscript.last.complete();
    final newState = state.copyWith(isLlmTyping: false);
    _emitCurrentTranscript(emit, newState);
  }

  Future<void> _addMessage(AddMessage event, Emit emit) async {
    // Value equality will detect that this state is "new"
    addMessage(event.message, emit);
    if (state.engine == null) {
      await _queueMessageForLlm(event.message.body, emit);
    } else {
      await _sendMessageToLlm(event.message.body, emit);
    }
  }

  Future<void> _queueMessageForLlm(String message, Emit emit) async {}

  Future<void> _sendMessageToLlm(String message, Emit emit) async {
    // Add a blank response for the LLM into which we can write its answer.
    addMessage(ChatMessage.llm(''), emit);
    emit(state.copyWith(isLlmTyping: true));

    final messageIndex = currentTranscript.length - 1;
    await Future.delayed(const Duration(seconds: 2));
    final response = [
      'Hello',
      'my good',
      'friend!',
      'How are you doing?',
      'Are you well?',
    ];
    for (final chunk in response) {
      await Future.delayed(const Duration(milliseconds: 500));
      add(ExtendMessage(chunk: chunk, index: messageIndex));
    }
    add(const CompleteResponse());

    // final responseStream = state.engine!.generateResponse(message);
    // await for (final String chunk in responseStream) {
    //   print('received $chunk in Flutter');
    //   currentTranscript[messageIndex] =
    //      currentTranscript[messageIndex].continueBody(chunk);
    // }
  }

  void _extendMessage(ExtendMessage event, Emit emit) {
    // It would be nice to not copy the whole list every time.
    currentTranscript[event.index] =
        currentTranscript[event.index].continueBody(event.chunk);
    _emitCurrentTranscript(emit);
  }

  void addMessage(ChatMessage message, Emit emit) {
    currentTranscript.add(message);
    _emitCurrentTranscript(emit);
  }

  /// Re-emits the current state with an updated copy of the transcript from the
  /// Bloc's own storage. However, if you have already made other modifications
  /// to a state object (via copying), consider passing that copied value to
  /// the [overrideState] parameter.
  ///
  /// See also:
  ///   * [_emitNewModelInfo] for the [ModelInfo] version of this method.
  void _emitCurrentTranscript(Emit emit, [TranscriptState? overrideState]) {
    emit(
      (overrideState ?? state)
          .copyWith(transcript: List<ChatMessage>.from(currentTranscript)),
    );
  }
}

@Freezed()
class TranscriptState with _$TranscriptState {
  TranscriptState._();
  factory TranscriptState({
    /// Log of messages for the [selectedModel]. Other models may have other
    /// message logs found on the [TranscriptBloc].
    @Default(<ChatMessage>[]) List<ChatMessage> transcript,

    /// Model receiving focus from the pool of available models.
    required LlmModel selectedModel,

    /// Engine for the current [selectedModel].
    LlmInferenceEngine? engine,

    /// True if the model is in the process of composing its response.
    @Default(false) isLlmTyping,

    /// Meta download information about each [LlmModel].
    required Map<LlmModel, ModelInfo> modelInfoMap,

    /// Randomness during token sampling selection.
    @Default(0.8) double temperature,

    /// Top K number of tokens to be sampled from for each decoding step.
    @Default(40) int topK,

    /// Randomness seed.
    required int randomSeed,

    /// Error message to show in a toast.
    String? error,
  }) = _TranscriptState;

  factory TranscriptState.initial(LlmModel selectedModel, [int? seed]) {
    final modelInfoMap = <LlmModel, ModelInfo>{};
    for (final model in LlmModel.values) {
      modelInfoMap[model] = const ModelInfo();
    }
    return TranscriptState(
      transcript: <ChatMessage>[],
      selectedModel: selectedModel,
      randomSeed: seed ?? Random().nextInt(1 << 32),
      modelInfoMap: modelInfoMap,
    );
  }

  int get maxTokens => 512;
  int get sequenceBatchSize => 20;
}

@Freezed()
class TranscriptEvent with _$TranscriptEvent {
  const factory TranscriptEvent.changeModel(LlmModel model) = ChangeModel;
  const factory TranscriptEvent.checkForModel(LlmModel model) = CheckForModel;
  const factory TranscriptEvent.downloadModel() = DownloadModel;
  const factory TranscriptEvent.setPercentDownloaded(
      LlmModel model, int percentDownloaded) = SetPercentDownloaded;
  const factory TranscriptEvent.deleteModel() = DeleteModel;
  const factory TranscriptEvent.initEngine() = InitEngine;
  const factory TranscriptEvent.updateTemperature(double value) =
      UpdateTemperature;
  const factory TranscriptEvent.updateTopK(int value) = UpdateTopK;
  const factory TranscriptEvent.addMessage(ChatMessage message) = AddMessage;
  const factory TranscriptEvent.extendMessage({
    required String chunk,
    required int index,
  }) = ExtendMessage;
  const factory TranscriptEvent.completeResponse() = CompleteResponse;
}
