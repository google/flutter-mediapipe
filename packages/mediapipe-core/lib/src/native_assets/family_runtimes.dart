import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:code_assets/code_assets.dart';
import 'package:crypto/crypto.dart';
import 'package:hooks/hooks.dart';
import 'package:yaml/yaml.dart';

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
/// libraries: the 1.2.3 release build of November 11, 2026.
const familyRuntimeVersion = '1.2.3';

/// Google's archive of the November 11, 2026 build, where the hooks download
/// Google's libraries: each one is read from it with HTTP range requests,
/// without the rest of the archive.
///
/// `hooks.user_defines.mediapipe_core.asset_source` replaces it for offline
/// and mirrored builds: a directory or URL holding each file under its
/// SHA-256.
const familyRuntimeArchiveUrl =
    'https://storage.googleapis.com/mediapipe-assets/prebuilts/'
    'mediapipe_tasks_c/1.2.3/mediapipe_tasks_c_1.2.3.zip';

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

  /// The download: the file in Google's archive. The hook saves it as
  /// [fileName].
  DownloadAsset get asset =>
      DownloadAsset(url: '$familyRuntimeArchiveUrl#$path', sha256: sha256);
}

/// Google's per-family libraries, by family and build target.
///
/// Android has 32-bit ARM too, which Flutter's release builds include, though
/// no task claims it; browsers run Google's JavaScript runtime instead.
///
/// Every file comes from Google's release build of November 11, 2026
/// (MediaPipe 1.2.3), unmodified. iOS has one framework zip for devices and
/// one for the Simulator.
const familyRuntimes = <String, Map<String, FamilyRuntime>>{
  'vision': {
    'macos/arm64': FamilyRuntime(
      'vision/darwin_arm64/libmediapipe_tasks_vision.dylib',
      'c4e8aa50a98a9b5d4a3f7883bf0bad2c1ca8bea66474ef3e14232fe8ee716c21',
      29510000,
    ),
    'android/arm64': FamilyRuntime(
      'vision/android_arm64-v8a/libmediapipe_tasks_vision.so',
      '14c3f4daee0000be9a5f77134a4925a4213c5019433197574e80d54d5c0ad253',
      16230608,
    ),
    'android/arm': FamilyRuntime(
      'vision/android_armeabi-v7a/libmediapipe_tasks_vision.so',
      'aba6ccb66e7727fe928789361166822afbaa58820e1e1bb8e5bf618216823cf5',
      11561128,
    ),
    'android/x64': FamilyRuntime(
      'vision/android_x86_64/libmediapipe_tasks_vision.so',
      '356c2825cabafee0603fcc75b20c63e560c702308223a96df61a4dcef4c2c408',
      19969808,
    ),
    'ios/arm64': FamilyRuntime(
      'vision/ios_arm64/MediaPipeTasksVisionC.framework.zip',
      '154333f07ee233efe3966976b9abcd1dc61a997825b0d7851a97ae97181ac67e',
      8841261,
    ),
    'ios-simulator/arm64': FamilyRuntime(
      'vision/ios_simulator/MediaPipeTasksVisionC.framework.zip',
      '7990f1bc49bba3f585813a7b59ed5ecd0611f36762f970856231d11de241e359',
      19397705,
    ),
    'linux/x64': FamilyRuntime(
      'vision/linux_x86_64/libmediapipe_tasks_vision.so',
      'e86556f45ee840bc0041bb1948059288dde36ef87a41b8f474735ea011c6c216',
      34864320,
    ),
    'windows/x64': FamilyRuntime(
      'vision/windows_x86_64/mediapipe_tasks_vision.dll',
      '30b54929f350e31ee2afcac5cbea250ff7004eac9b489006b9702f4f06b6256a',
      29751296,
    ),
  },
  'text': {
    'macos/arm64': FamilyRuntime(
      'text/darwin_arm64/libmediapipe_tasks_text.dylib',
      '813546fd803762b602fa2e84f7962600e613054454140d0179e3866f899814cc',
      27232848,
    ),
    'android/arm64': FamilyRuntime(
      'text/android_arm64-v8a/libmediapipe_tasks_text.so',
      '758a2821877d56428605444c2a8c9042cd92e15969f9ebaef265bb03b9392c3d',
      16836240,
    ),
    'android/arm': FamilyRuntime(
      'text/android_armeabi-v7a/libmediapipe_tasks_text.so',
      '9a13317c75faef917f26cbeaded3dadf69c438c6d77a49fe9ee43120102af570',
      11755560,
    ),
    'android/x64': FamilyRuntime(
      'text/android_x86_64/libmediapipe_tasks_text.so',
      '4398ca6b671423ebdce892b7e9db647822898dbb5efba0e580c87964d732f54f',
      20503952,
    ),
    'ios/arm64': FamilyRuntime(
      'text/ios_arm64/MediaPipeTasksTextC.framework.zip',
      'cdd9eceb0d271efcb1bf595d4d5f2a296666e752fea4adfe7e55c060bdaf6b6e',
      8177940,
    ),
    'ios-simulator/arm64': FamilyRuntime(
      'text/ios_simulator/MediaPipeTasksTextC.framework.zip',
      'dde62195ce72d107368da6ccd13c05383220c84dee0517c8b3f6b703f930eca6',
      17763862,
    ),
    'linux/x64': FamilyRuntime(
      'text/linux_x86_64/libmediapipe_tasks_text.so',
      '1e2e2929b8c8cdb4828a41093a3e7997522e44193dae24096007d4545ead78fd',
      41813600,
    ),
    'windows/x64': FamilyRuntime(
      'text/windows_x86_64/mediapipe_tasks_text.dll',
      '8c6157d9a76b3c57ef6af872789fbcc1baf9586eab86340d318ba8ec9a64859f',
      29845504,
    ),
  },
  'audio': {
    'macos/arm64': FamilyRuntime(
      'audio/darwin_arm64/libmediapipe_tasks_audio.dylib',
      'ba65bf3521132ffa4a3800564f49a540750605ea1b9ca064f6dc82901dfdd859',
      25478576,
    ),
    'android/arm64': FamilyRuntime(
      'audio/android_arm64-v8a/libmediapipe_tasks_audio.so',
      '41ab059471409cd1d358a0112bd7c7ce75a6344e5d89454eed612be3bfa30719',
      16259600,
    ),
    'android/arm': FamilyRuntime(
      'audio/android_armeabi-v7a/libmediapipe_tasks_audio.so',
      '955080e180751d7a738bfd050f5bc4817de911f8648025b5b2b2253dc123de32',
      11448616,
    ),
    'android/x64': FamilyRuntime(
      'audio/android_x86_64/libmediapipe_tasks_audio.so',
      '193686ed9802ef66f06afb3476f0f5524a11a5fa07b2656a1003b175e078afba',
      19952144,
    ),
    'ios/arm64': FamilyRuntime(
      'audio/ios_arm64/MediaPipeTasksAudioC.framework.zip',
      '71c8dd83d9187bdec0e851c88d99547d2e450823542baa875c4a42efe8e58b9c',
      8145085,
    ),
    'ios-simulator/arm64': FamilyRuntime(
      'audio/ios_simulator/MediaPipeTasksAudioC.framework.zip',
      '69c2a9f4b42bb66a89f80b2993bf872d3fd77d1b0691a7a49ff48e4c9fb7a3d7',
      17713264,
    ),
    'linux/x64': FamilyRuntime(
      'audio/linux_x86_64/libmediapipe_tasks_audio.so',
      'c735a9d2e3062450ed54dabe5acf6fbdf427e93bc5b4f6c9219ab50cfb0b7222',
      42208240,
    ),
    'windows/x64': FamilyRuntime(
      'audio/windows_x86_64/mediapipe_tasks_audio.dll',
      'c88bede1400a75a8c2cff91f3a4d7247f969bcf376be14a5373c204c0aca7518',
      47985152,
    ),
  },
  'retrieval': {
    'macos/arm64': FamilyRuntime(
      'retrieval/darwin_arm64/libmediapipe_tasks_retrieval.dylib',
      '50e42122535d037ec8a939aa4f1b19cb79c1b87de0fe41fb5aed456e77b4aff8',
      21924064,
    ),
    'android/arm64': FamilyRuntime(
      'retrieval/android_arm64-v8a/libmediapipe_tasks_retrieval.so',
      'e72d6915517b4b83ac3793946c71607cf70a25b41871961d556cef887c9a5b37',
      14771088,
    ),
    'android/arm': FamilyRuntime(
      'retrieval/android_armeabi-v7a/libmediapipe_tasks_retrieval.so',
      'd9106404d6367391bcefa06ee04041670463d88cc49523efd2b5ec0570ebedfa',
      10447976,
    ),
    'android/x64': FamilyRuntime(
      'retrieval/android_x86_64/libmediapipe_tasks_retrieval.so',
      'd45ee7d8fe53bc6ddd46cb23e03b7adc649240494084af32175275fb5edc9c0c',
      18367504,
    ),
    'ios/arm64': FamilyRuntime(
      'retrieval/ios_arm64/MediaPipeTasksRetrievalC.framework.zip',
      'e8efb7f2864c6297c4295c1ac6839ad58d118ae164bce13c7345702aaeb00484',
      6643132,
    ),
    'ios-simulator/arm64': FamilyRuntime(
      'retrieval/ios_simulator/MediaPipeTasksRetrievalC.framework.zip',
      '94012de2c90391806b10eef36519384e73ea03747ad89ec3f5fd826ea605824e',
      14852570,
    ),
    'linux/x64': FamilyRuntime(
      'retrieval/linux_x86_64/libmediapipe_tasks_retrieval.so',
      'c9169204fd423ec71aa18de4aadf69cf9dd59fef03d641d02cc84d9cf973679f',
      32969280,
    ),
    'windows/x64': FamilyRuntime(
      'retrieval/windows_x86_64/mediapipe_tasks_retrieval.dll',
      '8e9f054fcc11421243915ae3e54984f0d0e4322c6f9ddf0a418a3cacfa039016',
      27446272,
    ),
  },
  'decision': {
    'macos/arm64': FamilyRuntime(
      'decision/darwin_arm64/libmediapipe_tasks_decision.dylib',
      'e7f01bded4cfcec19def6a1652c5e5ee6b1808558efa66a4549705e0dff8ce99',
      13585312,
    ),
    'android/arm64': FamilyRuntime(
      'decision/android_arm64-v8a/libmediapipe_tasks_decision.so',
      '572ef7a1582e080483dc67a48bfddc97f6af68e07b60ed50902b27a8920fe562',
      12826512,
    ),
    'android/arm': FamilyRuntime(
      'decision/android_armeabi-v7a/libmediapipe_tasks_decision.so',
      '114f4cd111a7115c6130ae8c36dbf5d9914b906058c19013684002f0f5c66983',
      9022760,
    ),
    'android/x64': FamilyRuntime(
      'decision/android_x86_64/libmediapipe_tasks_decision.so',
      '83eda626906925175c0a1be4bbee9a4697dfe7c7a0943d3892438d1e7463074c',
      16081104,
    ),
    'ios/arm64': FamilyRuntime(
      'decision/ios_arm64/MediaPipeTasksDecisionC.framework.zip',
      '2ff7fe44cb922c90fa775206be2ee3df2ce3e4dc64ea8d3fc3ce99c09bda635b',
      6069015,
    ),
    'ios-simulator/arm64': FamilyRuntime(
      'decision/ios_simulator/MediaPipeTasksDecisionC.framework.zip',
      'b23708cb5f5253815acc2093b6d233766fbcf707a18d0c3e972f05e76d54320a',
      13419997,
    ),
    'linux/x64': FamilyRuntime(
      'decision/linux_x86_64/libmediapipe_tasks_decision.so',
      '025438d2c7c542c8b4676da407ca3b37cc2cc56b86cd185de08ecb188ce39c25',
      36645552,
    ),
    'windows/x64': FamilyRuntime(
      'decision/windows_x86_64/mediapipe_tasks_decision.dll',
      '09ec664895ee83cf96aaf1aa875ded66370f452d516da8666886c6094d9db665',
      40359424,
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
  checkFamilyRelease(input.packageName, input.packageRoot);
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

/// The oldest release of each task family that reads this core's libraries:
/// 0.3.0 moved to MediaPipe 1.2.3, whose `MpBaseOptions` grew from 72 to 80
/// bytes, so every task's options after it moved by 8.
const _minimumFamilyRelease = (0, 3, 0);

/// Stops the build when [packageRoot] is a pub.dev release of [package]
/// older than [_minimumFamilyRelease], which would pass this core's
/// libraries options laid out for MediaPipe 1.2.2.
///
/// Only hosted releases are checked, where the version names the code. A path
/// or git checkout passes, as does a pubspec without a plain version.
///
/// The error names core's version from the pubspec in [coreRoot], by default
/// where `package:mediapipe_core/` resolves in the running hook.
void checkFamilyRelease(String package, Uri packageRoot, {Uri? coreRoot}) {
  final segments = packageRoot.pathSegments.where((s) => s.isNotEmpty);
  final found = _pubspecVersion(packageRoot);
  if (found == null ||
      segments.length < 3 ||
      segments.elementAt(segments.length - 3) != 'hosted' ||
      segments.last != '$package-$found') {
    return;
  }
  final release = _release(found);
  if (release == null || _compare(release, _minimumFamilyRelease) >= 0) {
    return;
  }
  final (major, minor, patch) = _minimumFamilyRelease;
  final minimum = '$major.$minor.$patch';
  final core = switch (coreRoot ?? _coreLibrary()?.resolve('../')) {
    final root? => _pubspecVersion(root),
    null => null,
  };
  throw UnsupportedError(
    '$package $found does not work with '
    '${core == null ? 'this mediapipe_core' : 'mediapipe_core $core'}, which '
    "bundles Google's MediaPipe $familyRuntimeVersion: the task options "
    'changed layout there, and $package reads the new layout from $minimum. '
    'Upgrade $package to $minimum or later (flutter pub upgrade $package).',
  );
}

/// Where `package:mediapipe_core/` resolves in the running hook, or null.
Uri? _coreLibrary() {
  try {
    return Isolate.resolvePackageUriSync(Uri.parse('package:mediapipe_core/'));
  } on Object {
    return null;
  }
}

/// The `version:` of the pubspec in [root], or null.
String? _pubspecVersion(Uri root) {
  final pubspec = File.fromUri(root.resolve('pubspec.yaml'));
  if (!pubspec.existsSync()) return null;
  try {
    final version = (loadYaml(pubspec.readAsStringSync()) as Map)['version'];
    return version is String ? version : null;
  } on Object {
    return null;
  }
}

/// [version]'s major, minor and patch, ignoring any pre-release or build
/// suffix, or null when it is not a plain version.
(int, int, int)? _release(String version) {
  final match = RegExp(r'^(\d+)\.(\d+)\.(\d+)(?:[-+].*)?$').firstMatch(version);
  if (match == null) return null;
  return (int.parse(match[1]!), int.parse(match[2]!), int.parse(match[3]!));
}

int _compare((int, int, int) a, (int, int, int) b) => a.$1 != b.$1
    ? a.$1.compareTo(b.$1)
    : a.$2 != b.$2
    ? a.$2.compareTo(b.$2)
    : a.$3.compareTo(b.$3);

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
