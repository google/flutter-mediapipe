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
/// libraries: the 1.2.2 release build of November 2, 2026.
const familyRuntimeVersion = '1.2.2';

/// Google's archive of the November 2, 2026 build, where the hooks download
/// Google's libraries: each one is read from it with HTTP range requests,
/// without the rest of the archive.
///
/// `hooks.user_defines.mediapipe_core.asset_source` replaces it for offline
/// and mirrored builds: a directory or URL holding each file under its
/// SHA-256.
const familyRuntimeArchiveUrl =
    'https://storage.googleapis.com/mediapipe-assets/prebuilts/'
    'mediapipe_tasks_c/1.2.2/mediapipe_tasks_c_1.2.2.zip';

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
/// Every file comes from Google's release build of November 2, 2026
/// (MediaPipe 1.2.2), unmodified. iOS has one framework zip for devices and
/// one for the Simulator.
const familyRuntimes = <String, Map<String, FamilyRuntime>>{
  'vision': {
    'macos/arm64': FamilyRuntime(
      'vision/darwin_arm64/libmediapipe_tasks_vision.dylib',
      '73946d16db97575461b90eab08cffc542d93ef224786f89b8fa24e46ddf92d4c',
      30745008,
    ),
    'android/arm64': FamilyRuntime(
      'vision/android_arm64-v8a/libmediapipe_tasks_vision.so',
      '0576d27b04b587fbf33d6ae2ecdb13271aca3aa0c062f02e8e003e4460ce1591',
      16041120,
    ),
    'android/arm': FamilyRuntime(
      'vision/android_armeabi-v7a/libmediapipe_tasks_vision.so',
      'de6c5795ed8e684780f4923402fcc437a22457f1396a506d33a59e7ede76392c',
      11409968,
    ),
    'android/x64': FamilyRuntime(
      'vision/android_x86_64/libmediapipe_tasks_vision.so',
      'fe5bad377d07419c64017b2e9bdd06ee05dcd21c3a6164880eb7ee2f2ee55f37',
      19747440,
    ),
    'ios/arm64': FamilyRuntime(
      'vision/ios_arm64/MediaPipeTasksVisionC.framework.zip',
      '393c03da3bef7506201fe366b2f4d954c6ccc814f57d73683726b95ab76bed95',
      9044032,
    ),
    'ios-simulator/arm64': FamilyRuntime(
      'vision/ios_simulator/MediaPipeTasksVisionC.framework.zip',
      '5a03157f7210ffc7063997e33b0cf0353d77cec91f7bdfe0b219b04871083d49',
      19812658,
    ),
    'linux/x64': FamilyRuntime(
      'vision/linux_x86_64/libmediapipe_tasks_vision.so',
      'b3b67a46755f9bdb1214809d3ef438ab9dfdb1b0003623c72fd0c34f3fdef32c',
      34566656,
    ),
    'windows/x64': FamilyRuntime(
      'vision/windows_x86_64/mediapipe_tasks_vision.dll',
      'f447909df12eb2fc7870a1f7b2ce0de64f492b65f328ea218b740a75cae97ce5',
      29488128,
    ),
  },
  'text': {
    'macos/arm64': FamilyRuntime(
      'text/darwin_arm64/libmediapipe_tasks_text.dylib',
      '4d8c6855a7467d8186c4c8d50907c60aac6f95b43fe322e597789b9bb6a0372f',
      28369040,
    ),
    'android/arm64': FamilyRuntime(
      'text/android_arm64-v8a/libmediapipe_tasks_text.so',
      '27a61a341db494c4404070f5c97830a0d68b142645b2cc55acb72b5cc18b970f',
      16551600,
    ),
    'android/arm': FamilyRuntime(
      'text/android_armeabi-v7a/libmediapipe_tasks_text.so',
      'a6bc21af8bbecbeb97e0adf4634a230f0de5424b21c5b02288c48311f509da0d',
      11517416,
    ),
    'android/x64': FamilyRuntime(
      'text/android_x86_64/libmediapipe_tasks_text.so',
      'f2f82908a62e38c458bf623e9bfac197d1de0f647dbb87ac145d4e114a43f217',
      20153680,
    ),
    'ios/arm64': FamilyRuntime(
      'text/ios_arm64/MediaPipeTasksTextC.framework.zip',
      '0b2b4ff02b1fcd9380a56c5874c98ac55d1368a4baca3b1eebe2c51df79bd5fa',
      8363481,
    ),
    'ios-simulator/arm64': FamilyRuntime(
      'text/ios_simulator/MediaPipeTasksTextC.framework.zip',
      'b7de6465b17df97a8631cc66a1a07b0228e8d0486e7b4e383c447f9542070203',
      18157220,
    ),
    'linux/x64': FamilyRuntime(
      'text/linux_x86_64/libmediapipe_tasks_text.so',
      'f7403d856bbc6e719df0c5611f1e8a8e92dbdf16701e9ae7c31cd4b893269a18',
      41561568,
    ),
    'windows/x64': FamilyRuntime(
      'text/windows_x86_64/mediapipe_tasks_text.dll',
      'a86d0836c7290d76e52281c71adaea9ea3a1e6a8d71aaf7a0b0d91359f8ee5ee',
      42351104,
    ),
  },
  'audio': {
    'macos/arm64': FamilyRuntime(
      'audio/darwin_arm64/libmediapipe_tasks_audio.dylib',
      'ed64b1fa1537d72b6a5273bf5fdc2b5b985b42c3a77c7c0002685502b35d3825',
      26251120,
    ),
    'android/arm64': FamilyRuntime(
      'audio/android_arm64-v8a/libmediapipe_tasks_audio.so',
      '23e3c76ecdc841764cbbe887dff6e76c510959e97d7d3441bbe0bb68bce0d680',
      15890080,
    ),
    'android/arm': FamilyRuntime(
      'audio/android_armeabi-v7a/libmediapipe_tasks_audio.so',
      '8007fb5448109a7e4a874125f53f9fb254c7992162cf52b2e554e611f8adc8f5',
      11163784,
    ),
    'android/x64': FamilyRuntime(
      'audio/android_x86_64/libmediapipe_tasks_audio.so',
      '63d6d144469f5d50a0190ec4be54e7362cb0f95fca25428ca9fdb500453838be',
      19517176,
    ),
    'ios/arm64': FamilyRuntime(
      'audio/ios_arm64/MediaPipeTasksAudioC.framework.zip',
      '54e98bd406fabb5320c0728ce2bdfd110a6e271a10d6199aa231b261d7a1991a',
      8274510,
    ),
    'ios-simulator/arm64': FamilyRuntime(
      'audio/ios_simulator/MediaPipeTasksAudioC.framework.zip',
      'a1dc3dd1ed0db1a6a73f6d23d494ea2b3e7796e793b484007b860c1c8de551b2',
      17993408,
    ),
    'linux/x64': FamilyRuntime(
      'audio/linux_x86_64/libmediapipe_tasks_audio.so',
      '81fd4c0be47d589005c9b2b0c7477115ec4bfd682505178d4b8810146c1b61df',
      41752336,
    ),
    'windows/x64': FamilyRuntime(
      'audio/windows_x86_64/mediapipe_tasks_audio.dll',
      'e146a9c732229f521d836ed310024e766276be91b7529b260d0db8d1c0d88f00',
      47221248,
    ),
  },
  'retrieval': {
    'macos/arm64': FamilyRuntime(
      'retrieval/darwin_arm64/libmediapipe_tasks_retrieval.dylib',
      '3e6b06b542cd32ecd629e929da56dfdc379424fbaba18f26ebf780f0347915de',
      23291120,
    ),
    'android/arm64': FamilyRuntime(
      'retrieval/android_arm64-v8a/libmediapipe_tasks_retrieval.so',
      'f244e6a9196cd875fe6022d0d94d3b409d1b1522623a4dd9900bc73213bd52b6',
      14586672,
    ),
    'android/arm': FamilyRuntime(
      'retrieval/android_armeabi-v7a/libmediapipe_tasks_retrieval.so',
      '990f962059634c7cde2f31080e49595233dc382192ebc8c314962523c0f05602',
      10297192,
    ),
    'android/x64': FamilyRuntime(
      'retrieval/android_x86_64/libmediapipe_tasks_retrieval.so',
      '2f7e32853e3052875d67cd11f9cbb4a27964db798518a122c8a6896a3fc09400',
      18150360,
    ),
    'ios/arm64': FamilyRuntime(
      'retrieval/ios_arm64/MediaPipeTasksRetrievalC.framework.zip',
      '880bd84b38cb6badcf92094028fca5fa581327ca9be347ee6f5f1ed78fdc8c18',
      6874315,
    ),
    'ios-simulator/arm64': FamilyRuntime(
      'retrieval/ios_simulator/MediaPipeTasksRetrievalC.framework.zip',
      '65ae47ea7c5d9b3a124c14d5d9e0117c884847f45044b06e03975fc468274a95',
      15342167,
    ),
    'linux/x64': FamilyRuntime(
      'retrieval/linux_x86_64/libmediapipe_tasks_retrieval.so',
      '35d6b01347e13e6f9f2abb6c6abfe8ae0f0eb18045f03f7632d9512e58280eb3',
      32644448,
    ),
    'windows/x64': FamilyRuntime(
      'retrieval/windows_x86_64/mediapipe_tasks_retrieval.dll',
      'e49233468f3bfe4dd5c53a33a7e36d5264bf6ccd930d5ae1338d284fb0a967d5',
      27155456,
    ),
  },
  'decision': {
    'macos/arm64': FamilyRuntime(
      'decision/darwin_arm64/libmediapipe_tasks_decision.dylib',
      '6c5b8022d3188e663e663af28e4b5ab488bb10f6e8986f8d1f71c2c943b3af1d',
      14905568,
    ),
    'android/arm64': FamilyRuntime(
      'decision/android_arm64-v8a/libmediapipe_tasks_decision.so',
      'ea0aae8db9654e291421a7e7b37664c36f3a78ca1fc0f89202687d4732dbd6b1',
      12557784,
    ),
    'android/arm': FamilyRuntime(
      'decision/android_armeabi-v7a/libmediapipe_tasks_decision.so',
      'dcb4521d0209078b9ce55c43e796431201d10882ba2ca756dbf82270725aca2d',
      8805944,
    ),
    'android/x64': FamilyRuntime(
      'decision/android_x86_64/libmediapipe_tasks_decision.so',
      '32cffefd8a963ed756cdf4d5b115d3230f3684fc3dd7fa795128083b71b8e458',
      15779704,
    ),
    'ios/arm64': FamilyRuntime(
      'decision/ios_arm64/MediaPipeTasksDecisionC.framework.zip',
      '2a35c3d5b73d65a2d002c5e4a11a024aa7870b472e822512b6796477f55eaee8',
      6281274,
    ),
    'ios-simulator/arm64': FamilyRuntime(
      'decision/ios_simulator/MediaPipeTasksDecisionC.framework.zip',
      '8335a498357c9f8d4c4e069513d1ece4fc859bf489ef21f1a8a82f7873df9202',
      13865616,
    ),
    'linux/x64': FamilyRuntime(
      'decision/linux_x86_64/libmediapipe_tasks_decision.so',
      '0a8d12383450feb6b5bbdb594a661380ee11dcf216dea9cac243c93226837c8d',
      36265776,
    ),
    'windows/x64': FamilyRuntime(
      'decision/windows_x86_64/mediapipe_tasks_decision.dll',
      '3b8d737d9cc71cb97aca22916cdb9b1d8d568b61f778689a3ca55598a1d0593d',
      39974400,
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
