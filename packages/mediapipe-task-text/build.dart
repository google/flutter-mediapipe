import 'dart:io';
import 'package:native_assets_cli/native_assets_cli.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

import 'sdk_downloads.dart';

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
  final buildConfig = await BuildConfig.fromArgs(args);
  logFile = File(
    path.joinAll([
      Directory.current.path, // root dir of app using `mediapipe-task-xyz`
      'build/${buildConfig.dryRun ? "dryrun" : "live-run"}-build-log.txt',
    ]),
  );

  log(args.join(' '));
  final String targetOs = buildConfig.targetOs.toString();
  log('targetOs: $targetOs');

  log('dir.current: ${Directory.current.absolute.path}');

  // Throw if target runtime is unsupported.
  if (!sdkDownloadUrls.containsKey(targetOs)) {
    throw Exception('Unsupported target OS: $targetOs. '
        'Supported values are: ${sdkDownloadUrls.keys.toSet()}');
  }

  final buildOutput = BuildOutput();
  buildOutput.dependencies.dependencies
      .add(buildConfig.packageRoot.resolve('build.dart'));
  buildOutput.dependencies.dependencies
      .add(buildConfig.packageRoot.resolve('sdk_downloads.dart'));

  final modelName = 'libtext';
  final Iterable<String> archKeys;
  if (buildConfig.dryRun) {
    archKeys = sdkDownloadUrls[targetOs]![modelName]!.keys;
  } else {
    archKeys = [buildConfig.targetArchitecture.toString()];
  }
  for (final String arch in archKeys) {
    final assetUrl = sdkDownloadUrls[targetOs]!['libtext']![arch]!;
    final downloadFileLocation = buildConfig.outDir.resolve(
      '${arch}_${assetUrl.split('/').last}',
    );
    log('downloadFileLocation: $downloadFileLocation');
    buildOutput.assets.add(
      Asset(
        id: 'package:mediapipe_text/src/io/third_party/mediapipe/generated/mediapipe_text_bindings.dart',
        linkMode: LinkMode.dynamic,
        target: Target.fromArchitectureAndOs(
            Architecture.fromString(arch), buildConfig.targetOs),
        path: AssetAbsolutePath(downloadFileLocation),
      ),
    );
    if (!buildConfig.dryRun) {
      downloadAsset(assetUrl, downloadFileLocation);
    }
  }

  await buildOutput.writeToFile(outDir: buildConfig.outDir);
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
