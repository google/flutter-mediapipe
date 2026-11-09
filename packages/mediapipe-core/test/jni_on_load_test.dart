@TestOn('vm')
library;

import 'dart:ffi';

import 'package:mediapipe_core/platform_interface.dart' show runJniOnLoad;
import 'package:mediapipe_core/src/jni_on_load.dart' hide runJniOnLoad;
import 'package:test/test.dart';

final _vm = Pointer<Void>.fromAddress(0x7000);

/// Libraries by the address of a symbol in them; each has a `JNI_OnLoad`
/// unless listed in [noOnLoad].
final class _FakeHost implements JniOnLoadHost {
  _FakeHost(this.libraries, {this.noOnLoad = const {}, this.version = 0x10006});

  final Map<int, LoadedLibrary> libraries;
  final Set<String> noOnLoad;
  final int version;
  Pointer<Void> vm = _vm;
  final claims = <String>{};
  final lost = <String>{};
  final calls = <(String, Pointer<Void>, Pointer<Void>)>[];

  @override
  LoadedLibrary? libraryOf(Pointer<NativeType> symbol) =>
      libraries[symbol.address];

  @override
  JniOnLoad? onLoadIn(LoadedLibrary library) {
    if (noOnLoad.contains(library.path)) return null;
    return (vm, reserved) {
      calls.add((library.path, vm, reserved));
      return version;
    };
  }

  @override
  bool claim(String key) => !lost.contains(key) && claims.add(key);

  @override
  Pointer<Void> javaVm() => vm;
}

Pointer<Void> _at(int address) => Pointer<Void>.fromAddress(address);

void main() {
  const text = (path: 'libmediapipe_tasks_text.so', base: 0x1000);
  const vision = (path: 'libmediapipe_tasks_vision.so', base: 0x2000);

  test('calls JNI_OnLoad with the JavaVM and a null reserved pointer', () {
    final host = _FakeHost({0x1010: text});
    expect(JniOnLoadRunner(host).run(_at(0x1010)), isTrue);
    expect(host.calls, [(text.path, _vm, nullptr)]);
  });

  test('runs once per library, whichever symbol names it', () {
    final host = _FakeHost({0x1010: text, 0x1020: text});
    final runner = JniOnLoadRunner(host);
    runner.run(_at(0x1010));
    expect(runner.run(_at(0x1020)), isFalse);
    expect(runner.run(_at(0x1010)), isFalse);
    expect(host.calls, hasLength(1));
  });

  test('runs each family library once', () {
    final host = _FakeHost({0x1010: text, 0x2010: vision});
    final runner = JniOnLoadRunner(host);
    runner
      ..run(_at(0x1010))
      ..run(_at(0x2010))
      ..run(_at(0x2010));
    expect(host.calls.map((call) => call.$1), [text.path, vision.path]);
  });

  test('a library another isolate claimed is not run again', () {
    final host = _FakeHost({0x1010: text});
    expect(JniOnLoadRunner(host).run(_at(0x1010)), isTrue);
    // A second isolate has its own runner but shares the process claim.
    expect(JniOnLoadRunner(host).run(_at(0x1010)), isFalse);
    expect(host.calls, hasLength(1));
  });

  test('skips a symbol in no known library', () {
    final host = _FakeHost({});
    expect(JniOnLoadRunner(host).run(_at(0x1010)), isFalse);
    expect(host.claims, isEmpty);
  });

  test('skips a library without its own JNI_OnLoad, claiming nothing', () {
    final host = _FakeHost({0x1010: text}, noOnLoad: {text.path});
    expect(JniOnLoadRunner(host).run(_at(0x1010)), isFalse);
    expect(host.claims, isEmpty);
    expect(host.calls, isEmpty);
  });

  test('waits for a JavaVM, claiming nothing until there is one', () {
    final host = _FakeHost({0x1010: text})..vm = nullptr;
    final runner = JniOnLoadRunner(host);
    expect(runner.run(_at(0x1010)), isFalse);
    expect(host.claims, isEmpty);
    host.vm = _vm;
    expect(runner.run(_at(0x1010)), isTrue);
    expect(host.calls, [(text.path, _vm, nullptr)]);
  });

  test('does not call JNI_OnLoad when the claim is lost', () {
    final host = _FakeHost({0x1010: text})
      ..lost.add('mediapipe_flutter.JNI_OnLoad ${text.path}');
    expect(JniOnLoadRunner(host).run(_at(0x1010)), isFalse);
    expect(host.calls, isEmpty);
  });

  test('accepts the JNI versions ART accepts and nothing else', () {
    for (final version in [0x10002, 0x10004, 0x10006]) {
      final host = _FakeHost({0x1010: text}, version: version);
      expect(JniOnLoadRunner(host).run(_at(0x1010)), isTrue);
    }
    for (final version in [-1, 0, 0x10001, 0x10008]) {
      final host = _FakeHost({0x1010: text}, version: version);
      expect(JniOnLoadRunner(host).run(_at(0x1010)), isFalse);
      expect(host.calls, hasLength(1));
    }
  });

  test('runJniOnLoad does nothing off Android', () {
    // A pointer no library holds: on Android this would only be skipped.
    expect(() => runJniOnLoad(_at(0x10)), returnsNormally);
  });
}
