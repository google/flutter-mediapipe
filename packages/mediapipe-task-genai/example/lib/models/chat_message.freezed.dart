// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_message.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$ChatMessage {
  String get id => throw _privateConstructorUsedError;
  String get body => throw _privateConstructorUsedError;
  MessageOrigin get origin => throw _privateConstructorUsedError;
  int get cursorPosition => throw _privateConstructorUsedError;

  /// Always true for a user's message, but only true for the LLM once it has
  /// finished composing its reply.
  bool get isComplete => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $ChatMessageCopyWith<ChatMessage> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChatMessageCopyWith<$Res> {
  factory $ChatMessageCopyWith(
          ChatMessage value, $Res Function(ChatMessage) then) =
      _$ChatMessageCopyWithImpl<$Res, ChatMessage>;
  @useResult
  $Res call(
      {String id,
      String body,
      MessageOrigin origin,
      int cursorPosition,
      bool isComplete});
}

/// @nodoc
class _$ChatMessageCopyWithImpl<$Res, $Val extends ChatMessage>
    implements $ChatMessageCopyWith<$Res> {
  _$ChatMessageCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? body = null,
    Object? origin = null,
    Object? cursorPosition = null,
    Object? isComplete = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      body: null == body
          ? _value.body
          : body // ignore: cast_nullable_to_non_nullable
              as String,
      origin: null == origin
          ? _value.origin
          : origin // ignore: cast_nullable_to_non_nullable
              as MessageOrigin,
      cursorPosition: null == cursorPosition
          ? _value.cursorPosition
          : cursorPosition // ignore: cast_nullable_to_non_nullable
              as int,
      isComplete: null == isComplete
          ? _value.isComplete
          : isComplete // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ChatMessageImplCopyWith<$Res>
    implements $ChatMessageCopyWith<$Res> {
  factory _$$ChatMessageImplCopyWith(
          _$ChatMessageImpl value, $Res Function(_$ChatMessageImpl) then) =
      __$$ChatMessageImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String body,
      MessageOrigin origin,
      int cursorPosition,
      bool isComplete});
}

/// @nodoc
class __$$ChatMessageImplCopyWithImpl<$Res>
    extends _$ChatMessageCopyWithImpl<$Res, _$ChatMessageImpl>
    implements _$$ChatMessageImplCopyWith<$Res> {
  __$$ChatMessageImplCopyWithImpl(
      _$ChatMessageImpl _value, $Res Function(_$ChatMessageImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? body = null,
    Object? origin = null,
    Object? cursorPosition = null,
    Object? isComplete = null,
  }) {
    return _then(_$ChatMessageImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      body: null == body
          ? _value.body
          : body // ignore: cast_nullable_to_non_nullable
              as String,
      origin: null == origin
          ? _value.origin
          : origin // ignore: cast_nullable_to_non_nullable
              as MessageOrigin,
      cursorPosition: null == cursorPosition
          ? _value.cursorPosition
          : cursorPosition // ignore: cast_nullable_to_non_nullable
              as int,
      isComplete: null == isComplete
          ? _value.isComplete
          : isComplete // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class _$ChatMessageImpl extends _ChatMessage {
  const _$ChatMessageImpl(
      {required this.id,
      required this.body,
      required this.origin,
      required this.cursorPosition,
      required this.isComplete})
      : super._();

  @override
  final String id;
  @override
  final String body;
  @override
  final MessageOrigin origin;
  @override
  final int cursorPosition;

  /// Always true for a user's message, but only true for the LLM once it has
  /// finished composing its reply.
  @override
  final bool isComplete;

  @override
  String toString() {
    return 'ChatMessage(id: $id, body: $body, origin: $origin, cursorPosition: $cursorPosition, isComplete: $isComplete)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChatMessageImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.body, body) || other.body == body) &&
            (identical(other.origin, origin) || other.origin == origin) &&
            (identical(other.cursorPosition, cursorPosition) ||
                other.cursorPosition == cursorPosition) &&
            (identical(other.isComplete, isComplete) ||
                other.isComplete == isComplete));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, id, body, origin, cursorPosition, isComplete);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ChatMessageImplCopyWith<_$ChatMessageImpl> get copyWith =>
      __$$ChatMessageImplCopyWithImpl<_$ChatMessageImpl>(this, _$identity);
}

abstract class _ChatMessage extends ChatMessage {
  const factory _ChatMessage(
      {required final String id,
      required final String body,
      required final MessageOrigin origin,
      required final int cursorPosition,
      required final bool isComplete}) = _$ChatMessageImpl;
  const _ChatMessage._() : super._();

  @override
  String get id;
  @override
  String get body;
  @override
  MessageOrigin get origin;
  @override
  int get cursorPosition;
  @override

  /// Always true for a user's message, but only true for the LLM once it has
  /// finished composing its reply.
  bool get isComplete;
  @override
  @JsonKey(ignore: true)
  _$$ChatMessageImplCopyWith<_$ChatMessageImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
