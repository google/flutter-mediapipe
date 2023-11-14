import 'dart:io';
import 'package:native_assets_cli/native_assets_cli.dart';
import 'package:http/http.dart' as http;

const cloudAssetFilename = 'libtext_classifier-v0.0.5.dylib';
const localAssetFilename = 'libtext_classifier.dylib';
const assetLocation =
    'https://storage.googleapis.com/random-storage-asdf/$cloudAssetFilename';

Future<void> main(List<String> args) async {
  final buildConfig = await BuildConfig.fromArgs(args);
  final buildOutput = BuildOutput();
  final downloadFileLocation = buildConfig.outDir.resolve(localAssetFilename);
  if (!buildConfig.dryRun) {
    final downloadUri = Uri.parse(assetLocation);
    final downloadResponse = await http.get(downloadUri);
    final downloadedFile = File(downloadFileLocation.toFilePath());
    if (downloadResponse.statusCode == 200) {
      if (downloadedFile.existsSync()) {
        downloadedFile.deleteSync();
      }
      downloadedFile.createSync();
      downloadedFile.writeAsBytes(downloadResponse.bodyBytes);
    } else {
      throw Exception(
          '${downloadResponse.statusCode} :: ${downloadResponse.body}');
    }
  }
  buildOutput.dependencies.dependencies
      .add(buildConfig.packageRoot.resolve('build.dart'));
  buildOutput.assets.add(
    Asset(
      // What should this `id` be?
      id: 'package:mediapipe_text/src/mediapipe_text_bindings.dart',
      linkMode: LinkMode.dynamic,
      target: Target.macOSArm64,
      path: AssetAbsolutePath(downloadFileLocation),
    ),
  );
  await buildOutput.writeToFile(outDir: buildConfig.outDir);
}
