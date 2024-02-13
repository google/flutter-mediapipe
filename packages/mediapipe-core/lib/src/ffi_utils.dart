// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

/// Offers convenience and readability extensions for detecting null pointers.
extension NullAwarePtr on Pointer? {
  bool get _isNull => this == null;

  bool get _isNotNull => !_isNull;

  /// Returns true if this is a `nullptr`.
  bool get isNullPointer => _isNotNull && this!.address == nullptr.address;

  /// Returns true if this is not a `nullptr`, but also not [null].
  bool get isNotNullPointer => _isNotNull && this!.address != nullptr.address;

  /// Returns true if this is neither [null] nor a `nullptr`.
  bool get isNotNullAndIsNotNullPointer => _isNotNull && isNotNullPointer;

  /// Returns true if this is either [null] or is a `nullptr`.
  bool get isNullOrNullPointer => _isNull || isNullPointer;
}

/// Helpers to convert between a [String] and a `Pointer<Char>`.
extension NativeStrings on String {
  /// Copies a single Dart string into its C memory equivalent.
  ///
  /// See also:
  ///  * [toCharsPointerPointer]
  Pointer<Char> toNative() => toNativeUtf8().cast<Char>();
}

/// Helpers to convert between a `List<String>` and a `Pointer<Pointer<Char>>`.
extension NativeListOfStrings on List<String> {
  /// Copies a list of Dart strings into native memory.
  ///
  /// See also:
  ///  * [Pointer<Char>.toNative] for a non-list equivalent.
  Pointer<Pointer<Char>> toNative() {
    final ptrArray = calloc<Pointer<Char>>(length);
    for (var i = 0; i < length; i++) {
      ptrArray[i] = this[i].toNative();
    }
    return ptrArray;
  }
}

/// Helpers to convert a [Pointer<Char>] into a [Uint8List].
extension DartAwareChars on Pointer<Char> {
  /// Creates a Dart view on a pointer to utf8 chars in native memory, cast as
  /// unsigned, 8-bit integers. This method does not copy the data out of native
  /// memory.
  ///
  /// If this is called on a `nullptr`, the method returns `null`.
  Uint8List? toUint8List(int length) {
    if (isNullPointer) return null;
    RangeError.checkNotNegative(length, 'length');
    return cast<Uint8>().asTypedList(length);
  }

  /// Converts the C memory representation of a string into a Dart [String].
  ///
  /// If this is called on a `nullptr`, the method returns `null`.
  ///
  /// See also:
  ///  * [toDartStrings]
  String? toDartString({int? length}) {
    if (isNullPointer) return null;
    return cast<Utf8>().toDartString(length: length);
  }
}

/// Helpers to convert between `Pointer<Pointer<Char>>` and `List<String>`.
extension DartAwarePointerChars on Pointer<Pointer<Char>> {
  /// Creates a Dart view on a pointer to a pointer to utf8 chars in native memory,
  /// cast as a `List<String>`. This method does not copy the data out of native
  /// memory.
  ///
  /// If this is called on a `nullptr`, the method returns `null`.
  ///
  /// See also:
  ///  * [toDartString], for a non-list equivalent.
  List<String?>? toDartStrings(int length) {
    if (isNullPointer) return null;
    final dartStrings = <String?>[];
    int counter = 0;
    while (counter < length) {
      dartStrings.add(this[counter].toDartString());
      counter++;
    }
    return dartStrings;
  }
}

/// Helpers to convert a [Pointer<Char>] into a [Uint8List].
extension DartAwareFloats on Pointer<Float> {
  /// Creates a Dart view on a pointer to floats in native memory, cast as a
  /// Float32List. This method does not copy the data out of native memory.
  ///
  /// If this is called on a `nullptr`, the method returns `null`.
  Float32List? toFloat32List(int length) {
    if (isNullPointer) return null;
    RangeError.checkNotNegative(length, 'length');
    return cast<Float>().asTypedList(length);
  }
}

/// Extension method for copying a [Float32List] from Dart memory into native
/// memory.
extension NativeFloats on Float32List {
  /// Copies a [Float32List] into native memory as a `float*`.
  ///
  /// Returns an [allocator]-allocated pointer to the result.
  Pointer<Float> toNative({Allocator allocator = malloc}) {
    final Pointer<Float> result = allocator<Float>(length)
      ..asTypedList(length).setAll(0, this);
    return result.cast();
  }
}

/// Extension method for copying a [Uint8List] from Dart memory into native
/// memory.
extension NativeInts on Uint8List {
  /// Copies a [Uint8List] into native memory as a `char*`.
  ///
  /// Returns an [allocator]-allocated pointer to the result.
  Pointer<Char> toNative({Allocator allocator = malloc}) {
    final Pointer<Uint8> result = allocator<Uint8>(length)
      ..asTypedList(length).setAll(0, this);
    return result.cast();
  }
}
