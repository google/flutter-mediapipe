import 'dart:io';

import 'package:mediapipe_decision/mediapipe_decision.dart';

/// Answers a yes-or-no and a choice question about a text from the command
/// line with Google's pinned Laya model:
/// `dart run example/example.dart "My order arrived broken."`.
///
/// A Dart program has no app bundle, so this downloads the model (678 MB) once
/// into `.dart_tool/mediapipe_models/`, checks its SHA-256 and passes its
/// path. A Flutter app passes `model: DecisionModels.layaS256` instead, after
/// setting `ModelStore.allowDownloads = true` or bundling the model.
Future<void> main(List<String> arguments) async {
  final store = ModelStore(
    cacheDirectory: Directory('.dart_tool/mediapipe_models').absolute.path,
  );
  final model = await store.get(DecisionModels.layaS256);
  final task = await DecisionMaker.create(
    DecisionMakerOptions(modelPath: model.path),
  );
  try {
    final text = arguments.join(' ');
    final refund = await task.evaluateBoolean(
      text,
      BooleanQuestion('The customer wants a refund.'),
    );
    final topic = await task.evaluateChoice(
      text,
      ChoiceQuestion({
        'shipping': 'A problem with delivery or a damaged package',
        'billing': 'A question about a charge or a refund',
        'other': 'Anything else',
      }),
    );
    print(
      'Wants a refund: ${refund.value} '
      '(${refund.probabilityTrue.toStringAsFixed(2)})',
    );
    print('Topic: ${topic.selectedKey}');
  } finally {
    await task.dispose();
  }
}
