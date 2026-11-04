import 'dart:io';
import 'dart:typed_data';

import 'package:code_assets/code_assets.dart';
import 'package:crypto/crypto.dart';
import 'package:hooks/hooks.dart';
import 'package:mediapipe_core/native_assets.dart';
import 'package:mediapipe_core/platform_interface.dart'
    show tasksRuntimeTargets;
import 'package:test/test.dart';

/// Google's libraries named by SHA-256, as `asset_source` holds them, or null
/// where this checkout has none; the hooks then download them.
final Directory? _source = () {
  final configured = Platform.environment['MEDIAPIPE_ASSET_SOURCE'];
  final directory = Directory(
    configured ?? '../../build/split-runtimes-source',
  );
  return directory.existsSync() ? directory.absolute : null;
}();

/// A hook that bundles [family], from [_source] when there is one. Run in
/// core's own package, it reads `asset_source` from the user defines, as
/// core's hook does.
Future<void> _bundle(
  String family,
  OS os,
  Architecture architecture, {
  IOSSdk? sdk,
  required void Function(BuildOutput output) check,
}) => testCodeBuildHook(
  mainMethod: (arguments) => build(
    arguments,
    (input, output) => bundleFamilyRuntime(input, output, family: family),
  ),
  targetOS: os,
  targetArchitecture: architecture,
  targetIOSSdk: sdk,
  userDefines: PackageUserDefines(
    workspacePubspec: PackageUserDefinesSource(
      defines: {if (_source case final source?) 'asset_source': source.path},
      basePath: Uri.directory('.'),
    ),
  ),
  check: (_, output) => check(output),
);

void main() {
  test('every family has a library on every target the tasks claim', () {
    for (final MapEntry(key: family, value: runtimes)
        in familyRuntimes.entries) {
      // The simulator is part of the iOS claim.
      expect(runtimes.keys.toSet(), {
        ...tasksRuntimeTargets.keys,
        'ios-simulator/arm64',
      }, reason: family);
      for (final MapEntry(key: target, value: runtime) in runtimes.entries) {
        expect(runtime.sha256, matches(RegExp(r'^[a-f0-9]{64}$')));
        expect(runtime.bytes, greaterThan(1000000));
        expect(runtime.fileName, switch (target.split('/').first) {
          'macos' => 'libmediapipe_tasks_$family.dylib',
          'linux' || 'android' => 'libmediapipe_tasks_$family.so',
          'windows' => 'mediapipe_tasks_$family.dll',
          _ =>
            'MediaPipeTasks${family[0].toUpperCase()}${family.substring(1)}C'
                '.framework.zip',
        });
      }
    }
  });

  test("every library downloads from Google's archive, then the mirror", () {
    final runtimes = [
      for (final targets in familyRuntimes.values) ...targets.values,
    ];
    for (final runtime in runtimes) {
      // Google reuses file names across targets, so the mirror's digest
      // leads.
      expect(runtime.asset.urls, [
        '$familyRuntimeArchiveUrl#${runtime.path}',
        '$familyRuntimeBaseUrl/${runtime.sha256}-${runtime.fileName}',
      ]);
      expect(runtime.path, endsWith('/${runtime.fileName}'));
    }
    expect({
      for (final runtime in runtimes) runtime.path,
    }, hasLength({for (final runtime in runtimes) runtime.sha256}.length));
  });

  test('targets without a library name the ones that have one', () {
    expect(
      () => requireFamilyRuntime('text', 'linux/arm64'),
      throwsA(
        isA<UnsupportedError>().having(
          (error) => error.message,
          'message',
          allOf(contains('linux/arm64'), contains('macos/arm64')),
        ),
      ),
    );
  });

  test("macOS bundles Google's library as is, with room for the install name "
      'Dart and Flutter write', () async {
    final google = familyRuntimes['audio']!['macos/arm64']!;
    await _bundle(
      'audio',
      OS.macOS,
      Architecture.arm64,
      check: (output) {
        final asset = output.assets.code.single;
        expect(asset.id, 'package:mediapipe_core/mediapipe.dylib');
        final library = File.fromUri(asset.file!);
        expect(
          sha256.convert(library.readAsBytesSync()).toString(),
          google.sha256,
        );
        // An absolute install name under a deep build folder fits in a
        // few hundred bytes.
        expect(_headerRoom(library.readAsBytesSync()), greaterThan(4096));
      },
    );
  }, skip: Platform.isMacOS ? false : 'needs macOS');

  for (final (sdk, slice) in [
    (IOSSdk.iPhoneOS, 'device'),
    (IOSSdk.iPhoneSimulator, 'simulator'),
  ]) {
    test(
      "iOS bundles the $slice's arm64 binary under Google's file name",
      () async {
        await _bundle(
          'audio',
          OS.iOS,
          Architecture.arm64,
          sdk: sdk,
          check: (output) {
            final asset = output.assets.code.single;
            final library = File.fromUri(asset.file!);
            expect(library.uri.pathSegments.last, 'MediaPipeTasksAudioC');
            final archs = Process.runSync('lipo', ['-archs', library.path]);
            expect((archs.stdout as String).trim(), 'arm64');
            expect(_headerRoom(library.readAsBytesSync()), greaterThan(4096));
          },
        );
      },
      skip: Platform.isMacOS ? false : 'needs macOS',
    );
  }
}

/// Free bytes between a 64-bit Mach-O header's load commands and its first
/// section, which an install name rename needs.
int _headerRoom(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  expect(data.getUint32(0, Endian.little), 0xfeedfacf);
  final commands = data.getUint32(16, Endian.little);
  final commandBytes = data.getUint32(20, Endian.little);
  int? first;
  var offset = 32;
  for (var i = 0; i < commands; i++) {
    final size = data.getUint32(offset + 4, Endian.little);
    if (data.getUint32(offset, Endian.little) == 0x19) {
      final sections = data.getUint32(offset + 64, Endian.little);
      for (var s = 0; s < sections; s++) {
        final section = offset + 72 + s * 80;
        final fileOffset = data.getUint32(section + 48, Endian.little);
        if (fileOffset != 0 &&
            data.getUint64(section + 40, Endian.little) != 0 &&
            (first == null || fileOffset < first)) {
          first = fileOffset;
        }
      }
    }
    offset += size;
  }
  return first! - (32 + commandBytes);
}
