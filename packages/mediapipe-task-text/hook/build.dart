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
    final String targetOS = buildConfig.targetOS.toString();
    log('targetOS: $targetOS');

    log('dir.current: ${Directory.current.absolute.path}');

    // Throw if target runtime is unsupported.
    if (!sdkDownloadUrls.containsKey(targetOS)) {
      throw Exception('Unsupported target OS: $targetOS. '
          'Supported values are: ${sdkDownloadUrls.keys.toSet()}');
    }

    buildOutput.addDependencies([
      buildConfig.packageRoot.resolve('build.dart'),
      buildConfig.packageRoot.resolve('sdk_downloads.dart'),
    ]);

    final downloadFileLocation = buildConfig.outputDirectory.resolve(
      buildConfig.targetOS.dylibFileName('text'),
    );
    buildOutput.addAsset(
      NativeCodeAsset(
        package: 'mediapipe_text',
        name:
            'src/io/third_party/mediapipe/generated/mediapipe_text_bindings.dart',
        linkMode: DynamicLoadingBundled(),
        os: buildConfig.targetOS,
        architecture: buildConfig.targetArchitecture,
        file: downloadFileLocation,
      ),
    );
    if (!buildConfig.dryRun) {
      log('downloadFileLocation: $downloadFileLocation');
      final arch = buildConfig.targetArchitecture.toString();
      final assetUrl = sdkDownloadUrls[targetOS]!['libtext']![arch]!;
      downloadAsset(assetUrl, downloadFileLocation);
    }
  });
}

Future<void> downloadAsset(String assetUrl, Uri destinationFile) async {
  final downloadUri = Uri.parse(assetUrl);
  final downloadedFile = File(destinationFile.toFilePath());

  log('Downloading file from $downloadUri');

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
