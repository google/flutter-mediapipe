// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:mediapipe_core/mediapipe_core.dart';

/// {@template DartNativeMemoryManager}
/// Management aid for native memory that is owned by Dart code. Leases out a
/// pointer to native memory and tracks whether or not it has been released.
///
/// For similar assistance with memory owned by C code, see
/// [NativeMemoryManager].
///
/// Usage:
/// ```dart
/// class DartNativeStringMemory extends DartNativeStringMemory<Char> {
///   Pointer<Char> allocate() => calloc<Char>();
///   void deallocate(Pointer<Char> memory) => calloc.free(memory);
/// }
///
/// final memoryManager = DartNativeStringMemory();
/// final Pointer<Char> nativeString = nativeMemoryManager.memory;
///
/// // do something with `nativeString`
///
/// nativeMemoryManager.release();
/// assert(nativeMemoryManager.isFreed);
/// ```
/// {@endtemplate}
abstract class DartNativeMemoryManager<T extends NativeType> {
  /// {@macro DartNativeMemoryManager}
  DartNativeMemoryManager({
    required Pointer<T> Function() allocate,
    required void Function(Pointer<T>) deallocate,
  })  : _allocate = allocate,
        _deallocate = deallocate;
  Pointer<T>? _memory;

  /// Indicates whether the leased memory has since been released. Returns true
  /// if the memory has been released or was never allocated.
  bool get isFreed => _memory == null;

  /// Indicates whether the leased memory is still live. Returns true
  /// if the memory has not been released.
  bool get isNotFreed => _memory != null;

  /// Allocates and returns a pointer to the desired type of native memory.
  Pointer<T> get memory => _memory ??= _allocate();

  /// Location where the memory is actually allocated. Extending classes should
  /// implement this method.
  final Pointer<T> Function() _allocate;

  /// Deallocates any leased memory.
  void release() {
    if (_memory.isNotNullAndIsNotNullPointer) {
      _deallocate(_memory!);
    }
  }

  /// Location where the memory is actually deallocated. Extending classes
  /// should implement this method.
  final void Function(Pointer<T> memory) _deallocate;
}

/// {@template NullTerminatedListOfStringsManager}
/// Manages the native memory behind a list of strings. This class requires that
/// the list of Strings be null-terminated, as well as each individual string
/// be null-terminated.
///
/// {@endtemplate}
class NullTerminatedListOfStringsManager
    extends DartNativeMemoryManager<Pointer<Char>> {
  /// {@macro NullTerminatedListOfStringsManager}
  NullTerminatedListOfStringsManager()
      : super(allocate: _allocator, deallocate: _deallocator);

  static Pointer<Pointer<Char>> _allocator() => calloc<Pointer<Char>>();

  static void _deallocator(Pointer<Pointer<Char>> ptr) {
    if (ptr.isNullPointer) return;
    int i = 0;
    while (true) {
      if (ptr[i].isNullPointer) {
        break;
      }
      calloc.free(ptr[i]);
      i++;
    }
    calloc.free(ptr);
    ptr = nullptr;
  }
}

/// {@template NativeFloat32ListManager}
/// Houses the memory management of a [Pointer<Float>] and its Dart form, a
/// [Float32List].
/// {@endtemplate}
class NativeFloat32ListManager extends DartNativeMemoryManager<Float> {
  /// {@macro NativeFloat32ListManager}
  NativeFloat32ListManager()
      : super(
          allocate: _allocator,
          deallocate: _deallocator,
        );

  static Pointer<Float> _allocator() => calloc<Float>();

  static void _deallocator(Pointer<Float> ptr) => calloc.free(ptr);
}

/// {@template DoubleMemoryManager}
/// {@endtemplate}
class DoubleMemoryManager extends DartNativeMemoryManager<Double> {
  /// {@macro DoubleMemoryManager}
  DoubleMemoryManager()
      : super(
          allocate: () => calloc<Double>(),
          deallocate: (Pointer<Double> ptr, {int? length}) => calloc.free(ptr),
        );
}

/// {@template TaskResultsMemoryManager}
/// Management aid for [TaskResult] objects.
/// {@endtemplate}
class TaskResultsMemoryManager<T extends Struct>
    extends DartNativeMemoryManager<T> {
  /// {@macro TaskResultsMemoryManager}
  TaskResultsMemoryManager({
    required super.allocate,
    required super.deallocate,
  });
}

/// {@template TaskOptionsMemoryManager}
/// Management aid for [TaskOptions] objects.
/// {@endtemplate}
class TaskOptionsMemoryManager<T extends Struct>
    extends DartNativeMemoryManager<T> {
  /// {@macro TaskOptionsMemoryManager}
  TaskOptionsMemoryManager(
      {required TaskOptions<T> options, required super.deallocate})
      : super(
          allocate: () => options.toStruct(),
        );
}
