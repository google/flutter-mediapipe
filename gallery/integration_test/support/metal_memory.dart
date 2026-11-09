import 'dart:ffi';

import 'package:ffi/ffi.dart';

typedef _MetalDevice = Pointer<Void> Function();
typedef _SelectorNative = Pointer<Void> Function(Pointer<Utf8>);
typedef _Selector = Pointer<Void> Function(Pointer<Utf8>);
typedef _SizeNative = Uint64 Function(Pointer<Void>, Pointer<Void>);
typedef _Size = int Function(Pointer<Void>, Pointer<Void>);

/// The bytes this process holds on Metal's default device, from
/// `-[MTLDevice currentAllocatedSize]`, on macOS and iOS. The default device is
/// the one Google's library takes for its GPU delegate. It also holds what the
/// app itself draws with, so compare two readings.
int metalAllocatedBytes() {
  final metal = DynamicLibrary.open(
    '/System/Library/Frameworks/Metal.framework/Metal',
  );
  final device = metal
      .lookupFunction<_MetalDevice, _MetalDevice>(
        'MTLCreateSystemDefaultDevice',
      )
      .call();
  if (device == nullptr) throw StateError('This device has no Metal device.');
  final runtime = DynamicLibrary.process();
  final selector = using(
    (arena) => runtime.lookupFunction<_SelectorNative, _Selector>(
      'sel_registerName',
    )('currentAllocatedSize'.toNativeUtf8(allocator: arena)),
  );
  return runtime.lookupFunction<_SizeNative, _Size>('objc_msgSend')(
    device,
    selector,
  );
}
