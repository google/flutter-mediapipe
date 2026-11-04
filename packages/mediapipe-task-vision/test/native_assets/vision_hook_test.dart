import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:mediapipe_core/native_assets.dart';
import 'package:test/test.dart';

import '../../hook/build.dart' as hook;
import '../../vision_tasks.dart';

void main() {
  PackageUserDefines defines(Map<String, Object?> values) => PackageUserDefines(
    workspacePubspec: PackageUserDefinesSource(
      defines: values,
      basePath: Uri.directory('.'),
    ),
  );

  Matcher failsWith<T extends Error>(Matcher message) => throwsA(
    isA<T>().having(
      (error) => (error as dynamic).message.toString(),
      'message',
      message,
    ),
  );

  /// Google's libraries named by SHA-256, as `asset_source` holds them, or
  /// null where this checkout has none; the hook then downloads them.
  final source = () {
    final directory = Directory(
      Platform.environment['MEDIAPIPE_ASSET_SOURCE'] ??
          '../../build/split-runtimes-source',
    );
    return directory.existsSync() ? directory.absolute.path : null;
  }();

  /// What core's hook forwards when the app sets `asset_source`.
  Map<String, List<EncodedAsset>> core(String? path) => {
    'mediapipe_core': [
      if (path != null)
        EncodedAsset('hooks/metadata', {'key': 'asset_source', 'value': path}),
    ],
  };

  test('targets without a library name the ones that have one', () {
    for (final (os, architecture) in [
      (OS.linux, Architecture.arm64),
      (OS.windows, Architecture.arm64),
    ]) {
      expect(
        testCodeBuildHook(
          mainMethod: hook.main,
          targetOS: os,
          targetArchitecture: architecture,
          check: (_, _) => fail('Unsupported build unexpectedly succeeded'),
        ),
        failsWith<UnsupportedError>(
          allOf(contains('$os/$architecture'), contains('macos/arm64')),
        ),
      );
    }
    expect(
      testCodeBuildHook(
        mainMethod: hook.main,
        targetOS: OS.android,
        targetArchitecture: Architecture.ia32,
        check: (_, _) => fail('Unsupported build unexpectedly succeeded'),
      ),
      failsWith<UnsupportedError>(
        allOf(contains('android/ia32'), contains('android/arm64')),
      ),
    );
  });

  test('Intel slices name how to leave them out of the build', () {
    // Flutter's macOS release and profile builds include Intel by default.
    expect(
      testCodeBuildHook(
        mainMethod: hook.main,
        targetOS: OS.macOS,
        targetArchitecture: Architecture.x64,
        check: (_, _) => fail('Intel macOS build unexpectedly succeeded'),
      ),
      failsWith<UnsupportedError>(
        allOf(
          contains('macos/x64'),
          contains('ARCHS = arm64'),
          contains('EXCLUDED_ARCHS = x86_64'),
          contains('macos/Runner/Configs/AppInfo.xcconfig'),
          contains('flutter config --enable-macos-arm64-only'),
        ),
      ),
    );
    expect(
      testCodeBuildHook(
        mainMethod: hook.main,
        targetOS: OS.iOS,
        targetArchitecture: Architecture.x64,
        targetIOSSdk: IOSSdk.iPhoneSimulator,
        check: (_, _) => fail('Intel simulator build unexpectedly succeeded'),
      ),
      failsWith<UnsupportedError>(
        allOf(
          contains('ios-simulator/x64'),
          contains('EXCLUDED_ARCHS[sdk=iphonesimulator*] = x86_64'),
        ),
      ),
    );
  });

  test('validated tasks cover exactly what the platform jobs validate', () {
    // The hook refuses any task missing from these rows, so widening them
    // without adding the task to a platform job would claim coverage nothing
    // proves. Google's Windows library runs the stateful Interactive
    // Segmenter too slowly to offer (upstream-issues.md UP-048).
    expect(
      visionRuntimeTasks.keys,
      unorderedEquals(familyRuntimes['vision']!.keys),
    );
    for (final MapEntry(key: target, value: tasks)
        in visionRuntimeTasks.entries) {
      expect(
        tasks,
        target == 'windows/x64'
            ? visionTasks.difference({'interactive_segmenter'})
            : visionTasks,
        reason: target,
      );
    }
  });

  test('an unvalidated task names the validated ones', () {
    expect(
      testCodeBuildHook(
        mainMethod: hook.main,
        targetOS: OS.windows,
        targetArchitecture: Architecture.x64,
        userDefines: defines({
          'tasks': ['interactive_segmenter'],
        }),
        check: (_, _) => fail('Unvalidated task unexpectedly accepted'),
      ),
      failsWith<UnsupportedError>(
        allOf(contains('interactive_segmenter'), contains('pose_landmarker')),
      ),
    );
  });

  test("every task binds Google's one vision library", () async {
    await testCodeBuildHook(
      mainMethod: hook.main,
      targetOS: OS.linux,
      targetArchitecture: Architecture.x64,
      userDefines: defines({
        'tasks': ['face_detector', 'hand_landmarker', 'interactive_segmenter'],
      }),
      assets: core(source),
      check: (_, output) {
        final asset = output.assets.code.single;
        expect(asset.id, 'package:mediapipe_vision/mediapipe.dylib');
        expect(asset.linkMode, isA<DynamicLoadingBundled>());
        expect(
          asset.file!.pathSegments.last,
          familyRuntimes['vision']!['linux/x64']!.fileName,
        );
      },
    );
  });

  test(
    "Android bundles Google's vision library like every native target",
    () async {
      await testCodeBuildHook(
        mainMethod: hook.main,
        targetOS: OS.android,
        targetArchitecture: Architecture.arm64,
        targetAndroidNdkApi: 28,
        userDefines: defines({
          'tasks': ['hand_landmarker', 'interactive_segmenter'],
        }),
        assets: core(source),
        check: (_, output) {
          final asset = output.assets.code.single;
          expect(asset.id, 'package:mediapipe_vision/mediapipe.dylib');
          expect(asset.linkMode, isA<DynamicLoadingBundled>());
          expect(
            asset.file!.pathSegments.last,
            familyRuntimes['vision']!['android/arm64']!.fileName,
          );
        },
      );
    },
  );

  test('Android below API 28 names the minSdk fix', () {
    expect(
      testCodeBuildHook(
        mainMethod: hook.main,
        targetOS: OS.android,
        targetArchitecture: Architecture.arm64,
        targetAndroidNdkApi: 24,
        assets: core('/unused'),
        check: (_, _) => fail('An unsupported API level was accepted'),
      ),
      failsWith<UnsupportedError>(
        allOf(contains('API 24'), contains('minSdk = 28')),
      ),
    );
  });

  test('unknown task names list every accepted task', () {
    expect(
      testCodeBuildHook(
        mainMethod: hook.main,
        targetOS: OS.macOS,
        targetArchitecture: Architecture.arm64,
        userDefines: defines({
          'tasks': ['face_detecter'],
        }),
        check: (_, _) => fail('Invalid selection unexpectedly accepted'),
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          allOf(contains('pose_landmarker'), contains('interactive_segmenter')),
        ),
      ),
    );
  });
}
