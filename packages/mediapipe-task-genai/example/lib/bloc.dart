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
  TranscriptBloc({required this.engineBuilder})
      : modelProvider = ModelLocationProvider.fromEnvironment(),
        super(TranscriptState.initial()) {
    on<TranscriptEvent>(
      (event, emit) {
        event.map(
          addMessage: (e) => _addMessage(e, emit),
          extendMessage: (e) => _extendMessage(e, emit),
          checkForModel: (e) => _checkForModel(e, emit),
          completeResponse: (e) => _completeResponse(e, emit),
          downloadModel: (e) => _downloadModel(e, emit),
          deleteModel: (e) => _deleteModel(e, emit),
          setPercentDownloaded: (e) => _setPercentDownloaded(e, emit),
          updateTemperature: (e) => _updateTemperature(e, emit),
          updateTopK: (e) => _updateTopK(e, emit),
          updateMaxTokens: (e) => _updateMaxTokens(e, emit),
          initEngine: (e) => _initEngine(e, emit),
          initializeModelInfo: (e) => _initializeModelInfo(e, emit),
        );
      },
    );
    final cacheDirFuture = path_provider.getApplicationCacheDirectory();
    modelProvider.ready.then((_) async {
      cacheDir = (await cacheDirFuture).absolute.path;
      add(const InitializeModelInfo());
    });
  }

  late final String cacheDir;

  /// Utility which knows how to download and store the model file.
  ModelLocationProvider modelProvider;

  /// Constructor for the inference engine.
  final LlmInferenceEngine Function(LlmInferenceOptions) engineBuilder;

  Future<void> _initializeModelInfo(
    InitializeModelInfo event,
    Emit emit,
  ) async {
    // This is added post-construction because the ModelProvider must first
    // be ready, then we can sort out what models we have available, what can
    // be downloaded, and what is completely inaccessible given the current app
    // configuration.
    final modelInfoMap = <LlmModel, ModelInfo>{};
    for (final model in LlmModel.values) {
      modelInfoMap[model] = _getInfo(model);
    }
    emit(state.copyWith(modelInfoMap: modelInfoMap, modelsReady: true));
  }

  Future<void> _checkForModel(CheckForModel event, Emit emit) async {
    final existingPath = modelProvider.pathFor(event.model);
    final modelInfo = _getInfo(event.model);
    _emitNewModelInfo(event.model, modelInfo, emit);
    if (existingPath != null) {
      add(InitEngine(event.model));
    }
  }

  ModelInfo _getInfo(LlmModel model) {
    final existingPath = modelProvider.pathFor(model);
    return existingPath != null
        ? ModelInfo(
            path: existingPath,
            downloadedBytes: modelProvider.binarySize(existingPath),
            downloadPercent: null,
            remoteLocation: modelProvider.urlFor(model),
          )
        : ModelInfo(
            // The model may be downloading, so preserve whatever value that has
            downloadPercent: state.modelInfoMap[model]!.downloadPercent,
            remoteLocation: modelProvider.urlFor(model),
          );
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
  void _emitNewModelInfo(
    LlmModel model,
    ModelInfo info,
    Emit emit, [
    TranscriptState? overrideState,
  ]) {
    // Copy the map of `ModelInfo` objects
    final modelInfoMap = Map<LlmModel, ModelInfo>.from(state.modelInfoMap);

    // Update the map copy
    modelInfoMap[model] = info;

    // Emit a copy of `state` with the new ModelInfo map
    emit((overrideState ?? state).copyWith(modelInfoMap: modelInfoMap));
  }

  Future<void> _updateTemperature(UpdateTemperature event, Emit emit) async {
    state.engine?.dispose();
    emit(state.copyWith(engine: null, temperature: event.value));
  }

  Future<void> _updateTopK(UpdateTopK event, Emit emit) async {
    state.engine?.dispose();
    emit(state.copyWith(engine: null, topK: event.value));
  }

  Future<void> _updateMaxTokens(UpdateMaxTokens event, Emit emit) async {
    state.engine?.dispose();
    emit(state.copyWith(engine: null, maxTokens: event.value));
  }

  Future<void> _initEngine(InitEngine event, Emit emit) async {
    state.engine?.dispose();
    final modelPath = modelProvider.pathFor(event.model);
    if (modelPath == null) {
      throw Exception('Called _initEngine before model was downloaded');
    }
    final options = switch (event.model.hardware) {
      Hardware.gpu => LlmInferenceOptions.gpu(
          modelPath: modelPath,
          maxTokens: state.maxTokens,
          temperature: state.temperature,
          topK: state.topK,
          sequenceBatchSize: state.sequenceBatchSize,
        ),
      Hardware.cpu => LlmInferenceOptions.cpu(
          modelPath: modelPath,
          cacheDir: cacheDir,
          maxTokens: state.maxTokens,
          temperature: state.temperature,
          topK: state.topK,
        ),
    };
    _log.fine('Initializing inference engine with $options');
    final engine = engineBuilder(options);
    emit(state.copyWith(engine: engine));

    // If we queued a message for the Llm, process it!
    if (_queuedMessageForEngine != null) {
      _sendMessageToLlm(_queuedMessageForEngine!, emit);
      _queuedMessageForEngine = null;
    }
  }

  Future<void> _downloadModel(DownloadModel event, Emit emit) async {
    assert(
      await modelProvider.downloadExistsForModel(event.model) == false,
      'The UI should not ask to download an existing model. Model exists for '
      '${event.model} at ${modelProvider.pathFor(event.model)}.',
    );

    // Hold onto this variable in case the user switches the active model while
    // we are downloading.
    final modelToDownload = event.model;

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
      return;
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
    final modelToDelete = event.model;
    emit(state.copyWith(engine: null));
    await modelProvider.delete(modelToDelete);
    add(CheckForModel(modelToDelete));
  }

  void _completeResponse(CompleteResponse e, emit) =>
      emit(state.copyWith(isLlmTyping: false).completeMessage(e.model));

  Future<void> _addMessage(AddMessage event, Emit emit) async {
    // Value equality will detect that this state is "new"
    emit(state.addMessage(event.message, event.model));
    if (state.engine == null) {
      await _queueMessageForLlm(event, emit);
    } else {
      await _sendMessageToLlm(event, emit);
    }
  }

  Future<void> _queueMessageForLlm(AddMessage event, Emit emit) async {
    _queuedMessageForEngine = event;
    add(InitEngine(event.model));
  }

  AddMessage? _queuedMessageForEngine;

  Future<void> _sendMessageToLlm(
    AddMessage event,
    Emit emit,
  ) async {
    final formattedChatHistory =
        _formatChatHistoryForLlm(state.transcript[event.model]!);
    final responseStream = state.engine!.generateResponse(formattedChatHistory);

    // Add a blank response for the LLM into which we can write its answer.
    // Create a synthetic event just to pass to this helper method, but don't
    // route it through the `add` method.
    emit(
      state
          .copyWith(isLlmTyping: true)
          .addMessage(ChatMessage.llm(''), event.model),
    );

    final messageIndex = state.transcript[event.model]!.length - 1;
    bool first = true;
    await for (final String chunk in responseStream) {
      add(
        ExtendMessage(
          chunk: chunk,
          model: event.model,
          index: messageIndex,
          first: first,
          last: false,
        ),
      );
      first = false;
    }
    add(
      ExtendMessage(
        chunk: '',
        model: event.model,
        index: messageIndex,
        first: first,
        last: true,
      ),
    );
    add(CompleteResponse(event.model));
  }

  void _extendMessage(ExtendMessage event, Emit emit) => emit(
        state.extendMessage(
          event.chunk,
          model: event.model,
          index: event.index,
          first: event.first,
          last: event.last,
        ),
      );

  static const _begin = '<begin_transmission>';
  static const _end = '<end_transmission>';

  String _formatChatHistoryForLlm(List<ChatMessage> transcript) {
    // The current message is already in the transcript, so the length will be 1
    // on the first message. That message can go straight to the LLM without any
    // special decoration.
    if (transcript.length == 1) return transcript.last.body;

    final formattedHistory = transcript
        .map<String>(
          (message) => '$_begin\n'
              '${message.origin.transcriptName}: ${message.body}\n'
              '$_end\n',
        )
        .join('\n');

    return 'You are "${MessageOrigin.llm.transcriptName}" in the ensuing '
        'conversation. Messages tagged as having been written by '
        '"${MessageOrigin.llm.transcriptName}" are things you previously said '
        'in this conversation. Messages tagged as having been written by '
        '"${MessageOrigin.user.transcriptName}" came from the other party with '
        'which you are conversing.\n\n'
        '$formattedHistory\n\n'
        'Your response should not address the other party as '
        '"${MessageOrigin.user.transcriptName}". \n\n'
        'What is your response? Give a single answer.';
  }
}

@Freezed(makeCollectionsUnmodifiable: false)
class TranscriptState with _$TranscriptState {
  TranscriptState._();
  factory TranscriptState({
    /// Log of messages for the [selectedModel]. Other models may have other
    /// message logs found on the [TranscriptBloc].
    required Map<LlmModel, List<ChatMessage>> transcript,

    /// True only after the [ModelLocationProvider] has sorted out the initial
    /// state.
    @Default(false) bool modelsReady,

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

    /// The LLM's maximum context window.
    @Default(1024) int maxTokens,

    /// Randomness seed.
    required int randomSeed,

    /// Error message to show in a toast.
    String? error,
  }) = _TranscriptState;

  factory TranscriptState.initial([int? seed]) {
    final modelInfoMap = <LlmModel, ModelInfo>{};
    final transcript = <LlmModel, List<ChatMessage>>{};
    for (final model in LlmModel.values) {
      modelInfoMap[model] = const ModelInfo();
      transcript[model] = <ChatMessage>[];
    }
    return TranscriptState(
      transcript: transcript,
      randomSeed: seed ?? Random().nextInt(1 << 32),
      modelInfoMap: modelInfoMap,
    );
  }

  int get sequenceBatchSize => 20;

  Map<LlmModel, List<ChatMessage>> _copyTranscript() {
    final newTranscript = <LlmModel, List<ChatMessage>>{};
    for (final key in transcript.keys) {
      newTranscript[key] = List<ChatMessage>.from(transcript[key]!);
    }
    return newTranscript;
  }

  TranscriptState addMessage(ChatMessage message, LlmModel model) {
    final newTranscript = _copyTranscript();
    newTranscript[model]!.add(message);
    return copyWith(transcript: newTranscript);
  }

  TranscriptState extendMessage(
    String chunk, {
    required int index,
    required LlmModel model,
    required bool first,
    required bool last,
  }) {
    final newTranscript = _copyTranscript();
    assert(() {
      if (newTranscript[model]!.length < index + 1) {
        throw Exception('Tried to add to index $index, but length is '
            'only ${newTranscript[model]!.length} for $model');
      }
      return true;
    }());
    final oldMessage = newTranscript[model]![index];
    final newMessage = oldMessage.copyWith(
      body: '${oldMessage.body}$chunk'.sanitize(first, last),
    );
    newTranscript[model]![index] = newMessage;
    return copyWith(transcript: newTranscript);
  }

  TranscriptState completeMessage(LlmModel model) {
    final newTranscript = _copyTranscript();
    newTranscript[model]!.last =
        newTranscript[model]!.last.copyWith(isComplete: true);
    return copyWith(transcript: newTranscript);
  }
}

@Freezed()
class TranscriptEvent with _$TranscriptEvent {
  const factory TranscriptEvent.checkForModel(LlmModel model) = CheckForModel;
  const factory TranscriptEvent.downloadModel(LlmModel model) = DownloadModel;
  const factory TranscriptEvent.setPercentDownloaded(
    LlmModel model,
    int percentDownloaded,
  ) = SetPercentDownloaded;
  const factory TranscriptEvent.deleteModel(LlmModel model) = DeleteModel;
  const factory TranscriptEvent.initEngine(LlmModel model) = InitEngine;
  const factory TranscriptEvent.initializeModelInfo() = InitializeModelInfo;
  const factory TranscriptEvent.updateTemperature(double value) =
      UpdateTemperature;
  const factory TranscriptEvent.updateTopK(int value) = UpdateTopK;
  const factory TranscriptEvent.updateMaxTokens(int value) = UpdateMaxTokens;
  const factory TranscriptEvent.addMessage(
      ChatMessage message, LlmModel model) = AddMessage;
  const factory TranscriptEvent.extendMessage({
    required String chunk,
    required int index,
    required LlmModel model,
    required bool first,
    required bool last,
  }) = ExtendMessage;
  const factory TranscriptEvent.completeResponse(LlmModel model) =
      CompleteResponse;
}

extension on String {
  String sanitize(bool first, bool last) {
    final firstOrLast = <String>['\n', ' '];
    final invalidSubstrings = <String>[
      ':',
      ';',
      TranscriptBloc._begin,
      TranscriptBloc._end,
      MessageOrigin.llm.transcriptName,
      MessageOrigin.user.transcriptName,
    ];
    String val = sanitizeBeginning(
      invalidSubstrings..addAll(first ? firstOrLast : []),
    );
    return val.sanitizeEnd(
      invalidSubstrings..addAll(last ? firstOrLast : []),
    );
  }

  String sanitizeBeginning(List<String> invalidSubstrings) {
    String val = this;
    while (true) {
      String? matchingSubstring;
      for (String invalidSubstring in invalidSubstrings) {
        if (val.startsWith(invalidSubstring)) {
          matchingSubstring = invalidSubstring;
          break;
        }
      }
      if (matchingSubstring != null) {
        val = val.substring(matchingSubstring.length);
      } else {
        break;
      }
    }
    return val;
  }

  String sanitizeEnd(List<String> invalidSubstrings) {
    String val = this;
    while (true) {
      String? matchingSubstring;
      for (String invalidSubstring in invalidSubstrings) {
        if (val.endsWith(invalidSubstring)) {
          matchingSubstring = invalidSubstring;
          break;
        }
      }
      if (matchingSubstring != null) {
        val = val.substring(0, val.length - matchingSubstring.length);
      } else {
        break;
      }
    }
    return val;
  }
}
