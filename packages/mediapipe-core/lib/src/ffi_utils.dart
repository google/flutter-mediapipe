// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

/// Converts a list of Dart strings into their C memory equivalent.
///
/// See also:
///  * [prepareString]
Pointer<Pointer<Char>> prepareListOfStrings(List<String> values) {
  final ptrArray = calloc<Pointer<Char>>(values.length);
  for (var i = 0; i < values.length; i++) {
    ptrArray[i] = prepareString(values[i]);
  }
  return ptrArray;
}

/// Converts a single Dart string into its C memory equivalent.
///
/// See also:
///  * [prepareListOfStrings]
Pointer<Char> prepareString(String val) => val.toNativeUtf8().cast<Char>();

/// Converts the C memory representation of a string into a Dart [String]. If the
/// supplied pointer is a null pointer, this function returns `null`.
///
/// See also:
///  * [toDartStrings]
String? toDartString(Pointer<Char> val) {
  if (val.address == 0) return null;
  return val.cast<Utf8>().toDartString();
}

/// Converts a list of C memory representations of strings into a list of Dart
/// [String]s.
///
/// See also:
///  * [toDartString]
List<String?> toDartStrings(Pointer<Pointer<Char>> val, [int? length]) =>
    length != null
        ? _toDartStringsWithCount(val, length)
        : _toStartStringsUntilNull(val);

List<String?> _toStartStringsUntilNull(Pointer<Pointer<Char>> val) {
  final dartStrings = <String?>[];
  int counter = 0;
  while (true) {
    if (val[counter].address == 0) break;
    dartStrings.add(toDartString(val[counter]));
    counter++;
  }
  return dartStrings;
}

List<String?> _toDartStringsWithCount(Pointer<Pointer<Char>> val, int length) {
  final dartStrings = <String?>[];
  int counter = 0;
  while (counter < length) {
    dartStrings.add(toDartString(val[counter]));
    counter++;
  }
  return dartStrings;
}

/// Converts Dart's representation for binary data, a [Uint8List], into its C
/// memory representation.
Pointer<Char> prepareUint8List(Uint8List ints) {
  final Pointer<Uint8> ptr = calloc<Uint8>(ints.length);
  ptr.asTypedList(ints.length).setAll(0, ints);
  return ptr.cast();
}

/// Converts a pointer to binary data in C memory to Dart's representation for
/// binary data, a [Uint8List].
Uint8List toUint8List(Pointer<Char> val, {int? length}) {
  final codeUnits = val.cast<Uint8>();
  if (length != null) {
    RangeError.checkNotNegative(length, 'length');
  } else {
    length = _length(codeUnits);
  }
  return codeUnits.asTypedList(length);
}

// Counts the non-null bytes in a string to determine its length
int _length(Pointer<Uint8> codeUnits) {
  var length = 0;
  while (codeUnits[length] != 0) {
    length++;
  }
  return length;
}
