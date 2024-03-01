// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:mediapipe_core/io.dart';

/// {@template NativeMemoryManager}
/// Container for native memory fully managed by Dart code, but hydrated by
/// native code. Exists to pair the correct allocation and deallocation
/// functionality for a given data type.
///
/// See also:
///  * [NativeStringManager] for typical usage.
/// {@endtemplate}
abstract class NativeMemoryManager<T extends NativeType> {
  /// {@macro NativeMemoryManager}
  NativeMemoryManager({
    required Pointer<T> Function() allocate,
    required void Function(Pointer<T>) deallocate,
  })  : _allocate = allocate,
        _deallocate = deallocate;
  Pointer<T>? _memory;

  /// Indicates whether the leased memory has since been released. Returns true
  /// if the memory has been released or was never allocated.
  bool get isFreed => _memory.isNullOrNullPointer;

  /// Indicates whether the leased memory is still live. Returns true
  /// if the memory has not been released.
  bool get isNotFreed => !isFreed;

  /// Allocates and returns a pointer to the desired type of native memory.
  Pointer<T> get memory => _memory ??= _allocate();

  /// Allocates native memory. Extending classes should provide this method via
  /// the constructor's `allocate` parameter.
  final Pointer<T> Function() _allocate;

  /// Deallocates any leased memory.
  void free() {
    if (_memory.isNotNullAndIsNotNullPointer) {
      _deallocate(_memory!);
      _memory = null;
    }
  }

  /// Deallocates any leased memory, but with Flutter style.
  void dispose() => free();

  /// Deallocates native memory. Extending classes should provide this method
  /// via the constructor's `deallocate` parameter.
  final void Function(Pointer<T> memory) _deallocate;
}

/// {@template NativeStringManager}
/// Manages the native memory behind a list of strings which starts out empty
/// but may be hydrated within a native function call and each terminated by a
/// null character.
///
/// If the pointer is not `nullptr`, then it is assumed to represent an array of
/// strings with a length of 1.
///
/// Usage:
/// ```dart
/// final nativeString = NativeStringManager();
/// bindings.get_message(nativeString.memory);
/// final String message = nativeString.memory.toDartString();
/// nativeString.free();
/// ```
/// {@endtemplate}
class NativeStringManager extends NativeMemoryManager<Pointer<Char>> {
  /// {@macro NativeStringManager}
  NativeStringManager() : super(allocate: _allocator, deallocate: _deallocator);

  static Pointer<Pointer<Char>> _allocator() => calloc<Pointer<Char>>();

  static void _deallocator(Pointer<Pointer<Char>> ptr) {
    if (ptr.isNullPointer) return;
    // TODO: verify correctness
    if (ptr[0].isNotNullPointer) {
      calloc.free(ptr[0]);
    }
    calloc.free(ptr);
    // TODO: Is this a best practice or anti-pattern?
    ptr = nullptr;
  }
}

/// {@template DartStringMemoryManager}
/// Manager for a text value originating in Dart code and passed to native code,
/// and which must be released by Dart.
///
/// Usage:
/// ```dart
/// final stringManager = DartStringMemoryManager('value');
/// bindings.process_string(stringManager.memory);
/// stringManager.free();
/// ```
/// {@endtemplate}
class DartStringMemoryManager extends NativeMemoryManager<Char> {
  /// {@macro DartStringMemoryManager}
  DartStringMemoryManager(this.value)
      : super(allocate: () => _allocateString(value), deallocate: _deallocator);

  /// The String value being shared with native memory.
  final String value;

  static Pointer<Char> _allocateString(String value) => value.copyToNative();
  static void _deallocator(Pointer<Char> ptr) => calloc.free(ptr);
}
