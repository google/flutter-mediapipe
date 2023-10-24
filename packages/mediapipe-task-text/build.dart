import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:native_assets_cli/native_assets_cli.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

const assetFilename = 'libtext_classifier.dylib';
const assetLocation =
    'https://storage.cloud.google.com/random-storage-asdf/$assetFilename';

File outputFile = File(
    '/Users/craiglabenz/Dev/git/google/flutter-mediapipe/packages/mediapipe-task-text/logs-build.txt');

final logs = <String>[];

void main(List<String> args) async {
  if (await outputFile.exists()) {
    await outputFile.delete();
  }
  await outputFile.create();

  log(args.join(' '));
  _build(args);
  outputFile.writeAsString(logs.join('\n'));
}

Future<void> _build(List<String> args) async {
  final buildConfig = await BuildConfig.fromArgs(args);
  final buildOutput = BuildOutput();
  final downloadUri = Uri.parse(assetLocation);
  final downloadFileLocation = buildConfig.outDir.resolve(assetFilename);
  log('Downloading $downloadUri');
  final downloadResponse = await http.get(downloadUri);
  final downloadedFile = File(downloadFileLocation.toFilePath());
  if (downloadResponse.statusCode == 200) {
    if (downloadedFile.existsSync()) {
      downloadedFile.deleteSync();
    }
    downloadedFile.createSync();
    downloadedFile.writeAsBytes(downloadResponse.bodyBytes);
  }
  buildOutput.dependencies.dependencies
      .add(buildConfig.packageRoot.resolve('build.dart'));
  buildOutput.assets.add(
    Asset(
      id: 'package:mediapipe_text/src/mediapipe_text_bindings.dart',
      linkMode: LinkMode.dynamic,
      target: Target.macOSArm64,
      path: AssetAbsolutePath(downloadFileLocation),
    ),
  );
  await buildOutput.writeToFile(outDir: buildConfig.outDir);
  log(buildConfig.outDir.toString());
}

void log(String val) {
  logs.add('\n[${DateTime.now().toIso8601String()}] $val\n');
}
