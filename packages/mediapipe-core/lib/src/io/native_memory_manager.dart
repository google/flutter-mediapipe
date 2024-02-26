import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:mediapipe_core/io_mediapipe_core.dart';

/// {@template NativeMemoryManager}
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

  /// Location where the memory is actually allocated. Extending classes should
  /// implement this method.
  final Pointer<T> Function() _allocate;

  /// Deallocates any leased memory.
  void free() {
    if (_memory.isNotNullAndIsNotNullPointer) {
      _deallocate(_memory!);
      _memory = null;
    }
  }

  /// Location where the memory is actually deallocated. Extending classes
  /// should implement this method.
  final void Function(Pointer<T> memory) _deallocate;
}

/// {@template NativeStringManager}
/// Manages the native memory behind a string which starts out empty but may be
/// hydrated within a native function call and terminated by a null character.
///
/// If the pointer is not `nullptr`, then it is assumed to represent an array of
/// strings with a length of 1.
/// {@endtemplate}
class NativeStringManager extends NativeMemoryManager<Pointer<Char>> {
  /// {@macro NativeStringManager}
  NativeStringManager() : super(allocate: _allocator, deallocate: _deallocator);

  static Pointer<Pointer<Char>> _allocator() => calloc<Pointer<Char>>();

  static void _deallocator(Pointer<Pointer<Char>> ptr) {
    if (ptr.isNullPointer) return;
    // TODO: verify correctness
    calloc.free(ptr + 1);
    calloc.free(ptr);
    // TODO: Is this a best practice or anti-pattern?
    ptr = nullptr;
  }
}

/// {@template DartStringMemoryManager}
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

// ///
// class NativeUint8ListManager implements Finalizable {
//   NativeStringManager._(this._pointer);

//   ///
//   factory NativeStringManager({Allocator allocator = malloc}) {
//     final manager = NativeStringManager._(allocator.call<Char>());
//     _finalizer.attach(
//       manager,
//       manager._pointer.cast(),
//     );
//     return manager;
//   }

//   String get string => toDartString(_pointer)!;

//   final Pointer<Char> _pointer;
//   bool _closed = false;

//   static final NativeFinalizer _finalizer = NativeFinalizer(calloc.nativeFree);
// }
