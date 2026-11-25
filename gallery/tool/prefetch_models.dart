import 'dart:io';

import 'package:mediapipe_audio/mediapipe_audio.dart';
import 'package:mediapipe_decision/models.dart';
import 'package:mediapipe_retrieval/models.dart';

/// Downloads models into a model store folder ahead of the gallery. CI runs
/// it in the background on the gallery's own store while the suites before
/// the journey run (tool/test_desktop.py): the app then finds each model, or
/// waits for the one still downloading, since the store claims each model
/// across processes.
///
///     dart run tool/prefetch_models.dart <store folder> <model name>...
///
/// A model name is one a family's `byName` lists, such as `laya_s256`.
Future<void> main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln(
      'Usage: dart run tool/prefetch_models.dart <store folder> <model name>...',
    );
    exit(64);
  }
  final models = {
    ...AudioModels.byName,
    ...DecisionModels.byName,
    ...RetrievalModels.byName,
  };
  final store = ModelStore(cacheDirectory: args.first);
  // Past `dart run`'s build hooks, which test_desktop.py waits for.
  stdout.writeln('MODEL_PREFETCH started');
  for (final name in args.skip(1)) {
    final model = models[name];
    if (model == null) {
      stderr.writeln('No family lists a model named $name.');
      exit(64);
    }
    final clock = Stopwatch()..start();
    await store.prefetch(model);
    // The store's folder for the model, which test_desktop.py tells apart
    // from the folders the app writes.
    stdout.writeln(
      'MODEL_PREFETCH $name: ${model.sha256.substring(0, 16)} in '
      '${clock.elapsed.inSeconds} s',
    );
  }
}
