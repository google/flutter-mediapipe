// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bloc.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$TranscriptState {
  /// Log of messages for the [selectedModel]. Other models may have other
  /// message logs found on the [TranscriptBloc].
  List<ChatMessage> get transcript => throw _privateConstructorUsedError;

  /// True only after the [ModelLocationProvider] has sorted out the initial
  /// state.
  bool get modelsReady => throw _privateConstructorUsedError;

  /// Engine for the current [selectedModel].
  LlmInferenceEngine? get engine => throw _privateConstructorUsedError;

  /// True if the model is in the process of composing its response.
  dynamic get isLlmTyping => throw _privateConstructorUsedError;

  /// Meta download information about each [LlmModel].
  Map<LlmModel, ModelInfo> get modelInfoMap =>
      throw _privateConstructorUsedError;

  /// Randomness during token sampling selection.
  double get temperature => throw _privateConstructorUsedError;

  /// Top K number of tokens to be sampled from for each decoding step.
  int get topK => throw _privateConstructorUsedError;

  /// The LLM's maximum context window.
  int get maxTokens => throw _privateConstructorUsedError;

  /// Randomness seed.
  int get randomSeed => throw _privateConstructorUsedError;

  /// Error message to show in a toast.
  String? get error => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $TranscriptStateCopyWith<TranscriptState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TranscriptStateCopyWith<$Res> {
  factory $TranscriptStateCopyWith(
          TranscriptState value, $Res Function(TranscriptState) then) =
      _$TranscriptStateCopyWithImpl<$Res, TranscriptState>;
  @useResult
  $Res call(
      {List<ChatMessage> transcript,
      bool modelsReady,
      LlmInferenceEngine? engine,
      dynamic isLlmTyping,
      Map<LlmModel, ModelInfo> modelInfoMap,
      double temperature,
      int topK,
      int maxTokens,
      int randomSeed,
      String? error});
}

/// @nodoc
class _$TranscriptStateCopyWithImpl<$Res, $Val extends TranscriptState>
    implements $TranscriptStateCopyWith<$Res> {
  _$TranscriptStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? transcript = null,
    Object? modelsReady = null,
    Object? engine = freezed,
    Object? isLlmTyping = freezed,
    Object? modelInfoMap = null,
    Object? temperature = null,
    Object? topK = null,
    Object? maxTokens = null,
    Object? randomSeed = null,
    Object? error = freezed,
  }) {
    return _then(_value.copyWith(
      transcript: null == transcript
          ? _value.transcript
          : transcript // ignore: cast_nullable_to_non_nullable
              as List<ChatMessage>,
      modelsReady: null == modelsReady
          ? _value.modelsReady
          : modelsReady // ignore: cast_nullable_to_non_nullable
              as bool,
      engine: freezed == engine
          ? _value.engine
          : engine // ignore: cast_nullable_to_non_nullable
              as LlmInferenceEngine?,
      isLlmTyping: freezed == isLlmTyping
          ? _value.isLlmTyping
          : isLlmTyping // ignore: cast_nullable_to_non_nullable
              as dynamic,
      modelInfoMap: null == modelInfoMap
          ? _value.modelInfoMap
          : modelInfoMap // ignore: cast_nullable_to_non_nullable
              as Map<LlmModel, ModelInfo>,
      temperature: null == temperature
          ? _value.temperature
          : temperature // ignore: cast_nullable_to_non_nullable
              as double,
      topK: null == topK
          ? _value.topK
          : topK // ignore: cast_nullable_to_non_nullable
              as int,
      maxTokens: null == maxTokens
          ? _value.maxTokens
          : maxTokens // ignore: cast_nullable_to_non_nullable
              as int,
      randomSeed: null == randomSeed
          ? _value.randomSeed
          : randomSeed // ignore: cast_nullable_to_non_nullable
              as int,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TranscriptStateImplCopyWith<$Res>
    implements $TranscriptStateCopyWith<$Res> {
  factory _$$TranscriptStateImplCopyWith(_$TranscriptStateImpl value,
          $Res Function(_$TranscriptStateImpl) then) =
      __$$TranscriptStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {List<ChatMessage> transcript,
      bool modelsReady,
      LlmInferenceEngine? engine,
      dynamic isLlmTyping,
      Map<LlmModel, ModelInfo> modelInfoMap,
      double temperature,
      int topK,
      int maxTokens,
      int randomSeed,
      String? error});
}

/// @nodoc
class __$$TranscriptStateImplCopyWithImpl<$Res>
    extends _$TranscriptStateCopyWithImpl<$Res, _$TranscriptStateImpl>
    implements _$$TranscriptStateImplCopyWith<$Res> {
  __$$TranscriptStateImplCopyWithImpl(
      _$TranscriptStateImpl _value, $Res Function(_$TranscriptStateImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? transcript = null,
    Object? modelsReady = null,
    Object? engine = freezed,
    Object? isLlmTyping = freezed,
    Object? modelInfoMap = null,
    Object? temperature = null,
    Object? topK = null,
    Object? maxTokens = null,
    Object? randomSeed = null,
    Object? error = freezed,
  }) {
    return _then(_$TranscriptStateImpl(
      transcript: null == transcript
          ? _value._transcript
          : transcript // ignore: cast_nullable_to_non_nullable
              as List<ChatMessage>,
      modelsReady: null == modelsReady
          ? _value.modelsReady
          : modelsReady // ignore: cast_nullable_to_non_nullable
              as bool,
      engine: freezed == engine
          ? _value.engine
          : engine // ignore: cast_nullable_to_non_nullable
              as LlmInferenceEngine?,
      isLlmTyping: freezed == isLlmTyping ? _value.isLlmTyping! : isLlmTyping,
      modelInfoMap: null == modelInfoMap
          ? _value._modelInfoMap
          : modelInfoMap // ignore: cast_nullable_to_non_nullable
              as Map<LlmModel, ModelInfo>,
      temperature: null == temperature
          ? _value.temperature
          : temperature // ignore: cast_nullable_to_non_nullable
              as double,
      topK: null == topK
          ? _value.topK
          : topK // ignore: cast_nullable_to_non_nullable
              as int,
      maxTokens: null == maxTokens
          ? _value.maxTokens
          : maxTokens // ignore: cast_nullable_to_non_nullable
              as int,
      randomSeed: null == randomSeed
          ? _value.randomSeed
          : randomSeed // ignore: cast_nullable_to_non_nullable
              as int,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$TranscriptStateImpl extends _TranscriptState {
  _$TranscriptStateImpl(
      {final List<ChatMessage> transcript = const <ChatMessage>[],
      this.modelsReady = false,
      this.engine,
      this.isLlmTyping = false,
      required final Map<LlmModel, ModelInfo> modelInfoMap,
      this.temperature = 0.8,
      this.topK = 40,
      this.maxTokens = 1024,
      required this.randomSeed,
      this.error})
      : _transcript = transcript,
        _modelInfoMap = modelInfoMap,
        super._();

  /// Log of messages for the [selectedModel]. Other models may have other
  /// message logs found on the [TranscriptBloc].
  final List<ChatMessage> _transcript;

  /// Log of messages for the [selectedModel]. Other models may have other
  /// message logs found on the [TranscriptBloc].
  @override
  @JsonKey()
  List<ChatMessage> get transcript {
    if (_transcript is EqualUnmodifiableListView) return _transcript;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_transcript);
  }

  /// True only after the [ModelLocationProvider] has sorted out the initial
  /// state.
  @override
  @JsonKey()
  final bool modelsReady;

  /// Engine for the current [selectedModel].
  @override
  final LlmInferenceEngine? engine;

  /// True if the model is in the process of composing its response.
  @override
  @JsonKey()
  final dynamic isLlmTyping;

  /// Meta download information about each [LlmModel].
  final Map<LlmModel, ModelInfo> _modelInfoMap;

  /// Meta download information about each [LlmModel].
  @override
  Map<LlmModel, ModelInfo> get modelInfoMap {
    if (_modelInfoMap is EqualUnmodifiableMapView) return _modelInfoMap;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_modelInfoMap);
  }

  /// Randomness during token sampling selection.
  @override
  @JsonKey()
  final double temperature;

  /// Top K number of tokens to be sampled from for each decoding step.
  @override
  @JsonKey()
  final int topK;

  /// The LLM's maximum context window.
  @override
  @JsonKey()
  final int maxTokens;

  /// Randomness seed.
  @override
  final int randomSeed;

  /// Error message to show in a toast.
  @override
  final String? error;

  @override
  String toString() {
    return 'TranscriptState(transcript: $transcript, modelsReady: $modelsReady, engine: $engine, isLlmTyping: $isLlmTyping, modelInfoMap: $modelInfoMap, temperature: $temperature, topK: $topK, maxTokens: $maxTokens, randomSeed: $randomSeed, error: $error)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TranscriptStateImpl &&
            const DeepCollectionEquality()
                .equals(other._transcript, _transcript) &&
            (identical(other.modelsReady, modelsReady) ||
                other.modelsReady == modelsReady) &&
            (identical(other.engine, engine) || other.engine == engine) &&
            const DeepCollectionEquality()
                .equals(other.isLlmTyping, isLlmTyping) &&
            const DeepCollectionEquality()
                .equals(other._modelInfoMap, _modelInfoMap) &&
            (identical(other.temperature, temperature) ||
                other.temperature == temperature) &&
            (identical(other.topK, topK) || other.topK == topK) &&
            (identical(other.maxTokens, maxTokens) ||
                other.maxTokens == maxTokens) &&
            (identical(other.randomSeed, randomSeed) ||
                other.randomSeed == randomSeed) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_transcript),
      modelsReady,
      engine,
      const DeepCollectionEquality().hash(isLlmTyping),
      const DeepCollectionEquality().hash(_modelInfoMap),
      temperature,
      topK,
      maxTokens,
      randomSeed,
      error);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$TranscriptStateImplCopyWith<_$TranscriptStateImpl> get copyWith =>
      __$$TranscriptStateImplCopyWithImpl<_$TranscriptStateImpl>(
          this, _$identity);
}

abstract class _TranscriptState extends TranscriptState {
  factory _TranscriptState(
      {final List<ChatMessage> transcript,
      final bool modelsReady,
      final LlmInferenceEngine? engine,
      final dynamic isLlmTyping,
      required final Map<LlmModel, ModelInfo> modelInfoMap,
      final double temperature,
      final int topK,
      final int maxTokens,
      required final int randomSeed,
      final String? error}) = _$TranscriptStateImpl;
  _TranscriptState._() : super._();

  @override

  /// Log of messages for the [selectedModel]. Other models may have other
  /// message logs found on the [TranscriptBloc].
  List<ChatMessage> get transcript;
  @override

  /// True only after the [ModelLocationProvider] has sorted out the initial
  /// state.
  bool get modelsReady;
  @override

  /// Engine for the current [selectedModel].
  LlmInferenceEngine? get engine;
  @override

  /// True if the model is in the process of composing its response.
  dynamic get isLlmTyping;
  @override

  /// Meta download information about each [LlmModel].
  Map<LlmModel, ModelInfo> get modelInfoMap;
  @override

  /// Randomness during token sampling selection.
  double get temperature;
  @override

  /// Top K number of tokens to be sampled from for each decoding step.
  int get topK;
  @override

  /// The LLM's maximum context window.
  int get maxTokens;
  @override

  /// Randomness seed.
  int get randomSeed;
  @override

  /// Error message to show in a toast.
  String? get error;
  @override
  @JsonKey(ignore: true)
  _$$TranscriptStateImplCopyWith<_$TranscriptStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$TranscriptEvent {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(LlmModel model) checkForModel,
    required TResult Function(LlmModel model) downloadModel,
    required TResult Function(LlmModel model, int percentDownloaded)
        setPercentDownloaded,
    required TResult Function(LlmModel model) deleteModel,
    required TResult Function(LlmModel model) initEngine,
    required TResult Function() initializeModelInfo,
    required TResult Function(double value) updateTemperature,
    required TResult Function(int value) updateTopK,
    required TResult Function(int value) updateMaxTokens,
    required TResult Function(LlmModel model) setTranscript,
    required TResult Function(ChatMessage message, LlmModel model) addMessage,
    required TResult Function(
            String chunk, int index, LlmModel model, bool first, bool last)
        extendMessage,
    required TResult Function(LlmModel model) completeResponse,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(LlmModel model)? checkForModel,
    TResult? Function(LlmModel model)? downloadModel,
    TResult? Function(LlmModel model, int percentDownloaded)?
        setPercentDownloaded,
    TResult? Function(LlmModel model)? deleteModel,
    TResult? Function(LlmModel model)? initEngine,
    TResult? Function()? initializeModelInfo,
    TResult? Function(double value)? updateTemperature,
    TResult? Function(int value)? updateTopK,
    TResult? Function(int value)? updateMaxTokens,
    TResult? Function(LlmModel model)? setTranscript,
    TResult? Function(ChatMessage message, LlmModel model)? addMessage,
    TResult? Function(
            String chunk, int index, LlmModel model, bool first, bool last)?
        extendMessage,
    TResult? Function(LlmModel model)? completeResponse,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(LlmModel model)? checkForModel,
    TResult Function(LlmModel model)? downloadModel,
    TResult Function(LlmModel model, int percentDownloaded)?
        setPercentDownloaded,
    TResult Function(LlmModel model)? deleteModel,
    TResult Function(LlmModel model)? initEngine,
    TResult Function()? initializeModelInfo,
    TResult Function(double value)? updateTemperature,
    TResult Function(int value)? updateTopK,
    TResult Function(int value)? updateMaxTokens,
    TResult Function(LlmModel model)? setTranscript,
    TResult Function(ChatMessage message, LlmModel model)? addMessage,
    TResult Function(
            String chunk, int index, LlmModel model, bool first, bool last)?
        extendMessage,
    TResult Function(LlmModel model)? completeResponse,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(CheckForModel value) checkForModel,
    required TResult Function(DownloadModel value) downloadModel,
    required TResult Function(SetPercentDownloaded value) setPercentDownloaded,
    required TResult Function(DeleteModel value) deleteModel,
    required TResult Function(InitEngine value) initEngine,
    required TResult Function(InitializeModelInfo value) initializeModelInfo,
    required TResult Function(UpdateTemperature value) updateTemperature,
    required TResult Function(UpdateTopK value) updateTopK,
    required TResult Function(UpdateMaxTokens value) updateMaxTokens,
    required TResult Function(SetTranscript value) setTranscript,
    required TResult Function(AddMessage value) addMessage,
    required TResult Function(ExtendMessage value) extendMessage,
    required TResult Function(CompleteResponse value) completeResponse,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(CheckForModel value)? checkForModel,
    TResult? Function(DownloadModel value)? downloadModel,
    TResult? Function(SetPercentDownloaded value)? setPercentDownloaded,
    TResult? Function(DeleteModel value)? deleteModel,
    TResult? Function(InitEngine value)? initEngine,
    TResult? Function(InitializeModelInfo value)? initializeModelInfo,
    TResult? Function(UpdateTemperature value)? updateTemperature,
    TResult? Function(UpdateTopK value)? updateTopK,
    TResult? Function(UpdateMaxTokens value)? updateMaxTokens,
    TResult? Function(SetTranscript value)? setTranscript,
    TResult? Function(AddMessage value)? addMessage,
    TResult? Function(ExtendMessage value)? extendMessage,
    TResult? Function(CompleteResponse value)? completeResponse,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(CheckForModel value)? checkForModel,
    TResult Function(DownloadModel value)? downloadModel,
    TResult Function(SetPercentDownloaded value)? setPercentDownloaded,
    TResult Function(DeleteModel value)? deleteModel,
    TResult Function(InitEngine value)? initEngine,
    TResult Function(InitializeModelInfo value)? initializeModelInfo,
    TResult Function(UpdateTemperature value)? updateTemperature,
    TResult Function(UpdateTopK value)? updateTopK,
    TResult Function(UpdateMaxTokens value)? updateMaxTokens,
    TResult Function(SetTranscript value)? setTranscript,
    TResult Function(AddMessage value)? addMessage,
    TResult Function(ExtendMessage value)? extendMessage,
    TResult Function(CompleteResponse value)? completeResponse,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TranscriptEventCopyWith<$Res> {
  factory $TranscriptEventCopyWith(
          TranscriptEvent value, $Res Function(TranscriptEvent) then) =
      _$TranscriptEventCopyWithImpl<$Res, TranscriptEvent>;
}

/// @nodoc
class _$TranscriptEventCopyWithImpl<$Res, $Val extends TranscriptEvent>
    implements $TranscriptEventCopyWith<$Res> {
  _$TranscriptEventCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;
}

/// @nodoc
abstract class _$$CheckForModelImplCopyWith<$Res> {
  factory _$$CheckForModelImplCopyWith(
          _$CheckForModelImpl value, $Res Function(_$CheckForModelImpl) then) =
      __$$CheckForModelImplCopyWithImpl<$Res>;
  @useResult
  $Res call({LlmModel model});
}

/// @nodoc
class __$$CheckForModelImplCopyWithImpl<$Res>
    extends _$TranscriptEventCopyWithImpl<$Res, _$CheckForModelImpl>
    implements _$$CheckForModelImplCopyWith<$Res> {
  __$$CheckForModelImplCopyWithImpl(
      _$CheckForModelImpl _value, $Res Function(_$CheckForModelImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? model = null,
  }) {
    return _then(_$CheckForModelImpl(
      null == model
          ? _value.model
          : model // ignore: cast_nullable_to_non_nullable
              as LlmModel,
    ));
  }
}

/// @nodoc

class _$CheckForModelImpl implements CheckForModel {
  const _$CheckForModelImpl(this.model);

  @override
  final LlmModel model;

  @override
  String toString() {
    return 'TranscriptEvent.checkForModel(model: $model)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CheckForModelImpl &&
            (identical(other.model, model) || other.model == model));
  }

  @override
  int get hashCode => Object.hash(runtimeType, model);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$CheckForModelImplCopyWith<_$CheckForModelImpl> get copyWith =>
      __$$CheckForModelImplCopyWithImpl<_$CheckForModelImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(LlmModel model) checkForModel,
    required TResult Function(LlmModel model) downloadModel,
    required TResult Function(LlmModel model, int percentDownloaded)
        setPercentDownloaded,
    required TResult Function(LlmModel model) deleteModel,
    required TResult Function(LlmModel model) initEngine,
    required TResult Function() initializeModelInfo,
    required TResult Function(double value) updateTemperature,
    required TResult Function(int value) updateTopK,
    required TResult Function(int value) updateMaxTokens,
    required TResult Function(LlmModel model) setTranscript,
    required TResult Function(ChatMessage message, LlmModel model) addMessage,
    required TResult Function(
            String chunk, int index, LlmModel model, bool first, bool last)
        extendMessage,
    required TResult Function(LlmModel model) completeResponse,
  }) {
    return checkForModel(model);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(LlmModel model)? checkForModel,
    TResult? Function(LlmModel model)? downloadModel,
    TResult? Function(LlmModel model, int percentDownloaded)?
        setPercentDownloaded,
    TResult? Function(LlmModel model)? deleteModel,
    TResult? Function(LlmModel model)? initEngine,
    TResult? Function()? initializeModelInfo,
    TResult? Function(double value)? updateTemperature,
    TResult? Function(int value)? updateTopK,
    TResult? Function(int value)? updateMaxTokens,
    TResult? Function(LlmModel model)? setTranscript,
    TResult? Function(ChatMessage message, LlmModel model)? addMessage,
    TResult? Function(
            String chunk, int index, LlmModel model, bool first, bool last)?
        extendMessage,
    TResult? Function(LlmModel model)? completeResponse,
  }) {
    return checkForModel?.call(model);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(LlmModel model)? checkForModel,
    TResult Function(LlmModel model)? downloadModel,
    TResult Function(LlmModel model, int percentDownloaded)?
        setPercentDownloaded,
    TResult Function(LlmModel model)? deleteModel,
    TResult Function(LlmModel model)? initEngine,
    TResult Function()? initializeModelInfo,
    TResult Function(double value)? updateTemperature,
    TResult Function(int value)? updateTopK,
    TResult Function(int value)? updateMaxTokens,
    TResult Function(LlmModel model)? setTranscript,
    TResult Function(ChatMessage message, LlmModel model)? addMessage,
    TResult Function(
            String chunk, int index, LlmModel model, bool first, bool last)?
        extendMessage,
    TResult Function(LlmModel model)? completeResponse,
    required TResult orElse(),
  }) {
    if (checkForModel != null) {
      return checkForModel(model);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(CheckForModel value) checkForModel,
    required TResult Function(DownloadModel value) downloadModel,
    required TResult Function(SetPercentDownloaded value) setPercentDownloaded,
    required TResult Function(DeleteModel value) deleteModel,
    required TResult Function(InitEngine value) initEngine,
    required TResult Function(InitializeModelInfo value) initializeModelInfo,
    required TResult Function(UpdateTemperature value) updateTemperature,
    required TResult Function(UpdateTopK value) updateTopK,
    required TResult Function(UpdateMaxTokens value) updateMaxTokens,
    required TResult Function(SetTranscript value) setTranscript,
    required TResult Function(AddMessage value) addMessage,
    required TResult Function(ExtendMessage value) extendMessage,
    required TResult Function(CompleteResponse value) completeResponse,
  }) {
    return checkForModel(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(CheckForModel value)? checkForModel,
    TResult? Function(DownloadModel value)? downloadModel,
    TResult? Function(SetPercentDownloaded value)? setPercentDownloaded,
    TResult? Function(DeleteModel value)? deleteModel,
    TResult? Function(InitEngine value)? initEngine,
    TResult? Function(InitializeModelInfo value)? initializeModelInfo,
    TResult? Function(UpdateTemperature value)? updateTemperature,
    TResult? Function(UpdateTopK value)? updateTopK,
    TResult? Function(UpdateMaxTokens value)? updateMaxTokens,
    TResult? Function(SetTranscript value)? setTranscript,
    TResult? Function(AddMessage value)? addMessage,
    TResult? Function(ExtendMessage value)? extendMessage,
    TResult? Function(CompleteResponse value)? completeResponse,
  }) {
    return checkForModel?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(CheckForModel value)? checkForModel,
    TResult Function(DownloadModel value)? downloadModel,
    TResult Function(SetPercentDownloaded value)? setPercentDownloaded,
    TResult Function(DeleteModel value)? deleteModel,
    TResult Function(InitEngine value)? initEngine,
    TResult Function(InitializeModelInfo value)? initializeModelInfo,
    TResult Function(UpdateTemperature value)? updateTemperature,
    TResult Function(UpdateTopK value)? updateTopK,
    TResult Function(UpdateMaxTokens value)? updateMaxTokens,
    TResult Function(SetTranscript value)? setTranscript,
    TResult Function(AddMessage value)? addMessage,
    TResult Function(ExtendMessage value)? extendMessage,
    TResult Function(CompleteResponse value)? completeResponse,
    required TResult orElse(),
  }) {
    if (checkForModel != null) {
      return checkForModel(this);
    }
    return orElse();
  }
}

abstract class CheckForModel implements TranscriptEvent {
  const factory CheckForModel(final LlmModel model) = _$CheckForModelImpl;

  LlmModel get model;
  @JsonKey(ignore: true)
  _$$CheckForModelImplCopyWith<_$CheckForModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$DownloadModelImplCopyWith<$Res> {
  factory _$$DownloadModelImplCopyWith(
          _$DownloadModelImpl value, $Res Function(_$DownloadModelImpl) then) =
      __$$DownloadModelImplCopyWithImpl<$Res>;
  @useResult
  $Res call({LlmModel model});
}

/// @nodoc
class __$$DownloadModelImplCopyWithImpl<$Res>
    extends _$TranscriptEventCopyWithImpl<$Res, _$DownloadModelImpl>
    implements _$$DownloadModelImplCopyWith<$Res> {
  __$$DownloadModelImplCopyWithImpl(
      _$DownloadModelImpl _value, $Res Function(_$DownloadModelImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? model = null,
  }) {
    return _then(_$DownloadModelImpl(
      null == model
          ? _value.model
          : model // ignore: cast_nullable_to_non_nullable
              as LlmModel,
    ));
  }
}

/// @nodoc

class _$DownloadModelImpl implements DownloadModel {
  const _$DownloadModelImpl(this.model);

  @override
  final LlmModel model;

  @override
  String toString() {
    return 'TranscriptEvent.downloadModel(model: $model)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DownloadModelImpl &&
            (identical(other.model, model) || other.model == model));
  }

  @override
  int get hashCode => Object.hash(runtimeType, model);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$DownloadModelImplCopyWith<_$DownloadModelImpl> get copyWith =>
      __$$DownloadModelImplCopyWithImpl<_$DownloadModelImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(LlmModel model) checkForModel,
    required TResult Function(LlmModel model) downloadModel,
    required TResult Function(LlmModel model, int percentDownloaded)
        setPercentDownloaded,
    required TResult Function(LlmModel model) deleteModel,
    required TResult Function(LlmModel model) initEngine,
    required TResult Function() initializeModelInfo,
    required TResult Function(double value) updateTemperature,
    required TResult Function(int value) updateTopK,
    required TResult Function(int value) updateMaxTokens,
    required TResult Function(LlmModel model) setTranscript,
    required TResult Function(ChatMessage message, LlmModel model) addMessage,
    required TResult Function(
            String chunk, int index, LlmModel model, bool first, bool last)
        extendMessage,
    required TResult Function(LlmModel model) completeResponse,
  }) {
    return downloadModel(model);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(LlmModel model)? checkForModel,
    TResult? Function(LlmModel model)? downloadModel,
    TResult? Function(LlmModel model, int percentDownloaded)?
        setPercentDownloaded,
    TResult? Function(LlmModel model)? deleteModel,
    TResult? Function(LlmModel model)? initEngine,
    TResult? Function()? initializeModelInfo,
    TResult? Function(double value)? updateTemperature,
    TResult? Function(int value)? updateTopK,
    TResult? Function(int value)? updateMaxTokens,
    TResult? Function(LlmModel model)? setTranscript,
    TResult? Function(ChatMessage message, LlmModel model)? addMessage,
    TResult? Function(
            String chunk, int index, LlmModel model, bool first, bool last)?
        extendMessage,
    TResult? Function(LlmModel model)? completeResponse,
  }) {
    return downloadModel?.call(model);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(LlmModel model)? checkForModel,
    TResult Function(LlmModel model)? downloadModel,
    TResult Function(LlmModel model, int percentDownloaded)?
        setPercentDownloaded,
    TResult Function(LlmModel model)? deleteModel,
    TResult Function(LlmModel model)? initEngine,
    TResult Function()? initializeModelInfo,
    TResult Function(double value)? updateTemperature,
    TResult Function(int value)? updateTopK,
    TResult Function(int value)? updateMaxTokens,
    TResult Function(LlmModel model)? setTranscript,
    TResult Function(ChatMessage message, LlmModel model)? addMessage,
    TResult Function(
            String chunk, int index, LlmModel model, bool first, bool last)?
        extendMessage,
    TResult Function(LlmModel model)? completeResponse,
    required TResult orElse(),
  }) {
    if (downloadModel != null) {
      return downloadModel(model);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(CheckForModel value) checkForModel,
    required TResult Function(DownloadModel value) downloadModel,
    required TResult Function(SetPercentDownloaded value) setPercentDownloaded,
    required TResult Function(DeleteModel value) deleteModel,
    required TResult Function(InitEngine value) initEngine,
    required TResult Function(InitializeModelInfo value) initializeModelInfo,
    required TResult Function(UpdateTemperature value) updateTemperature,
    required TResult Function(UpdateTopK value) updateTopK,
    required TResult Function(UpdateMaxTokens value) updateMaxTokens,
    required TResult Function(SetTranscript value) setTranscript,
    required TResult Function(AddMessage value) addMessage,
    required TResult Function(ExtendMessage value) extendMessage,
    required TResult Function(CompleteResponse value) completeResponse,
  }) {
    return downloadModel(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(CheckForModel value)? checkForModel,
    TResult? Function(DownloadModel value)? downloadModel,
    TResult? Function(SetPercentDownloaded value)? setPercentDownloaded,
    TResult? Function(DeleteModel value)? deleteModel,
    TResult? Function(InitEngine value)? initEngine,
    TResult? Function(InitializeModelInfo value)? initializeModelInfo,
    TResult? Function(UpdateTemperature value)? updateTemperature,
    TResult? Function(UpdateTopK value)? updateTopK,
    TResult? Function(UpdateMaxTokens value)? updateMaxTokens,
    TResult? Function(SetTranscript value)? setTranscript,
    TResult? Function(AddMessage value)? addMessage,
    TResult? Function(ExtendMessage value)? extendMessage,
    TResult? Function(CompleteResponse value)? completeResponse,
  }) {
    return downloadModel?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(CheckForModel value)? checkForModel,
    TResult Function(DownloadModel value)? downloadModel,
    TResult Function(SetPercentDownloaded value)? setPercentDownloaded,
    TResult Function(DeleteModel value)? deleteModel,
    TResult Function(InitEngine value)? initEngine,
    TResult Function(InitializeModelInfo value)? initializeModelInfo,
    TResult Function(UpdateTemperature value)? updateTemperature,
    TResult Function(UpdateTopK value)? updateTopK,
    TResult Function(UpdateMaxTokens value)? updateMaxTokens,
    TResult Function(SetTranscript value)? setTranscript,
    TResult Function(AddMessage value)? addMessage,
    TResult Function(ExtendMessage value)? extendMessage,
    TResult Function(CompleteResponse value)? completeResponse,
    required TResult orElse(),
  }) {
    if (downloadModel != null) {
      return downloadModel(this);
    }
    return orElse();
  }
}

abstract class DownloadModel implements TranscriptEvent {
  const factory DownloadModel(final LlmModel model) = _$DownloadModelImpl;

  LlmModel get model;
  @JsonKey(ignore: true)
  _$$DownloadModelImplCopyWith<_$DownloadModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$SetPercentDownloadedImplCopyWith<$Res> {
  factory _$$SetPercentDownloadedImplCopyWith(_$SetPercentDownloadedImpl value,
          $Res Function(_$SetPercentDownloadedImpl) then) =
      __$$SetPercentDownloadedImplCopyWithImpl<$Res>;
  @useResult
  $Res call({LlmModel model, int percentDownloaded});
}

/// @nodoc
class __$$SetPercentDownloadedImplCopyWithImpl<$Res>
    extends _$TranscriptEventCopyWithImpl<$Res, _$SetPercentDownloadedImpl>
    implements _$$SetPercentDownloadedImplCopyWith<$Res> {
  __$$SetPercentDownloadedImplCopyWithImpl(_$SetPercentDownloadedImpl _value,
      $Res Function(_$SetPercentDownloadedImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? model = null,
    Object? percentDownloaded = null,
  }) {
    return _then(_$SetPercentDownloadedImpl(
      null == model
          ? _value.model
          : model // ignore: cast_nullable_to_non_nullable
              as LlmModel,
      null == percentDownloaded
          ? _value.percentDownloaded
          : percentDownloaded // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class _$SetPercentDownloadedImpl implements SetPercentDownloaded {
  const _$SetPercentDownloadedImpl(this.model, this.percentDownloaded);

  @override
  final LlmModel model;
  @override
  final int percentDownloaded;

  @override
  String toString() {
    return 'TranscriptEvent.setPercentDownloaded(model: $model, percentDownloaded: $percentDownloaded)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SetPercentDownloadedImpl &&
            (identical(other.model, model) || other.model == model) &&
            (identical(other.percentDownloaded, percentDownloaded) ||
                other.percentDownloaded == percentDownloaded));
  }

  @override
  int get hashCode => Object.hash(runtimeType, model, percentDownloaded);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$SetPercentDownloadedImplCopyWith<_$SetPercentDownloadedImpl>
      get copyWith =>
          __$$SetPercentDownloadedImplCopyWithImpl<_$SetPercentDownloadedImpl>(
              this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(LlmModel model) checkForModel,
    required TResult Function(LlmModel model) downloadModel,
    required TResult Function(LlmModel model, int percentDownloaded)
        setPercentDownloaded,
    required TResult Function(LlmModel model) deleteModel,
    required TResult Function(LlmModel model) initEngine,
    required TResult Function() initializeModelInfo,
    required TResult Function(double value) updateTemperature,
    required TResult Function(int value) updateTopK,
    required TResult Function(int value) updateMaxTokens,
    required TResult Function(LlmModel model) setTranscript,
    required TResult Function(ChatMessage message, LlmModel model) addMessage,
    required TResult Function(
            String chunk, int index, LlmModel model, bool first, bool last)
        extendMessage,
    required TResult Function(LlmModel model) completeResponse,
  }) {
    return setPercentDownloaded(model, percentDownloaded);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(LlmModel model)? checkForModel,
    TResult? Function(LlmModel model)? downloadModel,
    TResult? Function(LlmModel model, int percentDownloaded)?
        setPercentDownloaded,
    TResult? Function(LlmModel model)? deleteModel,
    TResult? Function(LlmModel model)? initEngine,
    TResult? Function()? initializeModelInfo,
    TResult? Function(double value)? updateTemperature,
    TResult? Function(int value)? updateTopK,
    TResult? Function(int value)? updateMaxTokens,
    TResult? Function(LlmModel model)? setTranscript,
    TResult? Function(ChatMessage message, LlmModel model)? addMessage,
    TResult? Function(
            String chunk, int index, LlmModel model, bool first, bool last)?
        extendMessage,
    TResult? Function(LlmModel model)? completeResponse,
  }) {
    return setPercentDownloaded?.call(model, percentDownloaded);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(LlmModel model)? checkForModel,
    TResult Function(LlmModel model)? downloadModel,
    TResult Function(LlmModel model, int percentDownloaded)?
        setPercentDownloaded,
    TResult Function(LlmModel model)? deleteModel,
    TResult Function(LlmModel model)? initEngine,
    TResult Function()? initializeModelInfo,
    TResult Function(double value)? updateTemperature,
    TResult Function(int value)? updateTopK,
    TResult Function(int value)? updateMaxTokens,
    TResult Function(LlmModel model)? setTranscript,
    TResult Function(ChatMessage message, LlmModel model)? addMessage,
    TResult Function(
            String chunk, int index, LlmModel model, bool first, bool last)?
        extendMessage,
    TResult Function(LlmModel model)? completeResponse,
    required TResult orElse(),
  }) {
    if (setPercentDownloaded != null) {
      return setPercentDownloaded(model, percentDownloaded);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(CheckForModel value) checkForModel,
    required TResult Function(DownloadModel value) downloadModel,
    required TResult Function(SetPercentDownloaded value) setPercentDownloaded,
    required TResult Function(DeleteModel value) deleteModel,
    required TResult Function(InitEngine value) initEngine,
    required TResult Function(InitializeModelInfo value) initializeModelInfo,
    required TResult Function(UpdateTemperature value) updateTemperature,
    required TResult Function(UpdateTopK value) updateTopK,
    required TResult Function(UpdateMaxTokens value) updateMaxTokens,
    required TResult Function(SetTranscript value) setTranscript,
    required TResult Function(AddMessage value) addMessage,
    required TResult Function(ExtendMessage value) extendMessage,
    required TResult Function(CompleteResponse value) completeResponse,
  }) {
    return setPercentDownloaded(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(CheckForModel value)? checkForModel,
    TResult? Function(DownloadModel value)? downloadModel,
    TResult? Function(SetPercentDownloaded value)? setPercentDownloaded,
    TResult? Function(DeleteModel value)? deleteModel,
    TResult? Function(InitEngine value)? initEngine,
    TResult? Function(InitializeModelInfo value)? initializeModelInfo,
    TResult? Function(UpdateTemperature value)? updateTemperature,
    TResult? Function(UpdateTopK value)? updateTopK,
    TResult? Function(UpdateMaxTokens value)? updateMaxTokens,
    TResult? Function(SetTranscript value)? setTranscript,
    TResult? Function(AddMessage value)? addMessage,
    TResult? Function(ExtendMessage value)? extendMessage,
    TResult? Function(CompleteResponse value)? completeResponse,
  }) {
    return setPercentDownloaded?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(CheckForModel value)? checkForModel,
    TResult Function(DownloadModel value)? downloadModel,
    TResult Function(SetPercentDownloaded value)? setPercentDownloaded,
    TResult Function(DeleteModel value)? deleteModel,
    TResult Function(InitEngine value)? initEngine,
    TResult Function(InitializeModelInfo value)? initializeModelInfo,
    TResult Function(UpdateTemperature value)? updateTemperature,
    TResult Function(UpdateTopK value)? updateTopK,
    TResult Function(UpdateMaxTokens value)? updateMaxTokens,
    TResult Function(SetTranscript value)? setTranscript,
    TResult Function(AddMessage value)? addMessage,
    TResult Function(ExtendMessage value)? extendMessage,
    TResult Function(CompleteResponse value)? completeResponse,
    required TResult orElse(),
  }) {
    if (setPercentDownloaded != null) {
      return setPercentDownloaded(this);
    }
    return orElse();
  }
}

abstract class SetPercentDownloaded implements TranscriptEvent {
  const factory SetPercentDownloaded(
          final LlmModel model, final int percentDownloaded) =
      _$SetPercentDownloadedImpl;

  LlmModel get model;
  int get percentDownloaded;
  @JsonKey(ignore: true)
  _$$SetPercentDownloadedImplCopyWith<_$SetPercentDownloadedImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$DeleteModelImplCopyWith<$Res> {
  factory _$$DeleteModelImplCopyWith(
          _$DeleteModelImpl value, $Res Function(_$DeleteModelImpl) then) =
      __$$DeleteModelImplCopyWithImpl<$Res>;
  @useResult
  $Res call({LlmModel model});
}

/// @nodoc
class __$$DeleteModelImplCopyWithImpl<$Res>
    extends _$TranscriptEventCopyWithImpl<$Res, _$DeleteModelImpl>
    implements _$$DeleteModelImplCopyWith<$Res> {
  __$$DeleteModelImplCopyWithImpl(
      _$DeleteModelImpl _value, $Res Function(_$DeleteModelImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? model = null,
  }) {
    return _then(_$DeleteModelImpl(
      null == model
          ? _value.model
          : model // ignore: cast_nullable_to_non_nullable
              as LlmModel,
    ));
  }
}

/// @nodoc

class _$DeleteModelImpl implements DeleteModel {
  const _$DeleteModelImpl(this.model);

  @override
  final LlmModel model;

  @override
  String toString() {
    return 'TranscriptEvent.deleteModel(model: $model)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DeleteModelImpl &&
            (identical(other.model, model) || other.model == model));
  }

  @override
  int get hashCode => Object.hash(runtimeType, model);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$DeleteModelImplCopyWith<_$DeleteModelImpl> get copyWith =>
      __$$DeleteModelImplCopyWithImpl<_$DeleteModelImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(LlmModel model) checkForModel,
    required TResult Function(LlmModel model) downloadModel,
    required TResult Function(LlmModel model, int percentDownloaded)
        setPercentDownloaded,
    required TResult Function(LlmModel model) deleteModel,
    required TResult Function(LlmModel model) initEngine,
    required TResult Function() initializeModelInfo,
    required TResult Function(double value) updateTemperature,
    required TResult Function(int value) updateTopK,
    required TResult Function(int value) updateMaxTokens,
    required TResult Function(LlmModel model) setTranscript,
    required TResult Function(ChatMessage message, LlmModel model) addMessage,
    required TResult Function(
            String chunk, int index, LlmModel model, bool first, bool last)
        extendMessage,
    required TResult Function(LlmModel model) completeResponse,
  }) {
    return deleteModel(model);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(LlmModel model)? checkForModel,
    TResult? Function(LlmModel model)? downloadModel,
    TResult? Function(LlmModel model, int percentDownloaded)?
        setPercentDownloaded,
    TResult? Function(LlmModel model)? deleteModel,
    TResult? Function(LlmModel model)? initEngine,
    TResult? Function()? initializeModelInfo,
    TResult? Function(double value)? updateTemperature,
    TResult? Function(int value)? updateTopK,
    TResult? Function(int value)? updateMaxTokens,
    TResult? Function(LlmModel model)? setTranscript,
    TResult? Function(ChatMessage message, LlmModel model)? addMessage,
    TResult? Function(
            String chunk, int index, LlmModel model, bool first, bool last)?
        extendMessage,
    TResult? Function(LlmModel model)? completeResponse,
  }) {
    return deleteModel?.call(model);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(LlmModel model)? checkForModel,
    TResult Function(LlmModel model)? downloadModel,
    TResult Function(LlmModel model, int percentDownloaded)?
        setPercentDownloaded,
    TResult Function(LlmModel model)? deleteModel,
    TResult Function(LlmModel model)? initEngine,
    TResult Function()? initializeModelInfo,
    TResult Function(double value)? updateTemperature,
    TResult Function(int value)? updateTopK,
    TResult Function(int value)? updateMaxTokens,
    TResult Function(LlmModel model)? setTranscript,
    TResult Function(ChatMessage message, LlmModel model)? addMessage,
    TResult Function(
            String chunk, int index, LlmModel model, bool first, bool last)?
        extendMessage,
    TResult Function(LlmModel model)? completeResponse,
    required TResult orElse(),
  }) {
    if (deleteModel != null) {
      return deleteModel(model);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(CheckForModel value) checkForModel,
    required TResult Function(DownloadModel value) downloadModel,
    required TResult Function(SetPercentDownloaded value) setPercentDownloaded,
    required TResult Function(DeleteModel value) deleteModel,
    required TResult Function(InitEngine value) initEngine,
    required TResult Function(InitializeModelInfo value) initializeModelInfo,
    required TResult Function(UpdateTemperature value) updateTemperature,
    required TResult Function(UpdateTopK value) updateTopK,
    required TResult Function(UpdateMaxTokens value) updateMaxTokens,
    required TResult Function(SetTranscript value) setTranscript,
    required TResult Function(AddMessage value) addMessage,
    required TResult Function(ExtendMessage value) extendMessage,
    required TResult Function(CompleteResponse value) completeResponse,
  }) {
    return deleteModel(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(CheckForModel value)? checkForModel,
    TResult? Function(DownloadModel value)? downloadModel,
    TResult? Function(SetPercentDownloaded value)? setPercentDownloaded,
    TResult? Function(DeleteModel value)? deleteModel,
    TResult? Function(InitEngine value)? initEngine,
    TResult? Function(InitializeModelInfo value)? initializeModelInfo,
    TResult? Function(UpdateTemperature value)? updateTemperature,
    TResult? Function(UpdateTopK value)? updateTopK,
    TResult? Function(UpdateMaxTokens value)? updateMaxTokens,
    TResult? Function(SetTranscript value)? setTranscript,
    TResult? Function(AddMessage value)? addMessage,
    TResult? Function(ExtendMessage value)? extendMessage,
    TResult? Function(CompleteResponse value)? completeResponse,
  }) {
    return deleteModel?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(CheckForModel value)? checkForModel,
    TResult Function(DownloadModel value)? downloadModel,
    TResult Function(SetPercentDownloaded value)? setPercentDownloaded,
    TResult Function(DeleteModel value)? deleteModel,
    TResult Function(InitEngine value)? initEngine,
    TResult Function(InitializeModelInfo value)? initializeModelInfo,
    TResult Function(UpdateTemperature value)? updateTemperature,
    TResult Function(UpdateTopK value)? updateTopK,
    TResult Function(UpdateMaxTokens value)? updateMaxTokens,
    TResult Function(SetTranscript value)? setTranscript,
    TResult Function(AddMessage value)? addMessage,
    TResult Function(ExtendMessage value)? extendMessage,
    TResult Function(CompleteResponse value)? completeResponse,
    required TResult orElse(),
  }) {
    if (deleteModel != null) {
      return deleteModel(this);
    }
    return orElse();
  }
}

abstract class DeleteModel implements TranscriptEvent {
  const factory DeleteModel(final LlmModel model) = _$DeleteModelImpl;

  LlmModel get model;
  @JsonKey(ignore: true)
  _$$DeleteModelImplCopyWith<_$DeleteModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$InitEngineImplCopyWith<$Res> {
  factory _$$InitEngineImplCopyWith(
          _$InitEngineImpl value, $Res Function(_$InitEngineImpl) then) =
      __$$InitEngineImplCopyWithImpl<$Res>;
  @useResult
  $Res call({LlmModel model});
}

/// @nodoc
class __$$InitEngineImplCopyWithImpl<$Res>
    extends _$TranscriptEventCopyWithImpl<$Res, _$InitEngineImpl>
    implements _$$InitEngineImplCopyWith<$Res> {
  __$$InitEngineImplCopyWithImpl(
      _$InitEngineImpl _value, $Res Function(_$InitEngineImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? model = null,
  }) {
    return _then(_$InitEngineImpl(
      null == model
          ? _value.model
          : model // ignore: cast_nullable_to_non_nullable
              as LlmModel,
    ));
  }
}

/// @nodoc

class _$InitEngineImpl implements InitEngine {
  const _$InitEngineImpl(this.model);

  @override
  final LlmModel model;

  @override
  String toString() {
    return 'TranscriptEvent.initEngine(model: $model)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$InitEngineImpl &&
            (identical(other.model, model) || other.model == model));
  }

  @override
  int get hashCode => Object.hash(runtimeType, model);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$InitEngineImplCopyWith<_$InitEngineImpl> get copyWith =>
      __$$InitEngineImplCopyWithImpl<_$InitEngineImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(LlmModel model) checkForModel,
    required TResult Function(LlmModel model) downloadModel,
    required TResult Function(LlmModel model, int percentDownloaded)
        setPercentDownloaded,
    required TResult Function(LlmModel model) deleteModel,
    required TResult Function(LlmModel model) initEngine,
    required TResult Function() initializeModelInfo,
    required TResult Function(double value) updateTemperature,
    required TResult Function(int value) updateTopK,
    required TResult Function(int value) updateMaxTokens,
    required TResult Function(LlmModel model) setTranscript,
    required TResult Function(ChatMessage message, LlmModel model) addMessage,
    required TResult Function(
            String chunk, int index, LlmModel model, bool first, bool last)
        extendMessage,
    required TResult Function(LlmModel model) completeResponse,
  }) {
    return initEngine(model);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(LlmModel model)? checkForModel,
    TResult? Function(LlmModel model)? downloadModel,
    TResult? Function(LlmModel model, int percentDownloaded)?
        setPercentDownloaded,
    TResult? Function(LlmModel model)? deleteModel,
    TResult? Function(LlmModel model)? initEngine,
    TResult? Function()? initializeModelInfo,
    TResult? Function(double value)? updateTemperature,
    TResult? Function(int value)? updateTopK,
    TResult? Function(int value)? updateMaxTokens,
    TResult? Function(LlmModel model)? setTranscript,
    TResult? Function(ChatMessage message, LlmModel model)? addMessage,
    TResult? Function(
            String chunk, int index, LlmModel model, bool first, bool last)?
        extendMessage,
    TResult? Function(LlmModel model)? completeResponse,
  }) {
    return initEngine?.call(model);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(LlmModel model)? checkForModel,
    TResult Function(LlmModel model)? downloadModel,
    TResult Function(LlmModel model, int percentDownloaded)?
        setPercentDownloaded,
    TResult Function(LlmModel model)? deleteModel,
    TResult Function(LlmModel model)? initEngine,
    TResult Function()? initializeModelInfo,
    TResult Function(double value)? updateTemperature,
    TResult Function(int value)? updateTopK,
    TResult Function(int value)? updateMaxTokens,
    TResult Function(LlmModel model)? setTranscript,
    TResult Function(ChatMessage message, LlmModel model)? addMessage,
    TResult Function(
            String chunk, int index, LlmModel model, bool first, bool last)?
        extendMessage,
    TResult Function(LlmModel model)? completeResponse,
    required TResult orElse(),
  }) {
    if (initEngine != null) {
      return initEngine(model);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(CheckForModel value) checkForModel,
    required TResult Function(DownloadModel value) downloadModel,
    required TResult Function(SetPercentDownloaded value) setPercentDownloaded,
    required TResult Function(DeleteModel value) deleteModel,
    required TResult Function(InitEngine value) initEngine,
    required TResult Function(InitializeModelInfo value) initializeModelInfo,
    required TResult Function(UpdateTemperature value) updateTemperature,
    required TResult Function(UpdateTopK value) updateTopK,
    required TResult Function(UpdateMaxTokens value) updateMaxTokens,
    required TResult Function(SetTranscript value) setTranscript,
    required TResult Function(AddMessage value) addMessage,
    required TResult Function(ExtendMessage value) extendMessage,
    required TResult Function(CompleteResponse value) completeResponse,
  }) {
    return initEngine(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(CheckForModel value)? checkForModel,
    TResult? Function(DownloadModel value)? downloadModel,
    TResult? Function(SetPercentDownloaded value)? setPercentDownloaded,
    TResult? Function(DeleteModel value)? deleteModel,
    TResult? Function(InitEngine value)? initEngine,
    TResult? Function(InitializeModelInfo value)? initializeModelInfo,
    TResult? Function(UpdateTemperature value)? updateTemperature,
    TResult? Function(UpdateTopK value)? updateTopK,
    TResult? Function(UpdateMaxTokens value)? updateMaxTokens,
    TResult? Function(SetTranscript value)? setTranscript,
    TResult? Function(AddMessage value)? addMessage,
    TResult? Function(ExtendMessage value)? extendMessage,
    TResult? Function(CompleteResponse value)? completeResponse,
  }) {
    return initEngine?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(CheckForModel value)? checkForModel,
    TResult Function(DownloadModel value)? downloadModel,
    TResult Function(SetPercentDownloaded value)? setPercentDownloaded,
    TResult Function(DeleteModel value)? deleteModel,
    TResult Function(InitEngine value)? initEngine,
    TResult Function(InitializeModelInfo value)? initializeModelInfo,
    TResult Function(UpdateTemperature value)? updateTemperature,
    TResult Function(UpdateTopK value)? updateTopK,
    TResult Function(UpdateMaxTokens value)? updateMaxTokens,
    TResult Function(SetTranscript value)? setTranscript,
    TResult Function(AddMessage value)? addMessage,
    TResult Function(ExtendMessage value)? extendMessage,
    TResult Function(CompleteResponse value)? completeResponse,
    required TResult orElse(),
  }) {
    if (initEngine != null) {
      return initEngine(this);
    }
    return orElse();
  }
}

abstract class InitEngine implements TranscriptEvent {
  const factory InitEngine(final LlmModel model) = _$InitEngineImpl;

  LlmModel get model;
  @JsonKey(ignore: true)
  _$$InitEngineImplCopyWith<_$InitEngineImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$InitializeModelInfoImplCopyWith<$Res> {
  factory _$$InitializeModelInfoImplCopyWith(_$InitializeModelInfoImpl value,
          $Res Function(_$InitializeModelInfoImpl) then) =
      __$$InitializeModelInfoImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$InitializeModelInfoImplCopyWithImpl<$Res>
    extends _$TranscriptEventCopyWithImpl<$Res, _$InitializeModelInfoImpl>
    implements _$$InitializeModelInfoImplCopyWith<$Res> {
  __$$InitializeModelInfoImplCopyWithImpl(_$InitializeModelInfoImpl _value,
      $Res Function(_$InitializeModelInfoImpl) _then)
      : super(_value, _then);
}

/// @nodoc

class _$InitializeModelInfoImpl implements InitializeModelInfo {
  const _$InitializeModelInfoImpl();

  @override
  String toString() {
    return 'TranscriptEvent.initializeModelInfo()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$InitializeModelInfoImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(LlmModel model) checkForModel,
    required TResult Function(LlmModel model) downloadModel,
    required TResult Function(LlmModel model, int percentDownloaded)
        setPercentDownloaded,
    required TResult Function(LlmModel model) deleteModel,
    required TResult Function(LlmModel model) initEngine,
    required TResult Function() initializeModelInfo,
    required TResult Function(double value) updateTemperature,
    required TResult Function(int value) updateTopK,
    required TResult Function(int value) updateMaxTokens,
    required TResult Function(LlmModel model) setTranscript,
    required TResult Function(ChatMessage message, LlmModel model) addMessage,
    required TResult Function(
            String chunk, int index, LlmModel model, bool first, bool last)
        extendMessage,
    required TResult Function(LlmModel model) completeResponse,
  }) {
    return initializeModelInfo();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(LlmModel model)? checkForModel,
    TResult? Function(LlmModel model)? downloadModel,
    TResult? Function(LlmModel model, int percentDownloaded)?
        setPercentDownloaded,
    TResult? Function(LlmModel model)? deleteModel,
    TResult? Function(LlmModel model)? initEngine,
    TResult? Function()? initializeModelInfo,
    TResult? Function(double value)? updateTemperature,
    TResult? Function(int value)? updateTopK,
    TResult? Function(int value)? updateMaxTokens,
    TResult? Function(LlmModel model)? setTranscript,
    TResult? Function(ChatMessage message, LlmModel model)? addMessage,
    TResult? Function(
            String chunk, int index, LlmModel model, bool first, bool last)?
        extendMessage,
    TResult? Function(LlmModel model)? completeResponse,
  }) {
    return initializeModelInfo?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(LlmModel model)? checkForModel,
    TResult Function(LlmModel model)? downloadModel,
    TResult Function(LlmModel model, int percentDownloaded)?
        setPercentDownloaded,
    TResult Function(LlmModel model)? deleteModel,
    TResult Function(LlmModel model)? initEngine,
    TResult Function()? initializeModelInfo,
    TResult Function(double value)? updateTemperature,
    TResult Function(int value)? updateTopK,
    TResult Function(int value)? updateMaxTokens,
    TResult Function(LlmModel model)? setTranscript,
    TResult Function(ChatMessage message, LlmModel model)? addMessage,
    TResult Function(
            String chunk, int index, LlmModel model, bool first, bool last)?
        extendMessage,
    TResult Function(LlmModel model)? completeResponse,
    required TResult orElse(),
  }) {
    if (initializeModelInfo != null) {
      return initializeModelInfo();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(CheckForModel value) checkForModel,
    required TResult Function(DownloadModel value) downloadModel,
    required TResult Function(SetPercentDownloaded value) setPercentDownloaded,
    required TResult Function(DeleteModel value) deleteModel,
    required TResult Function(InitEngine value) initEngine,
    required TResult Function(InitializeModelInfo value) initializeModelInfo,
    required TResult Function(UpdateTemperature value) updateTemperature,
    required TResult Function(UpdateTopK value) updateTopK,
    required TResult Function(UpdateMaxTokens value) updateMaxTokens,
    required TResult Function(SetTranscript value) setTranscript,
    required TResult Function(AddMessage value) addMessage,
    required TResult Function(ExtendMessage value) extendMessage,
    required TResult Function(CompleteResponse value) completeResponse,
  }) {
    return initializeModelInfo(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(CheckForModel value)? checkForModel,
    TResult? Function(DownloadModel value)? downloadModel,
    TResult? Function(SetPercentDownloaded value)? setPercentDownloaded,
    TResult? Function(DeleteModel value)? deleteModel,
    TResult? Function(InitEngine value)? initEngine,
    TResult? Function(InitializeModelInfo value)? initializeModelInfo,
    TResult? Function(UpdateTemperature value)? updateTemperature,
    TResult? Function(UpdateTopK value)? updateTopK,
    TResult? Function(UpdateMaxTokens value)? updateMaxTokens,
    TResult? Function(SetTranscript value)? setTranscript,
    TResult? Function(AddMessage value)? addMessage,
    TResult? Function(ExtendMessage value)? extendMessage,
    TResult? Function(CompleteResponse value)? completeResponse,
  }) {
    return initializeModelInfo?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(CheckForModel value)? checkForModel,
    TResult Function(DownloadModel value)? downloadModel,
    TResult Function(SetPercentDownloaded value)? setPercentDownloaded,
    TResult Function(DeleteModel value)? deleteModel,
    TResult Function(InitEngine value)? initEngine,
    TResult Function(InitializeModelInfo value)? initializeModelInfo,
    TResult Function(UpdateTemperature value)? updateTemperature,
    TResult Function(UpdateTopK value)? updateTopK,
    TResult Function(UpdateMaxTokens value)? updateMaxTokens,
    TResult Function(SetTranscript value)? setTranscript,
    TResult Function(AddMessage value)? addMessage,
    TResult Function(ExtendMessage value)? extendMessage,
    TResult Function(CompleteResponse value)? completeResponse,
    required TResult orElse(),
  }) {
    if (initializeModelInfo != null) {
      return initializeModelInfo(this);
    }
    return orElse();
  }
}

abstract class InitializeModelInfo implements TranscriptEvent {
  const factory InitializeModelInfo() = _$InitializeModelInfoImpl;
}

/// @nodoc
abstract class _$$UpdateTemperatureImplCopyWith<$Res> {
  factory _$$UpdateTemperatureImplCopyWith(_$UpdateTemperatureImpl value,
          $Res Function(_$UpdateTemperatureImpl) then) =
      __$$UpdateTemperatureImplCopyWithImpl<$Res>;
  @useResult
  $Res call({double value});
}

/// @nodoc
class __$$UpdateTemperatureImplCopyWithImpl<$Res>
    extends _$TranscriptEventCopyWithImpl<$Res, _$UpdateTemperatureImpl>
    implements _$$UpdateTemperatureImplCopyWith<$Res> {
  __$$UpdateTemperatureImplCopyWithImpl(_$UpdateTemperatureImpl _value,
      $Res Function(_$UpdateTemperatureImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? value = null,
  }) {
    return _then(_$UpdateTemperatureImpl(
      null == value
          ? _value.value
          : value // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc

class _$UpdateTemperatureImpl implements UpdateTemperature {
  const _$UpdateTemperatureImpl(this.value);

  @override
  final double value;

  @override
  String toString() {
    return 'TranscriptEvent.updateTemperature(value: $value)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UpdateTemperatureImpl &&
            (identical(other.value, value) || other.value == value));
  }

  @override
  int get hashCode => Object.hash(runtimeType, value);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$UpdateTemperatureImplCopyWith<_$UpdateTemperatureImpl> get copyWith =>
      __$$UpdateTemperatureImplCopyWithImpl<_$UpdateTemperatureImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(LlmModel model) checkForModel,
    required TResult Function(LlmModel model) downloadModel,
    required TResult Function(LlmModel model, int percentDownloaded)
        setPercentDownloaded,
    required TResult Function(LlmModel model) deleteModel,
    required TResult Function(LlmModel model) initEngine,
    required TResult Function() initializeModelInfo,
    required TResult Function(double value) updateTemperature,
    required TResult Function(int value) updateTopK,
    required TResult Function(int value) updateMaxTokens,
    required TResult Function(LlmModel model) setTranscript,
    required TResult Function(ChatMessage message, LlmModel model) addMessage,
    required TResult Function(
            String chunk, int index, LlmModel model, bool first, bool last)
        extendMessage,
    required TResult Function(LlmModel model) completeResponse,
  }) {
    return updateTemperature(value);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(LlmModel model)? checkForModel,
    TResult? Function(LlmModel model)? downloadModel,
    TResult? Function(LlmModel model, int percentDownloaded)?
        setPercentDownloaded,
    TResult? Function(LlmModel model)? deleteModel,
    TResult? Function(LlmModel model)? initEngine,
    TResult? Function()? initializeModelInfo,
    TResult? Function(double value)? updateTemperature,
    TResult? Function(int value)? updateTopK,
    TResult? Function(int value)? updateMaxTokens,
    TResult? Function(LlmModel model)? setTranscript,
    TResult? Function(ChatMessage message, LlmModel model)? addMessage,
    TResult? Function(
            String chunk, int index, LlmModel model, bool first, bool last)?
        extendMessage,
    TResult? Function(LlmModel model)? completeResponse,
  }) {
    return updateTemperature?.call(value);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(LlmModel model)? checkForModel,
    TResult Function(LlmModel model)? downloadModel,
    TResult Function(LlmModel model, int percentDownloaded)?
        setPercentDownloaded,
    TResult Function(LlmModel model)? deleteModel,
    TResult Function(LlmModel model)? initEngine,
    TResult Function()? initializeModelInfo,
    TResult Function(double value)? updateTemperature,
    TResult Function(int value)? updateTopK,
    TResult Function(int value)? updateMaxTokens,
    TResult Function(LlmModel model)? setTranscript,
    TResult Function(ChatMessage message, LlmModel model)? addMessage,
    TResult Function(
            String chunk, int index, LlmModel model, bool first, bool last)?
        extendMessage,
    TResult Function(LlmModel model)? completeResponse,
    required TResult orElse(),
  }) {
    if (updateTemperature != null) {
      return updateTemperature(value);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(CheckForModel value) checkForModel,
    required TResult Function(DownloadModel value) downloadModel,
    required TResult Function(SetPercentDownloaded value) setPercentDownloaded,
    required TResult Function(DeleteModel value) deleteModel,
    required TResult Function(InitEngine value) initEngine,
    required TResult Function(InitializeModelInfo value) initializeModelInfo,
    required TResult Function(UpdateTemperature value) updateTemperature,
    required TResult Function(UpdateTopK value) updateTopK,
    required TResult Function(UpdateMaxTokens value) updateMaxTokens,
    required TResult Function(SetTranscript value) setTranscript,
    required TResult Function(AddMessage value) addMessage,
    required TResult Function(ExtendMessage value) extendMessage,
    required TResult Function(CompleteResponse value) completeResponse,
  }) {
    return updateTemperature(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(CheckForModel value)? checkForModel,
    TResult? Function(DownloadModel value)? downloadModel,
    TResult? Function(SetPercentDownloaded value)? setPercentDownloaded,
    TResult? Function(DeleteModel value)? deleteModel,
    TResult? Function(InitEngine value)? initEngine,
    TResult? Function(InitializeModelInfo value)? initializeModelInfo,
    TResult? Function(UpdateTemperature value)? updateTemperature,
    TResult? Function(UpdateTopK value)? updateTopK,
    TResult? Function(UpdateMaxTokens value)? updateMaxTokens,
    TResult? Function(SetTranscript value)? setTranscript,
    TResult? Function(AddMessage value)? addMessage,
    TResult? Function(ExtendMessage value)? extendMessage,
    TResult? Function(CompleteResponse value)? completeResponse,
  }) {
    return updateTemperature?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(CheckForModel value)? checkForModel,
    TResult Function(DownloadModel value)? downloadModel,
    TResult Function(SetPercentDownloaded value)? setPercentDownloaded,
    TResult Function(DeleteModel value)? deleteModel,
    TResult Function(InitEngine value)? initEngine,
    TResult Function(InitializeModelInfo value)? initializeModelInfo,
    TResult Function(UpdateTemperature value)? updateTemperature,
    TResult Function(UpdateTopK value)? updateTopK,
    TResult Function(UpdateMaxTokens value)? updateMaxTokens,
    TResult Function(SetTranscript value)? setTranscript,
    TResult Function(AddMessage value)? addMessage,
    TResult Function(ExtendMessage value)? extendMessage,
    TResult Function(CompleteResponse value)? completeResponse,
    required TResult orElse(),
  }) {
    if (updateTemperature != null) {
      return updateTemperature(this);
    }
    return orElse();
  }
}

abstract class UpdateTemperature implements TranscriptEvent {
  const factory UpdateTemperature(final double value) = _$UpdateTemperatureImpl;

  double get value;
  @JsonKey(ignore: true)
  _$$UpdateTemperatureImplCopyWith<_$UpdateTemperatureImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$UpdateTopKImplCopyWith<$Res> {
  factory _$$UpdateTopKImplCopyWith(
          _$UpdateTopKImpl value, $Res Function(_$UpdateTopKImpl) then) =
      __$$UpdateTopKImplCopyWithImpl<$Res>;
  @useResult
  $Res call({int value});
}

/// @nodoc
class __$$UpdateTopKImplCopyWithImpl<$Res>
    extends _$TranscriptEventCopyWithImpl<$Res, _$UpdateTopKImpl>
    implements _$$UpdateTopKImplCopyWith<$Res> {
  __$$UpdateTopKImplCopyWithImpl(
      _$UpdateTopKImpl _value, $Res Function(_$UpdateTopKImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? value = null,
  }) {
    return _then(_$UpdateTopKImpl(
      null == value
          ? _value.value
          : value // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class _$UpdateTopKImpl implements UpdateTopK {
  const _$UpdateTopKImpl(this.value);

  @override
  final int value;

  @override
  String toString() {
    return 'TranscriptEvent.updateTopK(value: $value)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UpdateTopKImpl &&
            (identical(other.value, value) || other.value == value));
  }

  @override
  int get hashCode => Object.hash(runtimeType, value);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$UpdateTopKImplCopyWith<_$UpdateTopKImpl> get copyWith =>
      __$$UpdateTopKImplCopyWithImpl<_$UpdateTopKImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(LlmModel model) checkForModel,
    required TResult Function(LlmModel model) downloadModel,
    required TResult Function(LlmModel model, int percentDownloaded)
        setPercentDownloaded,
    required TResult Function(LlmModel model) deleteModel,
    required TResult Function(LlmModel model) initEngine,
    required TResult Function() initializeModelInfo,
    required TResult Function(double value) updateTemperature,
    required TResult Function(int value) updateTopK,
    required TResult Function(int value) updateMaxTokens,
    required TResult Function(LlmModel model) setTranscript,
    required TResult Function(ChatMessage message, LlmModel model) addMessage,
    required TResult Function(
            String chunk, int index, LlmModel model, bool first, bool last)
        extendMessage,
    required TResult Function(LlmModel model) completeResponse,
  }) {
    return updateTopK(value);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(LlmModel model)? checkForModel,
    TResult? Function(LlmModel model)? downloadModel,
    TResult? Function(LlmModel model, int percentDownloaded)?
        setPercentDownloaded,
    TResult? Function(LlmModel model)? deleteModel,
    TResult? Function(LlmModel model)? initEngine,
    TResult? Function()? initializeModelInfo,
    TResult? Function(double value)? updateTemperature,
    TResult? Function(int value)? updateTopK,
    TResult? Function(int value)? updateMaxTokens,
    TResult? Function(LlmModel model)? setTranscript,
    TResult? Function(ChatMessage message, LlmModel model)? addMessage,
    TResult? Function(
            String chunk, int index, LlmModel model, bool first, bool last)?
        extendMessage,
    TResult? Function(LlmModel model)? completeResponse,
  }) {
    return updateTopK?.call(value);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(LlmModel model)? checkForModel,
    TResult Function(LlmModel model)? downloadModel,
    TResult Function(LlmModel model, int percentDownloaded)?
        setPercentDownloaded,
    TResult Function(LlmModel model)? deleteModel,
    TResult Function(LlmModel model)? initEngine,
    TResult Function()? initializeModelInfo,
    TResult Function(double value)? updateTemperature,
    TResult Function(int value)? updateTopK,
    TResult Function(int value)? updateMaxTokens,
    TResult Function(LlmModel model)? setTranscript,
    TResult Function(ChatMessage message, LlmModel model)? addMessage,
    TResult Function(
            String chunk, int index, LlmModel model, bool first, bool last)?
        extendMessage,
    TResult Function(LlmModel model)? completeResponse,
    required TResult orElse(),
  }) {
    if (updateTopK != null) {
      return updateTopK(value);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(CheckForModel value) checkForModel,
    required TResult Function(DownloadModel value) downloadModel,
    required TResult Function(SetPercentDownloaded value) setPercentDownloaded,
    required TResult Function(DeleteModel value) deleteModel,
    required TResult Function(InitEngine value) initEngine,
    required TResult Function(InitializeModelInfo value) initializeModelInfo,
    required TResult Function(UpdateTemperature value) updateTemperature,
    required TResult Function(UpdateTopK value) updateTopK,
    required TResult Function(UpdateMaxTokens value) updateMaxTokens,
    required TResult Function(SetTranscript value) setTranscript,
    required TResult Function(AddMessage value) addMessage,
    required TResult Function(ExtendMessage value) extendMessage,
    required TResult Function(CompleteResponse value) completeResponse,
  }) {
    return updateTopK(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(CheckForModel value)? checkForModel,
    TResult? Function(DownloadModel value)? downloadModel,
    TResult? Function(SetPercentDownloaded value)? setPercentDownloaded,
    TResult? Function(DeleteModel value)? deleteModel,
    TResult? Function(InitEngine value)? initEngine,
    TResult? Function(InitializeModelInfo value)? initializeModelInfo,
    TResult? Function(UpdateTemperature value)? updateTemperature,
    TResult? Function(UpdateTopK value)? updateTopK,
    TResult? Function(UpdateMaxTokens value)? updateMaxTokens,
    TResult? Function(SetTranscript value)? setTranscript,
    TResult? Function(AddMessage value)? addMessage,
    TResult? Function(ExtendMessage value)? extendMessage,
    TResult? Function(CompleteResponse value)? completeResponse,
  }) {
    return updateTopK?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(CheckForModel value)? checkForModel,
    TResult Function(DownloadModel value)? downloadModel,
    TResult Function(SetPercentDownloaded value)? setPercentDownloaded,
    TResult Function(DeleteModel value)? deleteModel,
    TResult Function(InitEngine value)? initEngine,
    TResult Function(InitializeModelInfo value)? initializeModelInfo,
    TResult Function(UpdateTemperature value)? updateTemperature,
    TResult Function(UpdateTopK value)? updateTopK,
    TResult Function(UpdateMaxTokens value)? updateMaxTokens,
    TResult Function(SetTranscript value)? setTranscript,
    TResult Function(AddMessage value)? addMessage,
    TResult Function(ExtendMessage value)? extendMessage,
    TResult Function(CompleteResponse value)? completeResponse,
    required TResult orElse(),
  }) {
    if (updateTopK != null) {
      return updateTopK(this);
    }
    return orElse();
  }
}

abstract class UpdateTopK implements TranscriptEvent {
  const factory UpdateTopK(final int value) = _$UpdateTopKImpl;

  int get value;
  @JsonKey(ignore: true)
  _$$UpdateTopKImplCopyWith<_$UpdateTopKImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$UpdateMaxTokensImplCopyWith<$Res> {
  factory _$$UpdateMaxTokensImplCopyWith(_$UpdateMaxTokensImpl value,
          $Res Function(_$UpdateMaxTokensImpl) then) =
      __$$UpdateMaxTokensImplCopyWithImpl<$Res>;
  @useResult
  $Res call({int value});
}

/// @nodoc
class __$$UpdateMaxTokensImplCopyWithImpl<$Res>
    extends _$TranscriptEventCopyWithImpl<$Res, _$UpdateMaxTokensImpl>
    implements _$$UpdateMaxTokensImplCopyWith<$Res> {
  __$$UpdateMaxTokensImplCopyWithImpl(
      _$UpdateMaxTokensImpl _value, $Res Function(_$UpdateMaxTokensImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? value = null,
  }) {
    return _then(_$UpdateMaxTokensImpl(
      null == value
          ? _value.value
          : value // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class _$UpdateMaxTokensImpl implements UpdateMaxTokens {
  const _$UpdateMaxTokensImpl(this.value);

  @override
  final int value;

  @override
  String toString() {
    return 'TranscriptEvent.updateMaxTokens(value: $value)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UpdateMaxTokensImpl &&
            (identical(other.value, value) || other.value == value));
  }

  @override
  int get hashCode => Object.hash(runtimeType, value);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$UpdateMaxTokensImplCopyWith<_$UpdateMaxTokensImpl> get copyWith =>
      __$$UpdateMaxTokensImplCopyWithImpl<_$UpdateMaxTokensImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(LlmModel model) checkForModel,
    required TResult Function(LlmModel model) downloadModel,
    required TResult Function(LlmModel model, int percentDownloaded)
        setPercentDownloaded,
    required TResult Function(LlmModel model) deleteModel,
    required TResult Function(LlmModel model) initEngine,
    required TResult Function() initializeModelInfo,
    required TResult Function(double value) updateTemperature,
    required TResult Function(int value) updateTopK,
    required TResult Function(int value) updateMaxTokens,
    required TResult Function(LlmModel model) setTranscript,
    required TResult Function(ChatMessage message, LlmModel model) addMessage,
    required TResult Function(
            String chunk, int index, LlmModel model, bool first, bool last)
        extendMessage,
    required TResult Function(LlmModel model) completeResponse,
  }) {
    return updateMaxTokens(value);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(LlmModel model)? checkForModel,
    TResult? Function(LlmModel model)? downloadModel,
    TResult? Function(LlmModel model, int percentDownloaded)?
        setPercentDownloaded,
    TResult? Function(LlmModel model)? deleteModel,
    TResult? Function(LlmModel model)? initEngine,
    TResult? Function()? initializeModelInfo,
    TResult? Function(double value)? updateTemperature,
    TResult? Function(int value)? updateTopK,
    TResult? Function(int value)? updateMaxTokens,
    TResult? Function(LlmModel model)? setTranscript,
    TResult? Function(ChatMessage message, LlmModel model)? addMessage,
    TResult? Function(
            String chunk, int index, LlmModel model, bool first, bool last)?
        extendMessage,
    TResult? Function(LlmModel model)? completeResponse,
  }) {
    return updateMaxTokens?.call(value);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(LlmModel model)? checkForModel,
    TResult Function(LlmModel model)? downloadModel,
    TResult Function(LlmModel model, int percentDownloaded)?
        setPercentDownloaded,
    TResult Function(LlmModel model)? deleteModel,
    TResult Function(LlmModel model)? initEngine,
    TResult Function()? initializeModelInfo,
    TResult Function(double value)? updateTemperature,
    TResult Function(int value)? updateTopK,
    TResult Function(int value)? updateMaxTokens,
    TResult Function(LlmModel model)? setTranscript,
    TResult Function(ChatMessage message, LlmModel model)? addMessage,
    TResult Function(
            String chunk, int index, LlmModel model, bool first, bool last)?
        extendMessage,
    TResult Function(LlmModel model)? completeResponse,
    required TResult orElse(),
  }) {
    if (updateMaxTokens != null) {
      return updateMaxTokens(value);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(CheckForModel value) checkForModel,
    required TResult Function(DownloadModel value) downloadModel,
    required TResult Function(SetPercentDownloaded value) setPercentDownloaded,
    required TResult Function(DeleteModel value) deleteModel,
    required TResult Function(InitEngine value) initEngine,
    required TResult Function(InitializeModelInfo value) initializeModelInfo,
    required TResult Function(UpdateTemperature value) updateTemperature,
    required TResult Function(UpdateTopK value) updateTopK,
    required TResult Function(UpdateMaxTokens value) updateMaxTokens,
    required TResult Function(SetTranscript value) setTranscript,
    required TResult Function(AddMessage value) addMessage,
    required TResult Function(ExtendMessage value) extendMessage,
    required TResult Function(CompleteResponse value) completeResponse,
  }) {
    return updateMaxTokens(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(CheckForModel value)? checkForModel,
    TResult? Function(DownloadModel value)? downloadModel,
    TResult? Function(SetPercentDownloaded value)? setPercentDownloaded,
    TResult? Function(DeleteModel value)? deleteModel,
    TResult? Function(InitEngine value)? initEngine,
    TResult? Function(InitializeModelInfo value)? initializeModelInfo,
    TResult? Function(UpdateTemperature value)? updateTemperature,
    TResult? Function(UpdateTopK value)? updateTopK,
    TResult? Function(UpdateMaxTokens value)? updateMaxTokens,
    TResult? Function(SetTranscript value)? setTranscript,
    TResult? Function(AddMessage value)? addMessage,
    TResult? Function(ExtendMessage value)? extendMessage,
    TResult? Function(CompleteResponse value)? completeResponse,
  }) {
    return updateMaxTokens?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(CheckForModel value)? checkForModel,
    TResult Function(DownloadModel value)? downloadModel,
    TResult Function(SetPercentDownloaded value)? setPercentDownloaded,
    TResult Function(DeleteModel value)? deleteModel,
    TResult Function(InitEngine value)? initEngine,
    TResult Function(InitializeModelInfo value)? initializeModelInfo,
    TResult Function(UpdateTemperature value)? updateTemperature,
    TResult Function(UpdateTopK value)? updateTopK,
    TResult Function(UpdateMaxTokens value)? updateMaxTokens,
    TResult Function(SetTranscript value)? setTranscript,
    TResult Function(AddMessage value)? addMessage,
    TResult Function(ExtendMessage value)? extendMessage,
    TResult Function(CompleteResponse value)? completeResponse,
    required TResult orElse(),
  }) {
    if (updateMaxTokens != null) {
      return updateMaxTokens(this);
    }
    return orElse();
  }
}

abstract class UpdateMaxTokens implements TranscriptEvent {
  const factory UpdateMaxTokens(final int value) = _$UpdateMaxTokensImpl;

  int get value;
  @JsonKey(ignore: true)
  _$$UpdateMaxTokensImplCopyWith<_$UpdateMaxTokensImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$SetTranscriptImplCopyWith<$Res> {
  factory _$$SetTranscriptImplCopyWith(
          _$SetTranscriptImpl value, $Res Function(_$SetTranscriptImpl) then) =
      __$$SetTranscriptImplCopyWithImpl<$Res>;
  @useResult
  $Res call({LlmModel model});
}

/// @nodoc
class __$$SetTranscriptImplCopyWithImpl<$Res>
    extends _$TranscriptEventCopyWithImpl<$Res, _$SetTranscriptImpl>
    implements _$$SetTranscriptImplCopyWith<$Res> {
  __$$SetTranscriptImplCopyWithImpl(
      _$SetTranscriptImpl _value, $Res Function(_$SetTranscriptImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? model = null,
  }) {
    return _then(_$SetTranscriptImpl(
      null == model
          ? _value.model
          : model // ignore: cast_nullable_to_non_nullable
              as LlmModel,
    ));
  }
}

/// @nodoc

class _$SetTranscriptImpl implements SetTranscript {
  const _$SetTranscriptImpl(this.model);

  @override
  final LlmModel model;

  @override
  String toString() {
    return 'TranscriptEvent.setTranscript(model: $model)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SetTranscriptImpl &&
            (identical(other.model, model) || other.model == model));
  }

  @override
  int get hashCode => Object.hash(runtimeType, model);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$SetTranscriptImplCopyWith<_$SetTranscriptImpl> get copyWith =>
      __$$SetTranscriptImplCopyWithImpl<_$SetTranscriptImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(LlmModel model) checkForModel,
    required TResult Function(LlmModel model) downloadModel,
    required TResult Function(LlmModel model, int percentDownloaded)
        setPercentDownloaded,
    required TResult Function(LlmModel model) deleteModel,
    required TResult Function(LlmModel model) initEngine,
    required TResult Function() initializeModelInfo,
    required TResult Function(double value) updateTemperature,
    required TResult Function(int value) updateTopK,
    required TResult Function(int value) updateMaxTokens,
    required TResult Function(LlmModel model) setTranscript,
    required TResult Function(ChatMessage message, LlmModel model) addMessage,
    required TResult Function(
            String chunk, int index, LlmModel model, bool first, bool last)
        extendMessage,
    required TResult Function(LlmModel model) completeResponse,
  }) {
    return setTranscript(model);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(LlmModel model)? checkForModel,
    TResult? Function(LlmModel model)? downloadModel,
    TResult? Function(LlmModel model, int percentDownloaded)?
        setPercentDownloaded,
    TResult? Function(LlmModel model)? deleteModel,
    TResult? Function(LlmModel model)? initEngine,
    TResult? Function()? initializeModelInfo,
    TResult? Function(double value)? updateTemperature,
    TResult? Function(int value)? updateTopK,
    TResult? Function(int value)? updateMaxTokens,
    TResult? Function(LlmModel model)? setTranscript,
    TResult? Function(ChatMessage message, LlmModel model)? addMessage,
    TResult? Function(
            String chunk, int index, LlmModel model, bool first, bool last)?
        extendMessage,
    TResult? Function(LlmModel model)? completeResponse,
  }) {
    return setTranscript?.call(model);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(LlmModel model)? checkForModel,
    TResult Function(LlmModel model)? downloadModel,
    TResult Function(LlmModel model, int percentDownloaded)?
        setPercentDownloaded,
    TResult Function(LlmModel model)? deleteModel,
    TResult Function(LlmModel model)? initEngine,
    TResult Function()? initializeModelInfo,
    TResult Function(double value)? updateTemperature,
    TResult Function(int value)? updateTopK,
    TResult Function(int value)? updateMaxTokens,
    TResult Function(LlmModel model)? setTranscript,
    TResult Function(ChatMessage message, LlmModel model)? addMessage,
    TResult Function(
            String chunk, int index, LlmModel model, bool first, bool last)?
        extendMessage,
    TResult Function(LlmModel model)? completeResponse,
    required TResult orElse(),
  }) {
    if (setTranscript != null) {
      return setTranscript(model);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(CheckForModel value) checkForModel,
    required TResult Function(DownloadModel value) downloadModel,
    required TResult Function(SetPercentDownloaded value) setPercentDownloaded,
    required TResult Function(DeleteModel value) deleteModel,
    required TResult Function(InitEngine value) initEngine,
    required TResult Function(InitializeModelInfo value) initializeModelInfo,
    required TResult Function(UpdateTemperature value) updateTemperature,
    required TResult Function(UpdateTopK value) updateTopK,
    required TResult Function(UpdateMaxTokens value) updateMaxTokens,
    required TResult Function(SetTranscript value) setTranscript,
    required TResult Function(AddMessage value) addMessage,
    required TResult Function(ExtendMessage value) extendMessage,
    required TResult Function(CompleteResponse value) completeResponse,
  }) {
    return setTranscript(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(CheckForModel value)? checkForModel,
    TResult? Function(DownloadModel value)? downloadModel,
    TResult? Function(SetPercentDownloaded value)? setPercentDownloaded,
    TResult? Function(DeleteModel value)? deleteModel,
    TResult? Function(InitEngine value)? initEngine,
    TResult? Function(InitializeModelInfo value)? initializeModelInfo,
    TResult? Function(UpdateTemperature value)? updateTemperature,
    TResult? Function(UpdateTopK value)? updateTopK,
    TResult? Function(UpdateMaxTokens value)? updateMaxTokens,
    TResult? Function(SetTranscript value)? setTranscript,
    TResult? Function(AddMessage value)? addMessage,
    TResult? Function(ExtendMessage value)? extendMessage,
    TResult? Function(CompleteResponse value)? completeResponse,
  }) {
    return setTranscript?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(CheckForModel value)? checkForModel,
    TResult Function(DownloadModel value)? downloadModel,
    TResult Function(SetPercentDownloaded value)? setPercentDownloaded,
    TResult Function(DeleteModel value)? deleteModel,
    TResult Function(InitEngine value)? initEngine,
    TResult Function(InitializeModelInfo value)? initializeModelInfo,
    TResult Function(UpdateTemperature value)? updateTemperature,
    TResult Function(UpdateTopK value)? updateTopK,
    TResult Function(UpdateMaxTokens value)? updateMaxTokens,
    TResult Function(SetTranscript value)? setTranscript,
    TResult Function(AddMessage value)? addMessage,
    TResult Function(ExtendMessage value)? extendMessage,
    TResult Function(CompleteResponse value)? completeResponse,
    required TResult orElse(),
  }) {
    if (setTranscript != null) {
      return setTranscript(this);
    }
    return orElse();
  }
}

abstract class SetTranscript implements TranscriptEvent {
  const factory SetTranscript(final LlmModel model) = _$SetTranscriptImpl;

  LlmModel get model;
  @JsonKey(ignore: true)
  _$$SetTranscriptImplCopyWith<_$SetTranscriptImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$AddMessageImplCopyWith<$Res> {
  factory _$$AddMessageImplCopyWith(
          _$AddMessageImpl value, $Res Function(_$AddMessageImpl) then) =
      __$$AddMessageImplCopyWithImpl<$Res>;
  @useResult
  $Res call({ChatMessage message, LlmModel model});

  $ChatMessageCopyWith<$Res> get message;
}

/// @nodoc
class __$$AddMessageImplCopyWithImpl<$Res>
    extends _$TranscriptEventCopyWithImpl<$Res, _$AddMessageImpl>
    implements _$$AddMessageImplCopyWith<$Res> {
  __$$AddMessageImplCopyWithImpl(
      _$AddMessageImpl _value, $Res Function(_$AddMessageImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? message = null,
    Object? model = null,
  }) {
    return _then(_$AddMessageImpl(
      null == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as ChatMessage,
      null == model
          ? _value.model
          : model // ignore: cast_nullable_to_non_nullable
              as LlmModel,
    ));
  }

  @override
  @pragma('vm:prefer-inline')
  $ChatMessageCopyWith<$Res> get message {
    return $ChatMessageCopyWith<$Res>(_value.message, (value) {
      return _then(_value.copyWith(message: value));
    });
  }
}

/// @nodoc

class _$AddMessageImpl implements AddMessage {
  const _$AddMessageImpl(this.message, this.model);

  @override
  final ChatMessage message;
  @override
  final LlmModel model;

  @override
  String toString() {
    return 'TranscriptEvent.addMessage(message: $message, model: $model)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AddMessageImpl &&
            (identical(other.message, message) || other.message == message) &&
            (identical(other.model, model) || other.model == model));
  }

  @override
  int get hashCode => Object.hash(runtimeType, message, model);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$AddMessageImplCopyWith<_$AddMessageImpl> get copyWith =>
      __$$AddMessageImplCopyWithImpl<_$AddMessageImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(LlmModel model) checkForModel,
    required TResult Function(LlmModel model) downloadModel,
    required TResult Function(LlmModel model, int percentDownloaded)
        setPercentDownloaded,
    required TResult Function(LlmModel model) deleteModel,
    required TResult Function(LlmModel model) initEngine,
    required TResult Function() initializeModelInfo,
    required TResult Function(double value) updateTemperature,
    required TResult Function(int value) updateTopK,
    required TResult Function(int value) updateMaxTokens,
    required TResult Function(LlmModel model) setTranscript,
    required TResult Function(ChatMessage message, LlmModel model) addMessage,
    required TResult Function(
            String chunk, int index, LlmModel model, bool first, bool last)
        extendMessage,
    required TResult Function(LlmModel model) completeResponse,
  }) {
    return addMessage(message, model);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(LlmModel model)? checkForModel,
    TResult? Function(LlmModel model)? downloadModel,
    TResult? Function(LlmModel model, int percentDownloaded)?
        setPercentDownloaded,
    TResult? Function(LlmModel model)? deleteModel,
    TResult? Function(LlmModel model)? initEngine,
    TResult? Function()? initializeModelInfo,
    TResult? Function(double value)? updateTemperature,
    TResult? Function(int value)? updateTopK,
    TResult? Function(int value)? updateMaxTokens,
    TResult? Function(LlmModel model)? setTranscript,
    TResult? Function(ChatMessage message, LlmModel model)? addMessage,
    TResult? Function(
            String chunk, int index, LlmModel model, bool first, bool last)?
        extendMessage,
    TResult? Function(LlmModel model)? completeResponse,
  }) {
    return addMessage?.call(message, model);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(LlmModel model)? checkForModel,
    TResult Function(LlmModel model)? downloadModel,
    TResult Function(LlmModel model, int percentDownloaded)?
        setPercentDownloaded,
    TResult Function(LlmModel model)? deleteModel,
    TResult Function(LlmModel model)? initEngine,
    TResult Function()? initializeModelInfo,
    TResult Function(double value)? updateTemperature,
    TResult Function(int value)? updateTopK,
    TResult Function(int value)? updateMaxTokens,
    TResult Function(LlmModel model)? setTranscript,
    TResult Function(ChatMessage message, LlmModel model)? addMessage,
    TResult Function(
            String chunk, int index, LlmModel model, bool first, bool last)?
        extendMessage,
    TResult Function(LlmModel model)? completeResponse,
    required TResult orElse(),
  }) {
    if (addMessage != null) {
      return addMessage(message, model);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(CheckForModel value) checkForModel,
    required TResult Function(DownloadModel value) downloadModel,
    required TResult Function(SetPercentDownloaded value) setPercentDownloaded,
    required TResult Function(DeleteModel value) deleteModel,
    required TResult Function(InitEngine value) initEngine,
    required TResult Function(InitializeModelInfo value) initializeModelInfo,
    required TResult Function(UpdateTemperature value) updateTemperature,
    required TResult Function(UpdateTopK value) updateTopK,
    required TResult Function(UpdateMaxTokens value) updateMaxTokens,
    required TResult Function(SetTranscript value) setTranscript,
    required TResult Function(AddMessage value) addMessage,
    required TResult Function(ExtendMessage value) extendMessage,
    required TResult Function(CompleteResponse value) completeResponse,
  }) {
    return addMessage(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(CheckForModel value)? checkForModel,
    TResult? Function(DownloadModel value)? downloadModel,
    TResult? Function(SetPercentDownloaded value)? setPercentDownloaded,
    TResult? Function(DeleteModel value)? deleteModel,
    TResult? Function(InitEngine value)? initEngine,
    TResult? Function(InitializeModelInfo value)? initializeModelInfo,
    TResult? Function(UpdateTemperature value)? updateTemperature,
    TResult? Function(UpdateTopK value)? updateTopK,
    TResult? Function(UpdateMaxTokens value)? updateMaxTokens,
    TResult? Function(SetTranscript value)? setTranscript,
    TResult? Function(AddMessage value)? addMessage,
    TResult? Function(ExtendMessage value)? extendMessage,
    TResult? Function(CompleteResponse value)? completeResponse,
  }) {
    return addMessage?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(CheckForModel value)? checkForModel,
    TResult Function(DownloadModel value)? downloadModel,
    TResult Function(SetPercentDownloaded value)? setPercentDownloaded,
    TResult Function(DeleteModel value)? deleteModel,
    TResult Function(InitEngine value)? initEngine,
    TResult Function(InitializeModelInfo value)? initializeModelInfo,
    TResult Function(UpdateTemperature value)? updateTemperature,
    TResult Function(UpdateTopK value)? updateTopK,
    TResult Function(UpdateMaxTokens value)? updateMaxTokens,
    TResult Function(SetTranscript value)? setTranscript,
    TResult Function(AddMessage value)? addMessage,
    TResult Function(ExtendMessage value)? extendMessage,
    TResult Function(CompleteResponse value)? completeResponse,
    required TResult orElse(),
  }) {
    if (addMessage != null) {
      return addMessage(this);
    }
    return orElse();
  }
}

abstract class AddMessage implements TranscriptEvent {
  const factory AddMessage(final ChatMessage message, final LlmModel model) =
      _$AddMessageImpl;

  ChatMessage get message;
  LlmModel get model;
  @JsonKey(ignore: true)
  _$$AddMessageImplCopyWith<_$AddMessageImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ExtendMessageImplCopyWith<$Res> {
  factory _$$ExtendMessageImplCopyWith(
          _$ExtendMessageImpl value, $Res Function(_$ExtendMessageImpl) then) =
      __$$ExtendMessageImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String chunk, int index, LlmModel model, bool first, bool last});
}

/// @nodoc
class __$$ExtendMessageImplCopyWithImpl<$Res>
    extends _$TranscriptEventCopyWithImpl<$Res, _$ExtendMessageImpl>
    implements _$$ExtendMessageImplCopyWith<$Res> {
  __$$ExtendMessageImplCopyWithImpl(
      _$ExtendMessageImpl _value, $Res Function(_$ExtendMessageImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? chunk = null,
    Object? index = null,
    Object? model = null,
    Object? first = null,
    Object? last = null,
  }) {
    return _then(_$ExtendMessageImpl(
      chunk: null == chunk
          ? _value.chunk
          : chunk // ignore: cast_nullable_to_non_nullable
              as String,
      index: null == index
          ? _value.index
          : index // ignore: cast_nullable_to_non_nullable
              as int,
      model: null == model
          ? _value.model
          : model // ignore: cast_nullable_to_non_nullable
              as LlmModel,
      first: null == first
          ? _value.first
          : first // ignore: cast_nullable_to_non_nullable
              as bool,
      last: null == last
          ? _value.last
          : last // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class _$ExtendMessageImpl implements ExtendMessage {
  const _$ExtendMessageImpl(
      {required this.chunk,
      required this.index,
      required this.model,
      required this.first,
      required this.last});

  @override
  final String chunk;
  @override
  final int index;
  @override
  final LlmModel model;
  @override
  final bool first;
  @override
  final bool last;

  @override
  String toString() {
    return 'TranscriptEvent.extendMessage(chunk: $chunk, index: $index, model: $model, first: $first, last: $last)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ExtendMessageImpl &&
            (identical(other.chunk, chunk) || other.chunk == chunk) &&
            (identical(other.index, index) || other.index == index) &&
            (identical(other.model, model) || other.model == model) &&
            (identical(other.first, first) || other.first == first) &&
            (identical(other.last, last) || other.last == last));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, chunk, index, model, first, last);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ExtendMessageImplCopyWith<_$ExtendMessageImpl> get copyWith =>
      __$$ExtendMessageImplCopyWithImpl<_$ExtendMessageImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(LlmModel model) checkForModel,
    required TResult Function(LlmModel model) downloadModel,
    required TResult Function(LlmModel model, int percentDownloaded)
        setPercentDownloaded,
    required TResult Function(LlmModel model) deleteModel,
    required TResult Function(LlmModel model) initEngine,
    required TResult Function() initializeModelInfo,
    required TResult Function(double value) updateTemperature,
    required TResult Function(int value) updateTopK,
    required TResult Function(int value) updateMaxTokens,
    required TResult Function(LlmModel model) setTranscript,
    required TResult Function(ChatMessage message, LlmModel model) addMessage,
    required TResult Function(
            String chunk, int index, LlmModel model, bool first, bool last)
        extendMessage,
    required TResult Function(LlmModel model) completeResponse,
  }) {
    return extendMessage(chunk, index, model, first, last);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(LlmModel model)? checkForModel,
    TResult? Function(LlmModel model)? downloadModel,
    TResult? Function(LlmModel model, int percentDownloaded)?
        setPercentDownloaded,
    TResult? Function(LlmModel model)? deleteModel,
    TResult? Function(LlmModel model)? initEngine,
    TResult? Function()? initializeModelInfo,
    TResult? Function(double value)? updateTemperature,
    TResult? Function(int value)? updateTopK,
    TResult? Function(int value)? updateMaxTokens,
    TResult? Function(LlmModel model)? setTranscript,
    TResult? Function(ChatMessage message, LlmModel model)? addMessage,
    TResult? Function(
            String chunk, int index, LlmModel model, bool first, bool last)?
        extendMessage,
    TResult? Function(LlmModel model)? completeResponse,
  }) {
    return extendMessage?.call(chunk, index, model, first, last);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(LlmModel model)? checkForModel,
    TResult Function(LlmModel model)? downloadModel,
    TResult Function(LlmModel model, int percentDownloaded)?
        setPercentDownloaded,
    TResult Function(LlmModel model)? deleteModel,
    TResult Function(LlmModel model)? initEngine,
    TResult Function()? initializeModelInfo,
    TResult Function(double value)? updateTemperature,
    TResult Function(int value)? updateTopK,
    TResult Function(int value)? updateMaxTokens,
    TResult Function(LlmModel model)? setTranscript,
    TResult Function(ChatMessage message, LlmModel model)? addMessage,
    TResult Function(
            String chunk, int index, LlmModel model, bool first, bool last)?
        extendMessage,
    TResult Function(LlmModel model)? completeResponse,
    required TResult orElse(),
  }) {
    if (extendMessage != null) {
      return extendMessage(chunk, index, model, first, last);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(CheckForModel value) checkForModel,
    required TResult Function(DownloadModel value) downloadModel,
    required TResult Function(SetPercentDownloaded value) setPercentDownloaded,
    required TResult Function(DeleteModel value) deleteModel,
    required TResult Function(InitEngine value) initEngine,
    required TResult Function(InitializeModelInfo value) initializeModelInfo,
    required TResult Function(UpdateTemperature value) updateTemperature,
    required TResult Function(UpdateTopK value) updateTopK,
    required TResult Function(UpdateMaxTokens value) updateMaxTokens,
    required TResult Function(SetTranscript value) setTranscript,
    required TResult Function(AddMessage value) addMessage,
    required TResult Function(ExtendMessage value) extendMessage,
    required TResult Function(CompleteResponse value) completeResponse,
  }) {
    return extendMessage(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(CheckForModel value)? checkForModel,
    TResult? Function(DownloadModel value)? downloadModel,
    TResult? Function(SetPercentDownloaded value)? setPercentDownloaded,
    TResult? Function(DeleteModel value)? deleteModel,
    TResult? Function(InitEngine value)? initEngine,
    TResult? Function(InitializeModelInfo value)? initializeModelInfo,
    TResult? Function(UpdateTemperature value)? updateTemperature,
    TResult? Function(UpdateTopK value)? updateTopK,
    TResult? Function(UpdateMaxTokens value)? updateMaxTokens,
    TResult? Function(SetTranscript value)? setTranscript,
    TResult? Function(AddMessage value)? addMessage,
    TResult? Function(ExtendMessage value)? extendMessage,
    TResult? Function(CompleteResponse value)? completeResponse,
  }) {
    return extendMessage?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(CheckForModel value)? checkForModel,
    TResult Function(DownloadModel value)? downloadModel,
    TResult Function(SetPercentDownloaded value)? setPercentDownloaded,
    TResult Function(DeleteModel value)? deleteModel,
    TResult Function(InitEngine value)? initEngine,
    TResult Function(InitializeModelInfo value)? initializeModelInfo,
    TResult Function(UpdateTemperature value)? updateTemperature,
    TResult Function(UpdateTopK value)? updateTopK,
    TResult Function(UpdateMaxTokens value)? updateMaxTokens,
    TResult Function(SetTranscript value)? setTranscript,
    TResult Function(AddMessage value)? addMessage,
    TResult Function(ExtendMessage value)? extendMessage,
    TResult Function(CompleteResponse value)? completeResponse,
    required TResult orElse(),
  }) {
    if (extendMessage != null) {
      return extendMessage(this);
    }
    return orElse();
  }
}

abstract class ExtendMessage implements TranscriptEvent {
  const factory ExtendMessage(
      {required final String chunk,
      required final int index,
      required final LlmModel model,
      required final bool first,
      required final bool last}) = _$ExtendMessageImpl;

  String get chunk;
  int get index;
  LlmModel get model;
  bool get first;
  bool get last;
  @JsonKey(ignore: true)
  _$$ExtendMessageImplCopyWith<_$ExtendMessageImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$CompleteResponseImplCopyWith<$Res> {
  factory _$$CompleteResponseImplCopyWith(_$CompleteResponseImpl value,
          $Res Function(_$CompleteResponseImpl) then) =
      __$$CompleteResponseImplCopyWithImpl<$Res>;
  @useResult
  $Res call({LlmModel model});
}

/// @nodoc
class __$$CompleteResponseImplCopyWithImpl<$Res>
    extends _$TranscriptEventCopyWithImpl<$Res, _$CompleteResponseImpl>
    implements _$$CompleteResponseImplCopyWith<$Res> {
  __$$CompleteResponseImplCopyWithImpl(_$CompleteResponseImpl _value,
      $Res Function(_$CompleteResponseImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? model = null,
  }) {
    return _then(_$CompleteResponseImpl(
      null == model
          ? _value.model
          : model // ignore: cast_nullable_to_non_nullable
              as LlmModel,
    ));
  }
}

/// @nodoc

class _$CompleteResponseImpl implements CompleteResponse {
  const _$CompleteResponseImpl(this.model);

  @override
  final LlmModel model;

  @override
  String toString() {
    return 'TranscriptEvent.completeResponse(model: $model)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CompleteResponseImpl &&
            (identical(other.model, model) || other.model == model));
  }

  @override
  int get hashCode => Object.hash(runtimeType, model);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$CompleteResponseImplCopyWith<_$CompleteResponseImpl> get copyWith =>
      __$$CompleteResponseImplCopyWithImpl<_$CompleteResponseImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(LlmModel model) checkForModel,
    required TResult Function(LlmModel model) downloadModel,
    required TResult Function(LlmModel model, int percentDownloaded)
        setPercentDownloaded,
    required TResult Function(LlmModel model) deleteModel,
    required TResult Function(LlmModel model) initEngine,
    required TResult Function() initializeModelInfo,
    required TResult Function(double value) updateTemperature,
    required TResult Function(int value) updateTopK,
    required TResult Function(int value) updateMaxTokens,
    required TResult Function(LlmModel model) setTranscript,
    required TResult Function(ChatMessage message, LlmModel model) addMessage,
    required TResult Function(
            String chunk, int index, LlmModel model, bool first, bool last)
        extendMessage,
    required TResult Function(LlmModel model) completeResponse,
  }) {
    return completeResponse(model);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(LlmModel model)? checkForModel,
    TResult? Function(LlmModel model)? downloadModel,
    TResult? Function(LlmModel model, int percentDownloaded)?
        setPercentDownloaded,
    TResult? Function(LlmModel model)? deleteModel,
    TResult? Function(LlmModel model)? initEngine,
    TResult? Function()? initializeModelInfo,
    TResult? Function(double value)? updateTemperature,
    TResult? Function(int value)? updateTopK,
    TResult? Function(int value)? updateMaxTokens,
    TResult? Function(LlmModel model)? setTranscript,
    TResult? Function(ChatMessage message, LlmModel model)? addMessage,
    TResult? Function(
            String chunk, int index, LlmModel model, bool first, bool last)?
        extendMessage,
    TResult? Function(LlmModel model)? completeResponse,
  }) {
    return completeResponse?.call(model);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(LlmModel model)? checkForModel,
    TResult Function(LlmModel model)? downloadModel,
    TResult Function(LlmModel model, int percentDownloaded)?
        setPercentDownloaded,
    TResult Function(LlmModel model)? deleteModel,
    TResult Function(LlmModel model)? initEngine,
    TResult Function()? initializeModelInfo,
    TResult Function(double value)? updateTemperature,
    TResult Function(int value)? updateTopK,
    TResult Function(int value)? updateMaxTokens,
    TResult Function(LlmModel model)? setTranscript,
    TResult Function(ChatMessage message, LlmModel model)? addMessage,
    TResult Function(
            String chunk, int index, LlmModel model, bool first, bool last)?
        extendMessage,
    TResult Function(LlmModel model)? completeResponse,
    required TResult orElse(),
  }) {
    if (completeResponse != null) {
      return completeResponse(model);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(CheckForModel value) checkForModel,
    required TResult Function(DownloadModel value) downloadModel,
    required TResult Function(SetPercentDownloaded value) setPercentDownloaded,
    required TResult Function(DeleteModel value) deleteModel,
    required TResult Function(InitEngine value) initEngine,
    required TResult Function(InitializeModelInfo value) initializeModelInfo,
    required TResult Function(UpdateTemperature value) updateTemperature,
    required TResult Function(UpdateTopK value) updateTopK,
    required TResult Function(UpdateMaxTokens value) updateMaxTokens,
    required TResult Function(SetTranscript value) setTranscript,
    required TResult Function(AddMessage value) addMessage,
    required TResult Function(ExtendMessage value) extendMessage,
    required TResult Function(CompleteResponse value) completeResponse,
  }) {
    return completeResponse(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(CheckForModel value)? checkForModel,
    TResult? Function(DownloadModel value)? downloadModel,
    TResult? Function(SetPercentDownloaded value)? setPercentDownloaded,
    TResult? Function(DeleteModel value)? deleteModel,
    TResult? Function(InitEngine value)? initEngine,
    TResult? Function(InitializeModelInfo value)? initializeModelInfo,
    TResult? Function(UpdateTemperature value)? updateTemperature,
    TResult? Function(UpdateTopK value)? updateTopK,
    TResult? Function(UpdateMaxTokens value)? updateMaxTokens,
    TResult? Function(SetTranscript value)? setTranscript,
    TResult? Function(AddMessage value)? addMessage,
    TResult? Function(ExtendMessage value)? extendMessage,
    TResult? Function(CompleteResponse value)? completeResponse,
  }) {
    return completeResponse?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(CheckForModel value)? checkForModel,
    TResult Function(DownloadModel value)? downloadModel,
    TResult Function(SetPercentDownloaded value)? setPercentDownloaded,
    TResult Function(DeleteModel value)? deleteModel,
    TResult Function(InitEngine value)? initEngine,
    TResult Function(InitializeModelInfo value)? initializeModelInfo,
    TResult Function(UpdateTemperature value)? updateTemperature,
    TResult Function(UpdateTopK value)? updateTopK,
    TResult Function(UpdateMaxTokens value)? updateMaxTokens,
    TResult Function(SetTranscript value)? setTranscript,
    TResult Function(AddMessage value)? addMessage,
    TResult Function(ExtendMessage value)? extendMessage,
    TResult Function(CompleteResponse value)? completeResponse,
    required TResult orElse(),
  }) {
    if (completeResponse != null) {
      return completeResponse(this);
    }
    return orElse();
  }
}

abstract class CompleteResponse implements TranscriptEvent {
  const factory CompleteResponse(final LlmModel model) = _$CompleteResponseImpl;

  LlmModel get model;
  @JsonKey(ignore: true)
  _$$CompleteResponseImplCopyWith<_$CompleteResponseImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
