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
  logFile = File(
    path.joinAll([
      Directory.current.path, // root dir of app using `mediapipe-task-xyz`
      'build/${DateTime.now().millisecondsSinceEpoch}-build-log.txt',
    ]),
  );

  log(args.join(' '));
  final buildConfig = await BuildConfig.fromArgs(args);
  final String targetOs = buildConfig.targetOs.toString();

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

  final archKeys = sdkDownloadUrls[targetOs]!.keys;
  for (final String arch in archKeys) {
    final assetUrl = sdkDownloadUrls[targetOs]![arch]!;
    final downloadFileLocation =
        buildConfig.outDir.resolve('${arch}_${assetUrl.split('/').last}',);
    log('downloadFileLocation: $downloadFileLocation');
    buildOutput.assets.add(
      Asset(
        id: 'package:mediapipe_text/src/third_party/mediapipe/generated/mediapipe_text_bindings.dart',
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
  print('Saving file to ${downloadedFile.absolute.path}');

  final downloadResponse = await http.get(downloadUri);
  log('Download response: ${downloadResponse.statusCode}');

  if (downloadResponse.statusCode == 200) {
    if (downloadedFile.existsSync()) {
      downloadedFile.deleteSync();
    }
    downloadedFile.createSync();
    log('Saving file to ${downloadedFile.absolute.path}');
    downloadedFile.writeAsBytes(downloadResponse.bodyBytes);
  } else {
    log('${downloadResponse.statusCode} :: ${downloadResponse.body}');
    throw Exception(
        '${downloadResponse.statusCode} :: ${downloadResponse.body}');
  }
}
