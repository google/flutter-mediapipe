import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:jni/jni.dart';

/// Runs the `JNI_OnLoad` of the Google library that holds [symbol], once per
/// process, on Android only, and does nothing elsewhere or on any failure.
///
/// Google's Android libraries upload their usage log through Java from the
/// nightly of October 21, 2026 on (1.2.2 included), with the `JavaVM` their
/// `JNI_OnLoad` stores. Java's `System.loadLibrary` runs it; Dart's native
/// assets load the library with `dlopen`, which does not, so a family calls
/// this with one of its resolved symbols before its first task is created.
/// A library that exports no `JNI_OnLoad` of its own is skipped. Any isolate
/// may call it: each remembers the libraries it has seen, and the process
/// claims each library through Java so that only one isolate runs it.
void runJniOnLoad(Pointer<NativeType> symbol) {
  if (!Platform.isAndroid) return;
  try {
    _runner.run(symbol);
  } catch (_) {}
}

final _runner = JniOnLoadRunner(const _AndroidJniHost());

/// A loaded library, as `dladdr` names it.
typedef LoadedLibrary = ({String path, int base});

/// A library's `JNI_OnLoad`, called with the `JavaVM` and a null reserved
/// pointer.
typedef JniOnLoad = int Function(Pointer<Void> vm, Pointer<Void> reserved);

/// What [JniOnLoadRunner] needs from the process; tests give their own.
abstract interface class JniOnLoadHost {
  /// The loaded library holding [symbol], or null.
  LoadedLibrary? libraryOf(Pointer<NativeType> symbol);

  /// [library]'s own `JNI_OnLoad`, or null where it exports none (one found
  /// only in a library it depends on does not count).
  JniOnLoad? onLoadIn(LoadedLibrary library);

  /// Claims [key] for this process, true for the first caller of any
  /// isolate.
  bool claim(String key);

  /// The process's `JavaVM`, or null where there is none yet.
  Pointer<Void> javaVm();
}

/// The JNI versions ART accepts from `JNI_OnLoad` (1.2, 1.4 and 1.6).
const jniOnLoadVersions = {0x10002, 0x10004, 0x10006};

/// Runs each library's `JNI_OnLoad` at most once, through [JniOnLoadHost].
final class JniOnLoadRunner {
  /// A runner for one isolate.
  JniOnLoadRunner(this._host);

  final JniOnLoadHost _host;
  final _seen = <int>{};

  /// Runs the `JNI_OnLoad` of the library holding [symbol] unless this
  /// isolate has seen that library or another isolate claimed it, and
  /// returns whether it ran and returned a version ART accepts. Any other
  /// value would fail `System.loadLibrary`; Dart has already loaded the
  /// library, so there is nothing to undo, and its tasks still run, without
  /// uploads.
  bool run(Pointer<NativeType> symbol) {
    final library = _host.libraryOf(symbol);
    if (library == null || _seen.contains(library.base)) return false;
    final vm = _host.javaVm();
    if (vm == nullptr) return false;
    _seen.add(library.base);
    final onLoad = _host.onLoadIn(library);
    if (onLoad == null) return false;
    if (!_host.claim('mediapipe_flutter.JNI_OnLoad ${library.path}')) {
      return false;
    }
    return jniOnLoadVersions.contains(onLoad(vm, nullptr));
  }
}

final class _DlInfo extends Struct {
  external Pointer<Utf8> fname;
  external Pointer<Void> fbase;
  external Pointer<Void> sname;
  external Pointer<Void> saddr;
}

typedef _DladdrNative = Int Function(Pointer<NativeType>, Pointer<_DlInfo>);
typedef _Dladdr = int Function(Pointer<NativeType>, Pointer<_DlInfo>);
typedef _JniOnLoadNative = Int32 Function(Pointer<Void>, Pointer<Void>);

final class _AndroidJniHost implements JniOnLoadHost {
  const _AndroidJniHost();

  static final _libc = DynamicLibrary.process();
  static final _dladdr = _libc.lookupFunction<_DladdrNative, _Dladdr>('dladdr');

  @override
  LoadedLibrary? libraryOf(Pointer<NativeType> symbol) => using((arena) {
    final info = arena<_DlInfo>();
    if (_dladdr(symbol, info) == 0 || info.ref.fname == nullptr) return null;
    return (path: info.ref.fname.toDartString(), base: info.ref.fbase.address);
  });

  // By file name, as Dart's native assets open it, and through
  // `DynamicLibrary.open`: the linker picks the namespace from `dlopen`'s
  // caller, and Dart code calling `dlopen` itself gets one that cannot see
  // the app's libraries. The name finds the loaded copy (also inside the
  // APK), whose path `dladdr` gives as `base.apk!/lib/<abi>/<name>`.
  @override
  JniOnLoad? onLoadIn(LoadedLibrary library) {
    final name = library.path.substring(library.path.lastIndexOf('/') + 1);
    final opened = DynamicLibrary.open(name);
    if (!opened.providesSymbol('JNI_OnLoad')) return null;
    final address = opened.lookup<NativeFunction<_JniOnLoadNative>>(
      'JNI_OnLoad',
    );
    if (libraryOf(address)?.base != library.base) return null;
    return address.asFunction<JniOnLoad>();
  }

  @override
  bool claim(String key) {
    final system = JClass.forName('java/lang/System');
    final properties = system.staticMethodId(
      'getProperties',
      '()Ljava/util/Properties;',
    )(system, JObject.type, const []);
    final name = key.toJString();
    // Hashtable's putIfAbsent is synchronized, so one caller wins.
    final previous = JClass.forName('java/util/Properties')
        .instanceMethodId(
          'putIfAbsent',
          '(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;',
        )
        .callNullable(properties, JObject.type, [name, name]);
    previous?.release();
    name.release();
    properties.release();
    return previous == null;
  }

  // package:jni's own `GetJavaVM`: its `Jni.getJavaVM()` is an instance
  // member of a class with no instances, and `Jni.env` is internal. A
  // package:jni without the symbol throws here, which skips the call.
  @override
  Pointer<Void> javaVm() => DynamicLibrary.open('libdartjni.so')
      .lookupFunction<Pointer<Void> Function(), Pointer<Void> Function()>(
        'GetJavaVM',
      )();
}
