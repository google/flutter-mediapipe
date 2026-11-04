import 'dart:io';

import 'package:mediapipe_core/native_assets.dart';
import 'package:mediapipe_audio/mediapipe_audio.dart';

/// Downloads Google's pinned audio models into `models/`, each verified
/// against its SHA-256 and saved under Google's file name: the names given,
/// from `AudioModels.byName`, or every model.
Future<void> main(List<String> names) async {
  for (final name in names.isEmpty ? AudioModels.byName.keys : names) {
    final model = AudioModels.byName[name];
    if (model == null) {
      stderr.writeln(
        'No audio model is named $name. AudioModels.byName has '
        '${AudioModels.byName.keys.join(', ')}.',
      );
      exitCode = 64;
      return;
    }
    final target = File('models/${Uri.parse(model.url).pathSegments.last}');
    await downloadVerified(model, target);
    stdout.writeln('Verified ${target.path}');
  }
}
