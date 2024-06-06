import 'dart:io';
import 'package:native_assets_cli/native_assets_cli.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

import '../sdk_downloads.dart';

late File logFile;

final logs = <(DateTime, String)>[];
void log(String msg) {
  logs.add((DateTime.now(), msg));
  if (!logFile.parent.existsSync()) {
    logFile.parent.createSync();
  }

  if (logFile.existsSync()) {
    logFile.deleteSync();
  }
  logFile.createSync();
  logFile.writeAsStringSync(logs
      .map<String>((rec) => '[${rec.$1.toIso8601String()}] ${rec.$2}')
      .toList()
      .join('\n\n'));
}

Future<void> main(List<String> args) async {
  await build(args, (buildConfig, buildOutput) async {
    logFile = File(
      path.joinAll([
        Directory.current.path, // root dir of app using `mediapipe-task-xyz`
        'build/${buildConfig.dryRun ? "dryrun" : "live-run"}-build-log.txt',
      ]),
    );

    log(args.join(' '));
    final String targetOs = buildConfig.targetOS.toString();

    log('dir.current: ${Directory.current.absolute.path}');

    // Throw if target runtime is unsupported.
    if (!sdkDownloadUrls.containsKey(targetOs)) {
      throw Exception('Unsupported target OS: $targetOs. '
          'Supported values are: ${sdkDownloadUrls.keys.toSet()}');
    }

    buildOutput.addDependencies([
      buildConfig.packageRoot.resolve('build.dart'),
      buildConfig.packageRoot.resolve('sdk_downloads.dart'),
    ]);

    final modelName = 'libllm_inference_engine';
    final Iterable<String> archKeys;
    if (buildConfig.dryRun) {
      archKeys = sdkDownloadUrls[targetOs]![modelName]!.keys;
    } else {
      archKeys = [buildConfig.targetArchitecture.toString()];
    }
    for (String arch in archKeys) {
      arch = getArchAlias(arch);
      log('arch: $arch');
      log('sdkDownloadUrls[$targetOs]: ${sdkDownloadUrls[targetOs]}');
      log('sdkDownloadUrls[$targetOs][$modelName]: ${sdkDownloadUrls[targetOs]![modelName]}');
      log('sdkDownloadUrls[$targetOs][$modelName][$arch]: ${sdkDownloadUrls[targetOs]![modelName]![arch]}');

      if (!sdkDownloadUrls[targetOs]!['libllm_inference_engine']!
          .containsKey(arch)) {
        continue;
      }
      final assetUrl =
          sdkDownloadUrls[targetOs]!['libllm_inference_engine']![arch]!;

      // Take last chunk and drop file extension, e.g.,
      // "path/to/file.dylib" -> "file"
      final fileName = assetUrl.split('/').last.split('.').first;

      final downloadFileLocation = buildConfig.outputDirectory.resolve(
        buildConfig.targetOS.dylibFileName(fileName),
      );
      buildOutput.addAsset(
        NativeCodeAsset(
          package: 'mediapipe_genai',
          name:
              'src/io/third_party/mediapipe/generated/mediapipe_genai_bindings.dart',
          linkMode: DynamicLoadingBundled(),
          os: buildConfig.targetOS,
          architecture: buildConfig.targetArchitecture,
          file: downloadFileLocation,
        ),
      );
      if (!buildConfig.dryRun) {
        log('downloadFileLocation: $downloadFileLocation');
        downloadAsset(assetUrl, downloadFileLocation);
      }
    }
  });
}

Future<void> downloadAsset(String assetUrl, Uri destinationFile) async {
  final downloadUri = Uri.parse(assetUrl);
  final downloadedFile = File(destinationFile.toFilePath());
  log('Saving file to ${downloadedFile.absolute.path}');

  final downloadResponse = await http.get(downloadUri);
  log('Download response: ${downloadResponse.statusCode}');

  if (downloadResponse.statusCode == 200) {
    if (downloadedFile.existsSync()) {
      downloadedFile.deleteSync();
    }
    downloadedFile.createSync();
    log('Saved file to ${downloadedFile.absolute.path}\n');
    downloadedFile.writeAsBytes(downloadResponse.bodyBytes);
  } else {
    log('${downloadResponse.statusCode} :: ${downloadResponse.body}');
    throw Exception(
        '${downloadResponse.statusCode} :: ${downloadResponse.body}');
  }
}

/// Translates native-assets architecture names into MediaPipe architecture names
String getArchAlias(String arch) =>
    <String, String>{
      'arm': 'arm64',
    }[arch] ??
    arch;
