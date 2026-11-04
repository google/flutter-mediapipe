import 'dart:io';

import 'package:mediapipe_core/native_assets.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';

/// Downloads Google's pinned vision models into `models/`, each verified
/// against its SHA-256 and saved under Google's file name: the names given,
/// from `VisionModels.byName`, or every model.
Future<void> main(List<String> names) async {
  for (final name in names.isEmpty ? VisionModels.byName.keys : names) {
    final model = VisionModels.byName[name];
    if (model == null) {
      stderr.writeln(
        'No vision model is named $name. VisionModels.byName has '
        '${VisionModels.byName.keys.join(', ')}.',
      );
      exitCode = 64;
      return;
    }
    final target = File('models/${Uri.parse(model.url).pathSegments.last}');
    await downloadVerified(model, target);
    stdout.writeln('Verified ${target.path}');
  }
}
