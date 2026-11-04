import 'dart:io';

import 'package:mediapipe_core/native_assets.dart';
import 'package:mediapipe_text/mediapipe_text.dart';

/// Downloads Google's pinned text models into `models/`, each verified
/// against its SHA-256 and saved under Google's file name: the names given,
/// from `TextModels.byName`, or the three classic models the tests run (EmbeddingGemma, the
/// Proofreader and the Summarizer are 118 to 184 MB each).
Future<void> main(List<String> names) async {
  for (final name
      in names.isEmpty
          ? const [
              'bert_classifier',
              'universal_sentence_encoder',
              'language_detector',
            ]
          : names) {
    final model = TextModels.byName[name];
    if (model == null) {
      stderr.writeln(
        'No text model is named $name. TextModels.byName has '
        '${TextModels.byName.keys.join(', ')}.',
      );
      exitCode = 64;
      return;
    }
    final target = File('models/${Uri.parse(model.url).pathSegments.last}');
    await downloadVerified(model, target);
    stdout.writeln('Verified ${target.path}');
  }
}
