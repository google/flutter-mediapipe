@TestOn('mac-os')
library;

import 'dart:io';

import 'package:mediapipe_retrieval/mediapipe_retrieval.dart';
import 'package:test/test.dart';

/// Google's EmbeddingGemma 2 models; `make models_retrieval` downloads them.
final _textVision =
    Platform.environment['MEDIAPIPE_RETRIEVAL_MODEL'] ??
    'models/embeddinggemma-2-text-vision-440m.litertlm';
final _audio =
    Platform.environment['MEDIAPIPE_RETRIEVAL_AUDIO_MODEL'] ??
    'models/embeddinggemma-2-740m.litertlm';

/// The most memory a Universal Embedder on a pinned model may add to this
/// process's footprint, as `footprint` reads it: what iOS limits, about 3.4 GB
/// for an app on an iPhone 15 Pro. Google's Decision Maker reserves memory for
/// its whole token budget (upstream-issues.md UP-060); this guards the
/// embedder's own budget, `maxInputLength`, the same way.
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
  for (final (name, path) in [
    ('EmbeddingGemma 2 (text and vision)', _textVision),
    ('EmbeddingGemma 2 (audio)', _audio),
  ]) {
    test(
      '$name adds at most ${(_budgetMegabytes / 1024).toStringAsFixed(1)} GB '
      'at its default input length',
      () async {
        final before = await _footprint();
        final task = await UniversalEmbedder.create(
          UniversalEmbedderOptions(modelPath: path),
        );
        try {
          await task.embedText('A shark is swimming toward the fish.');
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
