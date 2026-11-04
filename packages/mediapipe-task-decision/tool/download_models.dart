import 'dart:io';

import 'package:mediapipe_core/native_assets.dart';
import 'package:mediapipe_decision/mediapipe_decision.dart';

/// Downloads Google's pinned decision models into `models/`, each verified
/// against its SHA-256 and saved under Google's file name: the names given,
/// from `DecisionModels.byName`, or Laya S256, the 678 MB model the native tests run.
Future<void> main(List<String> names) async {
  for (final name in names.isEmpty ? const ['laya_s256'] : names) {
    final model = DecisionModels.byName[name];
    if (model == null) {
      stderr.writeln(
        'No decision model is named $name. DecisionModels.byName has '
        '${DecisionModels.byName.keys.join(', ')}.',
      );
      exitCode = 64;
      return;
    }
    final target = File('models/${Uri.parse(model.url).pathSegments.last}');
    await downloadVerified(model, target);
    stdout.writeln('Verified ${target.path}');
  }
}
