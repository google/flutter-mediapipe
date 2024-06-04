// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ffi';
import 'package:mediapipe_core/interface.dart';
import 'package:mediapipe_core/io.dart';
import 'third_party/mediapipe/generated/mediapipe_common_bindings.dart'
    as bindings;

/// Anchor class for native memory implementations of task results.
mixin IOTaskResult {}

/// {@macro ClassifierResult}
abstract class ClassifierResult extends BaseClassifierResult with IOTaskResult {
  /// {@macro ClassifierResult.fake}
  ClassifierResult({required Iterable<Classifications> classifications})
      : _classifications = classifications,
        _pointer = null;

  final Pointer<bindings.ClassificationResult>? _pointer;

  /// Internal storage for [classifications], used to cache values pulled out
  /// of native memory, or passed in via the [fake] constructor.
  late final Iterable<Classifications>? _classifications;

  @override
  Iterable<Classifications> get classifications =>
      _classifications ??= _getClassifications();

  /// Fallback for [classifications] if no direct value was supplied and native
  /// memory has not yet been read.
  Iterable<Classifications> _getClassifications() {
    if (_pointer.isNullOrNullPointer) {
      throw Exception(
        'No native memory for ClassifierResult.classifications',
      );
    }
    return Classifications.fromNativeArray(
      _pointer!.ref.classifications,
      _pointer.ref.classifications_count,
    );
  }
}

/// {@macro TimestampedClassifierResult}
abstract class TimestampedClassifierResult extends ClassifierResult
    with TimestampedResult {
  /// {@macro TimestampedClassifierResult}
  TimestampedClassifierResult({
    required Iterable<Classifications> classifications,
    required Duration? timestamp,
  })  : _timestamp = timestamp,
        super(classifications: classifications);

  Duration? _timestamp;
  @override
  Duration? get timestamp => _timestamp ??= _getTimestamp();
  Duration? _getTimestamp() {
    if (_pointer.isNullOrNullPointer) {
      throw Exception(
        'No native memory for ClassifierResult.timestamp',
      );
    }
    return _pointer!.ref.has_timestamp_ms
        ? Duration(milliseconds: _pointer.ref.timestamp_ms)
        : null;
  }

  @override
  String toString() {
    final classificationStrings =
        classifications.map((cat) => cat.toString()).join(', ');
    return '$runtimeType(classifications=[$classificationStrings], '
        'timestamp=$timestamp)';
  }
}
