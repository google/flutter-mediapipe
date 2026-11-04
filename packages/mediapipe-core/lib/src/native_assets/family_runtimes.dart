import 'dart:io';

import 'package:archive/archive.dart';
import 'package:code_assets/code_assets.dart';
import 'package:crypto/crypto.dart';
import 'package:hooks/hooks.dart';

import '../../native_assets.dart';

/// The name each task family binds its own MediaPipe library under:
/// `package:mediapipe_vision/mediapipe.dylib`, `package:mediapipe_text/...`
/// and `package:mediapipe_audio/...`.
///
/// Google builds one C library per family, so an app bundles only the
/// families it depends on. The libraries keep their symbols to themselves,
/// so the three load side by side in one process.
const familyRuntimeAssetName = 'mediapipe.dylib';

/// Google's MediaPipe build that names the mirror release holding the
/// libraries: the 1.2.0 nightly build of October 18, 2026.
const familyRuntimeVersion = '1.2.0-nightly.20261018';

/// Google's archive of the October 18, 2026 build, where the hooks download
/// Google's libraries: each one is read from it with HTTP range requests,
/// without the rest of the archive.
const familyRuntimeArchiveUrl =
    'https://storage.googleapis.com/mediapipe-assets/prebuilts/'
    'mediapipe_tasks_c/20261018/mediapipe_tasks_c_20261018.zip';

/// The hooks' mirror of [familyRuntimeArchiveUrl]: a pre-release of this
/// project's native downloads, holding Google's files unmodified, posted with
/// Google's permission.
///
/// `hooks.user_defines.mediapipe_core.asset_source` replaces both for offline
/// and mirrored builds: a directory or URL holding each file under its
/// SHA-256.
const familyRuntimeBaseUrl =
    'https://github.com/hugocornellier/mediapipe_flutter_native/releases/'
    'download/per-family-v$familyRuntimeVersion';

/// One of Google's files, exactly as Google ships it.
final class FamilyRuntime {
  /// Pins the file at [path] in Google's archive by digest and size.
  const FamilyRuntime(this.path, this.sha256, this.bytes);

  /// Where the file is in [familyRuntimeArchiveUrl], such as
  /// `vision/darwin_arm64/libmediapipe_tasks_vision.dylib`.
  final String path;

  /// Google's file name: a library, or a framework zip on iOS.
  String get fileName => path.substring(path.lastIndexOf('/') + 1);

  /// SHA-256 of the only accepted bytes.
  final String sha256;

  /// Exact size in bytes.
  final int bytes;

  /// The download: the file in Google's archive, then the copy at
  /// [familyRuntimeBaseUrl]. Google gives several targets' libraries the
  /// same file name, so the mirror names each by its digest first; the hook
  /// still saves it as [fileName].
  DownloadAsset get asset => DownloadAsset(
    url: '$familyRuntimeArchiveUrl#$path',
    sha256: sha256,
    mirrors: ['$familyRuntimeBaseUrl/$sha256-$fileName'],
  );
}

/// Google's per-family libraries, by family and build target.
///
/// Android has 32-bit ARM too, which Flutter's release builds include, though
/// no task claims it; browsers run Google's JavaScript runtime instead.
///
/// Every file comes from Google's nightly build of October 18, 2026
/// (MediaPipe 1.2.0), unmodified. iOS has one framework zip for devices and
/// one for the Simulator.
const familyRuntimes = <String, Map<String, FamilyRuntime>>{
  'vision': {
    'macos/arm64': FamilyRuntime(
      'vision/darwin_arm64/libmediapipe_tasks_vision.dylib',
      '87002779cea6aedafb3423de382a07b291b8566508027e54de3eaac948c646f1',
      27020624,
    ),
    'android/arm64': FamilyRuntime(
      'vision/android_arm64-v8a/libmediapipe_tasks_vision.so',
      '65e01b32d720a57adeab7361d0fdd1038e4e3740abf52937ef344c11c404a12f',
      14411048,
    ),
    'android/arm': FamilyRuntime(
      'vision/android_armeabi-v7a/libmediapipe_tasks_vision.so',
      'b0c9449c766f979dfc84e8a686157ce74b314ff88cbf2fae3861ca16a1106537',
      10126036,
    ),
    'android/x64': FamilyRuntime(
      'vision/android_x86_64/libmediapipe_tasks_vision.so',
      '759765cc25288d88e720d6bec4d028b56b303e9fc0662685c1cf19ba090c7e29',
      18031216,
    ),
    'ios/arm64': FamilyRuntime(
      'vision/ios_arm64/MediaPipeTasksVisionC.framework.zip',
      '4e0cc4fff57070a0f1817b6907df51f0e80b1b11193b8591dd22d52993852f57',
      7976144,
    ),
    'ios-simulator/arm64': FamilyRuntime(
      'vision/ios_simulator/MediaPipeTasksVisionC.framework.zip',
      '077ffe8b9b3f468c971f25e56af3c8c48920108fa6cffa8ec6ddce60fe53004c',
      17523500,
    ),
    'linux/x64': FamilyRuntime(
      'vision/linux_x86_64/libmediapipe_tasks_vision.so',
      'aa2a694b48d4b8e96680e85fb4cd62b106bed8d59785c69c7004c64d31af90ba',
      30537008,
    ),
    'windows/x64': FamilyRuntime(
      'vision/windows_x86_64/mediapipe_tasks_vision.dll',
      'da8a304f42ee634efeddaa8f7b6ece394e581457dc037cc98ee003b15ac6fe79',
      25192448,
    ),
  },
  'text': {
    'macos/arm64': FamilyRuntime(
      'text/darwin_arm64/libmediapipe_tasks_text.dylib',
      'b1c67dcf887c9a45ddc03af8045cccfeacfcbb9239a0cd245c543c1500b991af',
      25224000,
    ),
    'android/arm64': FamilyRuntime(
      'text/android_arm64-v8a/libmediapipe_tasks_text.so',
      '3ab9e66f211b144772260d6bc42b6fa0b54e9a48225de8b7de9e661b5c060747',
      15519704,
    ),
    'android/arm': FamilyRuntime(
      'text/android_armeabi-v7a/libmediapipe_tasks_text.so',
      '72b39c293716187c4185f7c1e90532f25558c1a8ecda82a4b797f3628416db06',
      10589260,
    ),
    'android/x64': FamilyRuntime(
      'text/android_x86_64/libmediapipe_tasks_text.so',
      'd896a4db0a075cab272542da2d91a24dec60f20bf4c1a9d36c4f9c144996dc8c',
      19135392,
    ),
    'ios/arm64': FamilyRuntime(
      'text/ios_arm64/MediaPipeTasksTextC.framework.zip',
      '1db6cf7fd3505b34c90ac42a93357cfbb46f0b61c4477ec62120d51b963698f9',
      8290623,
    ),
    'ios-simulator/arm64': FamilyRuntime(
      'text/ios_simulator/MediaPipeTasksTextC.framework.zip',
      'd50e1e028c6a8094bfeddfb590c96bb1f8c92e0f5a1fb626fab12062b2b9fea7',
      17956600,
    ),
    'linux/x64': FamilyRuntime(
      'text/linux_x86_64/libmediapipe_tasks_text.so',
      'c031880d7613a74a33d15cbb1fb906d210a9a56029bb720dcc21e444776d1ceb',
      38308944,
    ),
    'windows/x64': FamilyRuntime(
      'text/windows_x86_64/mediapipe_tasks_text.dll',
      'e92ae9d06ae0fc3aef6f568580ab43f1de7bfac5ca0b8c89f3b7ec872f1cfa64',
      37528576,
    ),
  },
  'audio': {
    'macos/arm64': FamilyRuntime(
      'audio/darwin_arm64/libmediapipe_tasks_audio.dylib',
      '2182efbea9137f0d3e08673df322740334b3abf5656329e78ba6aed03fea63f9',
      12609120,
    ),
    'android/arm64': FamilyRuntime(
      'audio/android_arm64-v8a/libmediapipe_tasks_audio.so',
      '90797a1caed1f952bc73f3fac4e2fc9d1c8f872ebbeb246f4743ca0635da4cad',
      9726096,
    ),
    'android/arm': FamilyRuntime(
      'audio/android_armeabi-v7a/libmediapipe_tasks_audio.so',
      '55bd2042a095103d863253ac6b96054519d69f04f1060ceba9ceb81bacde48bd',
      6560956,
    ),
    'android/x64': FamilyRuntime(
      'audio/android_x86_64/libmediapipe_tasks_audio.so',
      '97375437a80f11d2c78f88e55f23a6b8c449f387911e66b2151c3a6767ae8645',
      12566328,
    ),
    'ios/arm64': FamilyRuntime(
      'audio/ios_arm64/MediaPipeTasksAudioC.framework.zip',
      'd4de9b94e79f9f437b7b9cfe75c5aa2ffc3df566c9601414a13480eb06fe204d',
      3996893,
    ),
    'ios-simulator/arm64': FamilyRuntime(
      'audio/ios_simulator/MediaPipeTasksAudioC.framework.zip',
      '2f0cbe0359111f02362f88d7c9b6973c7564169755a1ce62c7b8d05e931453b6',
      9086819,
    ),
    'linux/x64': FamilyRuntime(
      'audio/linux_x86_64/libmediapipe_tasks_audio.so',
      '5e7adc22d9f5a0b2187e0244bad3a91f9c2d3173e38f24764b273a0fe160250a',
      19812432,
    ),
    'windows/x64': FamilyRuntime(
      'audio/windows_x86_64/mediapipe_tasks_audio.dll',
      '56e397ce8cac13c405e2583759a480d3292e7fbe00f35499c97a5c8bc27fe24e',
      17030144,
    ),
  },
  'retrieval': {
    'macos/arm64': FamilyRuntime(
      'retrieval/darwin_arm64/libmediapipe_tasks_retrieval.dylib',
      '2edfce1a409da01b3a400e5f2684020704b20fb484248b486fd1d604e78ae933',
      19665888,
    ),
    'android/arm64': FamilyRuntime(
      'retrieval/android_arm64-v8a/libmediapipe_tasks_retrieval.so',
      '1724ea98b4b4e3f3208a68bc61c66f49a3045dd7f50cfe34e7abbbeb93ab4d2c',
      13146744,
    ),
    'android/arm': FamilyRuntime(
      'retrieval/android_armeabi-v7a/libmediapipe_tasks_retrieval.so',
      '1c5e7f9bee375fa4f209d9c130a910aa611756267e4737e3f16491d8f3765ea3',
      9149948,
    ),
    'android/x64': FamilyRuntime(
      'retrieval/android_x86_64/libmediapipe_tasks_retrieval.so',
      '4b8fc4f0e7f1e405370f91e135abef82742e454dbd5e25ea229d7c1da840c4e3',
      16622232,
    ),
    'ios/arm64': FamilyRuntime(
      'retrieval/ios_arm64/MediaPipeTasksRetrievalC.framework.zip',
      'f2199620afbe124d4ae3e2f40b946b81dfda926a43b04f7c89f78aeea857fec3',
      5855439,
    ),
    'ios-simulator/arm64': FamilyRuntime(
      'retrieval/ios_simulator/MediaPipeTasksRetrievalC.framework.zip',
      '6b51273cb20502932c5b11192bd0e059f8c8e4594441254801798a0c00ead087',
      13155674,
    ),
    'linux/x64': FamilyRuntime(
      'retrieval/linux_x86_64/libmediapipe_tasks_retrieval.so',
      '1cc02d45a731a824116a6ca5982a35a4849a6f64a70d00c8ef85464dd8279025',
      28622480,
    ),
    'windows/x64': FamilyRuntime(
      'retrieval/windows_x86_64/mediapipe_tasks_retrieval.dll',
      'c6aed1ce79658d5be806ca58cf74a9be09d8882d6596e932a30fca9da1da2ad9',
      22858240,
    ),
  },
  'decision': {
    'macos/arm64': FamilyRuntime(
      'decision/darwin_arm64/libmediapipe_tasks_decision.dylib',
      '0a0cc1385a52d3e76a3ab6c30b4be72de593558e4c997d5b0d1f452e956f8de6',
      11296560,
    ),
    'android/arm64': FamilyRuntime(
      'decision/android_arm64-v8a/libmediapipe_tasks_decision.so',
      '5b561bf8a26518abe2de647c8862dc6c148ad84737f459143c693597818ae602',
      15789512,
    ),
    'android/arm': FamilyRuntime(
      'decision/android_armeabi-v7a/libmediapipe_tasks_decision.so',
      'ecb3311fbc4dd6d82377f5e3adacf5138e2220e763c85ae98337d63662cb77cf',
      10930876,
    ),
    'android/x64': FamilyRuntime(
      'decision/android_x86_64/libmediapipe_tasks_decision.so',
      '9d4a13c8e737a9276b5b7e54e37a3c059abd41af0d7de404bff3b18571e5eb77',
      19326112,
    ),
    'ios/arm64': FamilyRuntime(
      'decision/ios_arm64/MediaPipeTasksDecisionC.framework.zip',
      'e5831c335802620f4bce68e95d3f97536a28ffbb6c44188ad01f6d71e6bc5ea1',
      5229894,
    ),
    'ios-simulator/arm64': FamilyRuntime(
      'decision/ios_simulator/MediaPipeTasksDecisionC.framework.zip',
      '7daa2b42d12808ab1e5e85311302c4cc2f953cd1e907fd5ca7e533bcfa2cb516',
      11622225,
    ),
    'linux/x64': FamilyRuntime(
      'decision/linux_x86_64/libmediapipe_tasks_decision.so',
      '62e8a66717d903c2e449953ff30c696fff46a4453e06b6dfc952ffbf5e712193',
      32214752,
    ),
    'windows/x64': FamilyRuntime(
      'decision/windows_x86_64/mediapipe_tasks_decision.dll',
      'b98ae97241fd8582b11b25fa343313098ad6ce111643b09629e106adfc371a11',
      34307584,
    ),
  },
};

/// [family]'s library for [target], or an [UnsupportedError] naming the
/// targets that have one.
FamilyRuntime requireFamilyRuntime(String family, String target) {
  final runtimes = familyRuntimes[family];
  if (runtimes == null) throw ArgumentError.value(family, 'family');
  final runtime = runtimes[target];
  if (runtime != null) return runtime;
  throw UnsupportedError(_unsupportedTarget(family, target, runtimes.keys));
}

String _unsupportedTarget(
  String family,
  String target,
  Iterable<String> targets,
) => switch (target) {
  // Flutter's macOS release and profile builds include Intel unless the
  // app excludes it; debug builds target only the host.
  'macos/x64' =>
    'mediapipe_$family has no MediaPipe library for Intel Macs '
        "(macos/x64), and Flutter's macOS release and profile builds "
        'include Intel by default. Build the app for Apple Silicon only: add '
        'ARCHS = arm64 and EXCLUDED_ARCHS = x86_64 to '
        'macos/Runner/Configs/AppInfo.xcconfig, or run '
        '`flutter config --enable-macos-arm64-only`.',
  'ios-simulator/x64' =>
    'mediapipe_$family has no MediaPipe library for the Intel iOS '
        'Simulator (ios-simulator/x64). Exclude that slice in the Runner '
        "target's build settings: "
        'EXCLUDED_ARCHS[sdk=iphonesimulator*] = x86_64.',
  _ =>
    'mediapipe_$family has no MediaPipe library for $target. Targets: '
        '${targets.join(', ')}, plus browsers through Google\'s '
        'JavaScript runtime.',
};

/// The lowest Android API level Google's Android libraries load on: they are
/// built for Android 9.
const familyRuntimeMinimumAndroidApi = 28;

/// Bundles [family]'s library for the hook's target under
/// [familyRuntimeAssetName], in the calling family's package: Google's
/// per-family library ([familyRuntimes]).
Future<void> bundleFamilyRuntime(
  BuildInput input,
  BuildOutputBuilder output, {
  required String family,
}) async {
  final code = input.config.code;
  requireDynamicLinking(code);
  final target = buildTarget(code);
  final runtime = requireFamilyRuntime(family, target);
  if (code.targetOS == OS.android &&
      code.android.targetNdkApi < familyRuntimeMinimumAndroidApi) {
    throw UnsupportedError(
      "mediapipe_$family runs Google's MediaPipe library, which needs Android "
      '9 (API $familyRuntimeMinimumAndroidApi); this app targets API '
      '${code.android.targetNdkApi}. Set minSdk = '
      '$familyRuntimeMinimumAndroidApi in android/app/build.gradle(.kts).',
    );
  }
  final source = hookAssetSource(input);
  final cache = Directory.fromUri(
    input.outputDirectoryShared.resolve('${runtime.sha256}/'),
  );
  final download = await downloadVerified(
    runtime.asset,
    File.fromUri(cache.uri.resolve(runtime.fileName)),
    source: source,
  );
  if (await download.length() != runtime.bytes) {
    throw StateError('$target $family runtime size mismatch.');
  }
  final library = code.targetOS == OS.iOS
      ? await _extractIosBinary(
          download,
          simulator: code.iOS.targetSdk == IOSSdk.iPhoneSimulator,
        )
      : download;
  output.dependencies.add(download.uri);
  output.assets.code.add(
    CodeAsset(
      package: input.packageName,
      name: familyRuntimeAssetName,
      linkMode: DynamicLoadingBundled(),
      file: library.uri,
    ),
  );
}

/// The arm64 binary from Google's framework zip for an iOS device or the
/// Simulator.
///
/// It keeps Google's file name, which Flutter names the framework after.
Future<File> _extractIosBinary(File zip, {required bool simulator}) {
  final name = zip.uri.pathSegments.last.replaceFirst('.framework.zip', '');
  return _derived(zip, '${simulator ? 'simulator' : 'device'}/$name', (
    copy,
  ) async {
    final path = '$name.framework/$name';
    final entry = ZipDecoder()
        .decodeBytes(await zip.readAsBytes())
        .findFile(path);
    if (entry == null) throw StateError('${zip.path} has no $path.');
    await copy.writeAsBytes(entry.readBytes()!, flush: true);
    // The simulator binary also holds x86_64; a hook bundles one
    // architecture.
    if (simulator) {
      await _run('xcrun', [
        'lipo',
        copy.path,
        '-thin',
        'arm64',
        '-output',
        copy.path,
      ]);
    }
  });
}

/// [name] derived from the verified [source] by [prepare], made once and
/// reused only while its bytes match the digest recorded when it was made.
Future<File> _derived(
  File source,
  String name,
  Future<void> Function(File copy) prepare,
) async {
  final file = File.fromUri(source.parent.uri.resolve(name));
  final record = File('${file.path}.sha256');
  if (await file.exists() && await record.exists()) {
    if (await _digest(file) == (await record.readAsString()).trim()) {
      return file;
    }
  }
  await file.parent.create(recursive: true);
  final temporary = await file.parent.createTemp('.prepare-');
  try {
    final copy = File.fromUri(
      temporary.uri.resolve(file.uri.pathSegments.last),
    );
    await source.copy(copy.path);
    await prepare(copy);
    await record.writeAsString(await _digest(copy));
    return await copy.rename(file.path);
  } finally {
    await temporary.delete(recursive: true);
  }
}

Future<String> _digest(File file) async =>
    (await sha256.bind(file.openRead()).first).toString();

Future<String> _run(String executable, List<String> arguments) async {
  final result = await Process.run(executable, arguments);
  if (result.exitCode != 0) {
    throw StateError(
      '$executable ${arguments.join(' ')} failed (${result.exitCode}):\n'
      '${result.stderr}',
    );
  }
  return result.stdout as String;
}
