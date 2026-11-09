import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:jni/jni.dart';
import 'package:jni_flutter/jni_flutter.dart';

/// The app's ID and version as Google's native SDKs report them. Null off the
/// platforms below, or where the platform does not give them: reading them must
/// never stop a task from starting.
///
/// Tasks start on worker isolates, so this runs synchronously on any isolate.
/// On iOS: the bundle ID and `CFBundleShortVersionString`, through
/// CoreFoundation, which every iOS process loads. On Android: the package name
/// and `versionCode`, through JNI, from the application context Flutter gives
/// `package:jni_flutter`.
({String? id, String? version}) readAppIdentity() {
  try {
    if (Platform.isIOS) return _readBundle();
    if (Platform.isAndroid) return _readPackage();
  } catch (_) {}
  return (id: null, version: null);
}

({String? id, String? version}) _readPackage() {
  final context = androidApplicationContext;
  final contextClass = JClass.forName('android/content/Context');
  final name = contextClass.instanceMethodId(
    'getPackageName',
    '()Ljava/lang/String;',
  )(context, JString.type, const []);
  final manager = contextClass.instanceMethodId(
    'getPackageManager',
    '()Landroid/content/pm/PackageManager;',
  )(context, JObject.type, const []);
  final info = JClass.forName('android/content/pm/PackageManager')
      .instanceMethodId(
        'getPackageInfo',
        '(Ljava/lang/String;I)Landroid/content/pm/PackageInfo;',
      )(manager, JObject.type, [name, JValueInt(0)]);
  // Google's SDK reports versionCode, which every API level still fills.
  final versionCode = JClass.forName(
    'android/content/pm/PackageInfo',
  ).instanceFieldId('versionCode', 'I').get(info, jint.type);
  return (id: name.toDartString(), version: '$versionCode');
}

typedef _CFBundleGetMainBundleNative = Pointer<Void> Function();
typedef _CFBundleGetIdentifierNative = Pointer<Void> Function(Pointer<Void>);
typedef _CFBundleGetValueNative =
    Pointer<Void> Function(Pointer<Void>, Pointer<Void>);
typedef _CFStringCreateNative =
    Pointer<Void> Function(Pointer<Void>, Pointer<Utf8>, Uint32);
typedef _CFStringCreate =
    Pointer<Void> Function(Pointer<Void>, Pointer<Utf8>, int);
typedef _CFStringGetCStringNative =
    Bool Function(Pointer<Void>, Pointer<Utf8>, IntPtr, Uint32);
typedef _CFStringGetCString =
    bool Function(Pointer<Void>, Pointer<Utf8>, int, int);
typedef _CFGetTypeIDNative = UnsignedLong Function(Pointer<Void>);
typedef _CFGetTypeID = int Function(Pointer<Void>);
typedef _CFStringGetTypeIDNative = UnsignedLong Function();
typedef _CFStringGetTypeID = int Function();
typedef _CFReleaseNative = Void Function(Pointer<Void>);
typedef _CFRelease = void Function(Pointer<Void>);

// kCFStringEncodingUTF8.
const _utf8 = 0x08000100;

({String? id, String? version}) _readBundle() {
  final cf = DynamicLibrary.process();
  final mainBundle = cf
      .lookupFunction<
        _CFBundleGetMainBundleNative,
        _CFBundleGetMainBundleNative
      >('CFBundleGetMainBundle');
  final getIdentifier = cf
      .lookupFunction<
        _CFBundleGetIdentifierNative,
        _CFBundleGetIdentifierNative
      >('CFBundleGetIdentifier');
  final getValue = cf
      .lookupFunction<_CFBundleGetValueNative, _CFBundleGetValueNative>(
        'CFBundleGetValueForInfoDictionaryKey',
      );
  final createString = cf
      .lookupFunction<_CFStringCreateNative, _CFStringCreate>(
        'CFStringCreateWithCString',
      );
  final getCString = cf
      .lookupFunction<_CFStringGetCStringNative, _CFStringGetCString>(
        'CFStringGetCString',
      );
  final getTypeId = cf.lookupFunction<_CFGetTypeIDNative, _CFGetTypeID>(
    'CFGetTypeID',
  );
  final stringTypeId = cf
      .lookupFunction<_CFStringGetTypeIDNative, _CFStringGetTypeID>(
        'CFStringGetTypeID',
      );
  final release = cf.lookupFunction<_CFReleaseNative, _CFRelease>('CFRelease');

  return using((arena) {
    String? read(Pointer<Void> string) {
      if (string == nullptr || getTypeId(string) != stringTypeId()) return null;
      const capacity = 1024;
      final buffer = arena<Uint8>(capacity).cast<Utf8>();
      if (!getCString(string, buffer, capacity, _utf8)) return null;
      final value = buffer.toDartString();
      return value.isEmpty ? null : value;
    }

    final bundle = mainBundle();
    if (bundle == nullptr) return (id: null, version: null);
    final key = createString(
      nullptr,
      'CFBundleShortVersionString'.toNativeUtf8(allocator: arena),
      _utf8,
    );
    try {
      return (
        id: read(getIdentifier(bundle)),
        version: read(getValue(bundle, key)),
      );
    } finally {
      release(key);
    }
  });
}
