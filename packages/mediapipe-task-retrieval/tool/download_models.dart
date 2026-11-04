import 'dart:io';

import 'package:mediapipe_core/native_assets.dart';
import 'package:mediapipe_retrieval/mediapipe_retrieval.dart';

/// Downloads Google's pinned retrieval models into `models/`, each verified
/// against its SHA-256 and saved under Google's file name: the names given,
/// from `RetrievalModels.byName`, or every model.
Future<void> main(List<String> names) async {
  for (final name in names.isEmpty ? RetrievalModels.byName.keys : names) {
    final model = RetrievalModels.byName[name];
    if (model == null) {
      stderr.writeln(
        'No retrieval model is named $name. RetrievalModels.byName has '
        '${RetrievalModels.byName.keys.join(', ')}.',
      );
      exitCode = 64;
      return;
    }
    final target = File('models/${Uri.parse(model.url).pathSegments.last}');
    await downloadVerified(model, target);
    stdout.writeln('Verified ${target.path}');
  }
}
