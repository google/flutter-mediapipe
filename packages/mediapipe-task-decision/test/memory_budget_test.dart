@TestOn('mac-os')
library;

import 'dart:io';

import 'package:mediapipe_decision/mediapipe_decision.dart';
import 'package:test/test.dart';

/// Google's Laya model; `make models_decision` downloads it.
final _laya =
    Platform.environment['MEDIAPIPE_DECISION_MODEL'] ?? 'models/laya_s256.task';

/// Google's text and vision EmbeddingGemma 2, when downloaded or given:
/// `dart tool/download_models.dart embedding_gemma_2_text_vision`.
final _gemma =
    Platform.environment['MEDIAPIPE_DECISION_EG2_MODEL'] ??
    'models/embeddinggemma-2-text-vision-440m.litertlm';

/// The most memory a Decision Maker on a pinned model may add to this
/// process's footprint, as `footprint` reads it: what iOS limits, about 3.4 GB
/// for an app on an iPhone 15 Pro. Google's engine reserves memory for the
/// whole token budget when the task is created, 6.7 GB with EmbeddingGemma 2
/// at 4096 tokens (upstream-issues.md UP-060); at the model's own budget each
/// model takes about 0.7 GB.
const _budgetMegabytes = 1536;

/// This process's footprint in megabytes, from macOS's `footprint` tool.
Future<double> _footprint() async {
  final result = await Process.run('footprint', ['-p', '$pid']);
  final match = RegExp(
    r'Footprint: ([\d.]+) ([KMG])B',
  ).firstMatch('${result.stdout}');
  if (match == null) fail('footprint printed no total: ${result.stdout}');
  final value = double.parse(match[1]!);
  return switch (match[2]) {
    'K' => value / 1024,
    'G' => value * 1024,
    _ => value,
  };
}

void main() {
  for (final (name, path) in [('Laya', _laya), ('EmbeddingGemma 2', _gemma)]) {
    test(
      '$name adds at most ${(_budgetMegabytes / 1024).toStringAsFixed(1)} GB '
      'at its default token budget',
      () async {
        final before = await _footprint();
        final task = await DecisionMaker.create(
          DecisionMakerOptions(modelPath: path),
        );
        try {
          await task.evaluateChoice(
            'A shark is swimming toward the fish.',
            ChoiceQuestion({
              'chase': 'prey nearby',
              'flee': 'a predator nearby',
            }, instructions: 'What should the fish do?'),
          );
          final added = await _footprint() - before;
          print('MEMORY_BUDGET $name: ${added.round()} MB');
          expect(added, lessThan(_budgetMegabytes));
        } finally {
          await task.dispose();
        }
      },
      skip: File(path).existsSync() ? null : 'No $name model at $path.',
      timeout: const Timeout(Duration(minutes: 5)),
    );
  }
}
