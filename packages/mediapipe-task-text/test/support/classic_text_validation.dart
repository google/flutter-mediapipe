import 'dart:io';

import 'dart:typed_data';

import 'package:mediapipe_text/mediapipe_text.dart';

typedef _Task = (Future<Object> Function(String), Future<void> Function());

/// A model as a file path or in memory.
typedef _Model = ({String? path, Uint8List? bytes});

Future<_Task> _create(
  String name,
  _Model model,
  Map<String, dynamic> config,
) async {
  // Python's None and an absent option mean Google's default.
  final maxResults = config['max_results'] as int? ?? -1;
  final scoreThreshold = (config['score_threshold'] as num?)?.toDouble() ?? 0;
  final allow = (config['category_allowlist'] as List?)?.cast<String>();
  final deny = (config['category_denylist'] as List?)?.cast<String>();
  final locale = config['display_names_locale'] as String?;
  switch (name) {
    case 'classifier':
      final task = await TextClassifier.create(
        TextClassifierOptions(
          modelPath: model.path,
          modelBytes: model.bytes,
          displayNamesLocale: locale,
          maxResults: maxResults,
          scoreThreshold: scoreThreshold,
          categoryAllowlist: allow,
          categoryDenylist: deny,
        ),
      );
      return (task.classify, task.dispose);
    case 'language':
      final task = await LanguageDetector.create(
        LanguageDetectorOptions(
          modelPath: model.path,
          modelBytes: model.bytes,
          displayNamesLocale: locale,
          maxResults: maxResults,
          scoreThreshold: scoreThreshold,
          categoryAllowlist: allow,
          categoryDenylist: deny,
        ),
      );
      return (task.detect, task.dispose);
    case 'embedder':
      final task = await TextEmbedder.create(
        TextEmbedderOptions(
          modelPath: model.path,
          modelBytes: model.bytes,
          l2Normalize: config['l2_normalize'] == true,
          quantize: config['quantize'] == true,
        ),
      );
      return (task.embed, task.dispose);
    default:
      throw StateError('Unknown task $name');
  }
}

Object _json(Object value) => switch (value) {
  TextClassifierResult result => {
    // Google's Python converter exposes timestamp_ms=0 for non-timed text.
    'timestamp_ms': result.timestampMilliseconds ?? 0,
    'classifications': [
      for (final head in result.classifications)
        {
          'head_index': head.headIndex,
          'head_name': head.headName,
          'categories': [
            for (final c in head.categories)
              {
                'index': c.index,
                'score': c.score,
                'category_name': c.categoryName,
                'display_name': c.displayName,
              },
          ],
        },
    ],
  },
  LanguageDetectorResult result => {
    'detections': [
      for (final p in result.predictions)
        {'language_code': p.languageCode, 'probability': p.probability},
    ],
  },
  TextEmbedderResult result => {
    'timestamp_ms': result.timestampMilliseconds,
    'embeddings': [
      for (final e in result.embeddings)
        {
          'head_index': e.headIndex,
          'head_name': e.headName,
          'quantized': e.quantizedEmbedding != null,
          'values': e.quantizedEmbedding ?? e.floatEmbedding,
        },
    ],
  },
  _ => throw StateError('Unknown result $value'),
};

/// Compare every native output, including ordered metadata and all vector values.
/// Reused by package tests and real Flutter debug/release consumers.
Future<Map<String, Object>> validateClassicText(
  Map<String, String> models,
  Map<String, dynamic> reference,
) async {
  var maxError = 0.0;
  void compare(
    Object? actual,
    Object? expected,
    String context, {
    bool exact = false,
  }) {
    if (actual is Map && expected is Map) {
      if (actual.length != expected.length) {
        throw StateError('$context fields differ');
      }
      for (final key in expected.keys) {
        if (!actual.containsKey(key)) throw StateError('$context missing $key');
        compare(actual[key], expected[key], '$context.$key', exact: exact);
      }
    } else if (actual is List && expected is List) {
      if (actual.length != expected.length) {
        throw StateError('$context length differs');
      }
      for (var i = 0; i < expected.length; i++) {
        compare(actual[i], expected[i], '$context[$i]', exact: exact);
      }
    } else if (actual is num && expected is num) {
      final error = (actual - expected).abs().toDouble();
      if (!error.isFinite || error > (exact ? 0 : 1e-6)) {
        throw StateError('$context: $actual != $expected (error $error)');
      }
      if (error > maxError) maxError = error;
    } else if (actual != expected) {
      throw StateError('$context: $actual != $expected');
    }
  }

  final retained = <String, TextEmbedderResult>{};
  final cases = (reference['cases'] as List).cast<Map<String, dynamic>>();
  for (final entry in cases) {
    final name = entry['task'] as String;
    for (final memory in [false, true]) {
      final _Model source = memory
          ? (path: null, bytes: await File(models[name]!).readAsBytes())
          : (path: models[name]!, bytes: null);
      final (run, dispose) = await _create(name, source, entry['options']);
      late Object result;
      try {
        result = await run(entry['input']);
        // Native output must survive another request and task disposal without
        // first reading any of the result's nested values.
        await run('A different request.');
      } finally {
        await dispose();
        await dispose();
      }
      compare(
        _json(result),
        entry['result'],
        '${entry['task']}/${entry['name']}/$memory',
        exact: entry['options']['quantize'] == true,
      );
      if (result is TextEmbedderResult) retained[entry['name']] = result;
    }
  }
  for (final pair in reference['similarities'] as List) {
    final actual = TextEmbedder.cosineSimilarity(
      retained[pair['a']]!.embeddings.first,
      retained[pair['b']]!.embeddings.first,
    );
    compare(actual, pair['value'], 'cosine');
  }

  for (final entry in reference['creation_errors'] as List) {
    var rejected = false;
    try {
      final (_, dispose) = await _create(entry['task'], (
        path: models[entry['task']]!,
        bytes: null,
      ), entry['options']);
      await dispose();
    } on ArgumentError {
      // Options Google's runtime refuses (its message is entry['error']) are
      // refused in Dart first, the same way on every platform.
      rejected = true;
    }
    if (!rejected) throw StateError('Invalid options were accepted.');
  }

  for (final entry in models.entries) {
    final (run, dispose) = await _create(entry.key, (
      path: entry.value,
      bytes: null,
    ), {});
    try {
      final sequence = reference['lifecycle_sequences'][entry.key] as List;
      for (var i = 0; i < 2; i++) {
        compare(
          _json(await run(sequence[i]['input'])),
          sequence[i]['result'],
          '${entry.key} serial[$i]',
        );
      }
      final pending = [for (final item in sequence.skip(2)) run(item['input'])];
      final closing = dispose();
      var rejected = false;
      try {
        await run('Too late');
      } on StateError {
        rejected = true;
      }
      if (!rejected) throw StateError('Accepted a request during disposal');
      final results = await Future.wait(pending);
      await closing;
      for (var i = 0; i < results.length; i++) {
        compare(
          _json(results[i]),
          sequence[i + 2]['result'],
          '${entry.key} queue[$i]',
        );
      }
    } finally {
      await dispose();
    }
  }

  return {
    'reference_cases': cases.length,
    'model_sources': ['path', 'bytes'],
    'inference_comparisons': cases.length * 2,
    'maximum_output_error': maxError,
    'cosine_comparisons': (reference['similarities'] as List).length,
    'official_creation_errors': (reference['creation_errors'] as List).length,
    'results_owned_after_disposal': 'passed',
    'queue_and_dispose': 'passed',
  };
}
