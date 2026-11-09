import 'dart:ffi';

import 'package:ffi/ffi.dart';

typedef _MetalDevice = Pointer<Void> Function();
typedef _SelectorNative = Pointer<Void> Function(Pointer<Utf8>);
typedef _Selector = Pointer<Void> Function(Pointer<Utf8>);
typedef _SizeNative = Uint64 Function(Pointer<Void>, Pointer<Void>);
typedef _Size = int Function(Pointer<Void>, Pointer<Void>);

/// The bytes this process holds on Metal's default device, from
/// `-[MTLDevice currentAllocatedSize]`. The default device is the one Google's
/// library takes for its GPU delegate. A copy of the gallery's
/// integration_test/support/metal_memory.dart, as a package test cannot import
/// the gallery.
int metalAllocatedBytes() {
  // Apple documents the default device as needing CoreGraphics, which a
  // command-line process does not link.
  DynamicLibrary.open(
    '/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics',
  );
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
