import 'dart:ffi';
import 'dart:typed_data';

import 'package:mediapipe_core/mediapipe_core.dart';

/// {@template NativeMemoryManager}
/// Memory management utility for native memory owned by the native side. Dart
/// code is expected to either not care about it's contents or, if it does want
/// to view the raw values, provide a `finalizer` for correct memory cleanup.
///
/// [NativeMemoryManager] is best used for primitives, like [Uint8List] and
/// [Float32List] - not proper structs.
///
/// See also:
///   [DartNativeMemoryManager] for a similar utility for memory owned by Dart.
/// {@endtemplate}
class NativeMemoryManager<NT extends NativeType, TD extends TypedData> {
  /// {@macro NativeMemoryManager}
  NativeMemoryManager._({
    required Pointer<NT>? pointer,
    required TD? dartCopy,
    required this.toDart,
    required this.toNative,
  })  : _pointer = pointer,
        _dartCopy = dartCopy;

  ///
  factory NativeMemoryManager.dart(
    TD data, {
    required Pointer<NT> Function(TD data) toNative,
  }) =>
      NativeMemoryManager._(
        pointer: null,
        dartCopy: data,
        toNative: toNative,
        toDart: null,
      );

  ///
  factory NativeMemoryManager.native(
    Pointer<NT> pointer, {
    required TD Function(Pointer<NT> data) toDart,
  }) =>
      NativeMemoryManager._(
        pointer: pointer,
        dartCopy: null,
        toDart: toDart,
        toNative: null,
      );

  Pointer<NT>? _pointer;
  TD? _dartCopy;

  /// Pointer to the native-owned memory. If the [native] constructor was used,
  /// this returns the exact pointer value passed to that constructor.
  Pointer<NT> get pointer => _pointer ??= toNative!(_dartCopy!);

  /// Way to access Dart's copy of the native memory. If the [dart] constructor
  /// was used, then this value is exactly the same as what was passed to that
  /// constructor.
  TD get dartCopy => _dartCopy ??= toDart!(_pointer!);

  ///
  final TD Function(Pointer<NT> ptr)? toDart;

  ///
  final Pointer<NT> Function(TD data)? toNative;
}

/// Typed extensions for [NativeMemoryManager].
extension TypedNativeMemoryManager on NativeMemoryManager {
  /// Returns a memory manager for a [Uint8List] that originates in native memory
  /// and is primarily owned by native code.
  static NativeMemoryManager<Char, Uint8List> nativeUint8List(
    Pointer<Char> ptr,
    int length,
  ) =>
      NativeMemoryManager<Char, Uint8List>.native(
        ptr,
        // TODO: actually make this copy the data
        toDart: (Pointer<Char> ptr) => ptr.toUint8List(length),
      );

  /// Returns a memory manager for a [Uint8List] that originates in Dart memory
  /// and is primarily owned by Dart code.
  static NativeMemoryManager<Char, Uint8List> dartUint8List(
    Uint8List data,
  ) =>
      NativeMemoryManager<Char, Uint8List>.dart(
        data,
        toNative: (Uint8List data) => data.copyToNative(),
      );

  /// Returns a memory manager for a [Float32List] that originates in native memory
  /// and is primarily owned by native code.
  static NativeMemoryManager<Float, Float32List> nativeFloat32List(
    Pointer<Float> ptr,
    int length,
  ) =>
      NativeMemoryManager<Float, Float32List>.native(
        ptr,
        // TODO: actually make this copy the data
        toDart: (Pointer<Float> ptr) => ptr.toFloat32List(length),
      );

  /// Returns a memory manager for a [Float32List] that originates in Dart memory
  /// and is primarily owned by Dart code.
  static NativeMemoryManager<Float, Float32List> dartFloat32List(
    Float32List data,
  ) =>
      NativeMemoryManager<Float, Float32List>.dart(
        data,
        toNative: (Float32List data) => data.copyToNative(),
      );
}

// /// {@template Uint8ListMemoryManager}
// /// {@endtemplate}
// class Uint8ListMemoryManager extends NativeMemoryManager<Char, Uint8List> {
//   /// {@macro Uint8ListMemoryManager}
//   Uint8ListMemoryManager(
//     super.pointer, {
//     required this.length,
//   });

//   /// Length of the list of integers.
//   final int length;

//   @override
//   Uint8List copyToDart() =>
//       Uint8List.fromList(pointer.cast<Uint8>().asTypedList(length));
// }
