// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'llm_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$ModelInfo {
  /// Size of the on-disk location of this model. A null value here either
  /// means that the model is currently downloading or completely missing.
  int? get downloadedBytes => throw _privateConstructorUsedError;

  /// 0-100 if a model is being downloaded. A null value here means no
  /// download is in progress for the given model.
  int? get downloadPercent => throw _privateConstructorUsedError;

  /// Location of the model if it is available on disk.
  String? get path => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $ModelInfoCopyWith<ModelInfo> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ModelInfoCopyWith<$Res> {
  factory $ModelInfoCopyWith(ModelInfo value, $Res Function(ModelInfo) then) =
      _$ModelInfoCopyWithImpl<$Res, ModelInfo>;
  @useResult
  $Res call({int? downloadedBytes, int? downloadPercent, String? path});
}

/// @nodoc
class _$ModelInfoCopyWithImpl<$Res, $Val extends ModelInfo>
    implements $ModelInfoCopyWith<$Res> {
  _$ModelInfoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? downloadedBytes = freezed,
    Object? downloadPercent = freezed,
    Object? path = freezed,
  }) {
    return _then(_value.copyWith(
      downloadedBytes: freezed == downloadedBytes
          ? _value.downloadedBytes
          : downloadedBytes // ignore: cast_nullable_to_non_nullable
              as int?,
      downloadPercent: freezed == downloadPercent
          ? _value.downloadPercent
          : downloadPercent // ignore: cast_nullable_to_non_nullable
              as int?,
      path: freezed == path
          ? _value.path
          : path // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ModelInfoImplCopyWith<$Res>
    implements $ModelInfoCopyWith<$Res> {
  factory _$$ModelInfoImplCopyWith(
          _$ModelInfoImpl value, $Res Function(_$ModelInfoImpl) then) =
      __$$ModelInfoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int? downloadedBytes, int? downloadPercent, String? path});
}

/// @nodoc
class __$$ModelInfoImplCopyWithImpl<$Res>
    extends _$ModelInfoCopyWithImpl<$Res, _$ModelInfoImpl>
    implements _$$ModelInfoImplCopyWith<$Res> {
  __$$ModelInfoImplCopyWithImpl(
      _$ModelInfoImpl _value, $Res Function(_$ModelInfoImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? downloadedBytes = freezed,
    Object? downloadPercent = freezed,
    Object? path = freezed,
  }) {
    return _then(_$ModelInfoImpl(
      downloadedBytes: freezed == downloadedBytes
          ? _value.downloadedBytes
          : downloadedBytes // ignore: cast_nullable_to_non_nullable
              as int?,
      downloadPercent: freezed == downloadPercent
          ? _value.downloadPercent
          : downloadPercent // ignore: cast_nullable_to_non_nullable
              as int?,
      path: freezed == path
          ? _value.path
          : path // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$ModelInfoImpl extends _ModelInfo {
  const _$ModelInfoImpl({this.downloadedBytes, this.downloadPercent, this.path})
      : super._();

  /// Size of the on-disk location of this model. A null value here either
  /// means that the model is currently downloading or completely missing.
  @override
  final int? downloadedBytes;

  /// 0-100 if a model is being downloaded. A null value here means no
  /// download is in progress for the given model.
  @override
  final int? downloadPercent;

  /// Location of the model if it is available on disk.
  @override
  final String? path;

  @override
  String toString() {
    return 'ModelInfo(downloadedBytes: $downloadedBytes, downloadPercent: $downloadPercent, path: $path)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ModelInfoImpl &&
            (identical(other.downloadedBytes, downloadedBytes) ||
                other.downloadedBytes == downloadedBytes) &&
            (identical(other.downloadPercent, downloadPercent) ||
                other.downloadPercent == downloadPercent) &&
            (identical(other.path, path) || other.path == path));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, downloadedBytes, downloadPercent, path);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ModelInfoImplCopyWith<_$ModelInfoImpl> get copyWith =>
      __$$ModelInfoImplCopyWithImpl<_$ModelInfoImpl>(this, _$identity);
}

abstract class _ModelInfo extends ModelInfo {
  const factory _ModelInfo(
      {final int? downloadedBytes,
      final int? downloadPercent,
      final String? path}) = _$ModelInfoImpl;
  const _ModelInfo._() : super._();

  @override

  /// Size of the on-disk location of this model. A null value here either
  /// means that the model is currently downloading or completely missing.
  int? get downloadedBytes;
  @override

  /// 0-100 if a model is being downloaded. A null value here means no
  /// download is in progress for the given model.
  int? get downloadPercent;
  @override

  /// Location of the model if it is available on disk.
  String? get path;
  @override
  @JsonKey(ignore: true)
  _$$ModelInfoImplCopyWith<_$ModelInfoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
