import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:mediapipe_core/src/native_assets/reference_wheels.dart';
import 'package:mediapipe_text/mediapipe_text.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';

typedef Json = Map<String, dynamic>;
late Directory repo;
late List<Json> cases;
final report = <String, dynamic>{};

Future<void> main(List<String> args) async {
  String option(String name, String fallback) {
    final index = args.indexOf(name);
    return index < 0 ? fallback : args[index + 1];
  }

  repo = Directory(option('--repo', '../..')).absolute;
  final output = File(
    option('--output', '${repo.path}/build/task-benchmarks/report.json'),
  );
  final iterations = int.parse(option('--iterations', '100'));
  final reloads = int.parse(option('--reloads', '10'));
  if (iterations < 1 || reloads < 1) {
    throw ArgumentError('Counts must be positive.');
  }
  final reference = File(
    '${repo.path}/tool/task_benchmarks/fixtures/options-reference.json.gz',
  );
  final payload = gzip.decode(await reference.readAsBytes());
  final golden = jsonDecode(utf8.decode(payload)) as Json;
  cases = (golden['cases'] as List).cast<Json>();
  // Google's macOS reference wheel, the release the family libraries come from.
  final runtime = referenceWheel('macos/arm64')!.version;
  report.addAll({
    'started_utc': DateTime.now().toUtc().toIso8601String(),
    'runtime': runtime,
    'dart': Platform.version,
    'execution':
        Platform.executable.endsWith('dartaotruntime') ||
            !Platform.script.path.endsWith('.dart')
        ? 'AOT'
        : 'JIT',
    'reference_sha256': sha256.convert(payload).toString(),
    'iterations': iterations,
    'reloads': reloads,
    'warmups': 3,
    'note':
        'Wall-clock public API latency including worker messaging and result copies. '
        'RSS is process-wide and includes allocators, model maps and Dart GC; growth is not itself proof of a leak.',
    'status': 'running',
  });
  try {
    check(golden['runtime'] == runtime, 'Wrong reference runtime');
    for (final entry in (golden['models'] as Json).entries) {
      final actual = await sha256.bind(File(model(entry.key)).openRead()).first;
      check(actual.toString() == entry.value, 'Model hash: ${entry.key}');
    }
    final capabilities = await queryTextEmbedderCapabilities(
      TextModels.embeddingGemma,
    );
    check(
      capabilities.supportedDelegates.contains(Delegate.cpu),
      'Unsupported process platform',
    );
    report['platform'] = {
      'os': capabilities.platform.operatingSystem,
      'version': capabilities.platform.version,
      'architecture': capabilities.platform.architecture,
    };
    if (!args.contains('--validate-only')) await benchmark(iterations, reloads);
    if (!args.contains('--skip-validation')) {
      await validateOptions();
      await validateCaches();
      await validateGpuRejection();
    }
    report['status'] = 'passed';
  } catch (error, stack) {
    report['status'] = 'failed';
    report['error'] = '$error';
    stderr.writeln('$error\n$stack');
    exitCode = 1;
  } finally {
    report['finished_utc'] = DateTime.now().toUtc().toIso8601String();
    await output.parent.create(recursive: true);
    await output.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(report)}\n',
    );
    stdout.writeln('TASK_REPORT ${output.path}: ${report['status']}');
  }
}

String model(String kind) =>
    '${repo.path}/packages/${kind == 'segmenter' ? 'mediapipe-task-vision' : 'mediapipe-task-text'}/models/${switch (kind) {
      'embedding' => 'embedding_gemma.task',
      'proofreader' => 'proofread_quant_200m.litertlm',
      'summarizer' => 'summarization_quant_200m_2modes.litertlm',
      'segmenter' => 'interactive_segmentation.task',
      _ => throw ArgumentError(kind),
    }}';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

void compare(Object? actual, Object? expected, String label) {
  if (actual is num && expected is num) {
    check(
      actual.isFinite && (actual - expected).abs() <= 1e-6,
      '$label: $actual != $expected',
    );
  } else if (actual is List && expected is List) {
    check(actual.length == expected.length, '$label length');
    for (var i = 0; i < actual.length; i++) {
      final a = actual[i];
      final b = expected[i];
      if (a is num && b is num) {
        if (!a.isFinite || (a - b).abs() > 1e-6) {
          throw StateError('$label[$i]: $a != $b');
        }
      } else {
        compare(a, b, '$label[$i]');
      }
    }
  } else if (actual is Map && expected is Map) {
    check(actual.length == expected.length, '$label keys');
    for (final key in expected.keys) {
      check(actual.containsKey(key), '$label missing $key');
      compare(actual[key], expected[key], '$label.$key');
    }
  } else {
    check(actual == expected, '$label: $actual != $expected');
  }
}

/// Google's long key-point summaries are not reproducible: its macOS wheel
/// wrote three or four different summaries for each of these requests across
/// three runs, and its C library's varied from run to run too, all alike for at
/// least their first 98 characters (upstream-issues.md UP-036). Those cases
/// must follow Google's text from the start, as the text package requires
/// where it cannot replay Google's requests, and the report records whether
/// they matched exactly; every other case must match exactly.
bool unreproducible(Json entry) =>
    entry['task'] == 'summarizer' &&
    entry['name'] == 'long' &&
    entry['options']['mode'] == 'KEYPOINTS';

/// Requires [actual] to match [expected] for its first 80 characters, or in
/// full when [expected] is shorter.
void follows(Object? actual, Object? expected, String label) {
  final a = expected as String;
  final b = actual as String? ?? '';
  var prefix = 0;
  while (prefix < a.length && prefix < b.length && a[prefix] == b[prefix]) {
    prefix++;
  }
  check(
    prefix >= (a.length < 80 ? a.length : 80),
    '$label: $actual does not follow $expected',
  );
}

final class Loaded {
  Loaded(this.run, this.dispose);
  final Future<Object?> Function(Json entry, bool streaming) run;
  final Future<void> Function() dispose;
}

Future<Loaded> load(Json entry, {String? cache}) async {
  final kind = entry['task'] as String;
  final options = entry['options'] as Json;
  switch (kind) {
    case 'embedding':
      final task = await TextEmbedder.create(
        TextEmbedderOptions(
          modelPath: model(kind),
          l2Normalize: options['normalize'],
          quantize: options['quantize'],
        ),
      );
      return Loaded((entry, _) async {
        final context = entry['context'] as Json?;
        final result = await task.embed(
          entry['input'],
          formatContext: context == null
              ? null
              : TextFormatContext(
                  taskType: EmbeddingType.values.firstWhere(
                    (value) =>
                        value.name
                            .replaceAll(RegExp('[^a-zA-Z]'), '')
                            .toLowerCase() ==
                        (context['task_type'] as String)
                            .replaceAll('_', '')
                            .toLowerCase(),
                  ),
                  role: TextRole.values.byName(
                    (context['role'] as String).toLowerCase(),
                  ),
                  title: context['title'],
                ),
        );
        final embedding = result.embeddings.single;
        return embedding.floatEmbedding?.toList() ??
            embedding.quantizedEmbedding!.toList();
      }, task.dispose);
    case 'proofreader':
      final task = await TextProofreader.create(
        TextProofreaderOptions(
          modelPath: model(kind),
          maxNumTokens: options['budget'],
          cacheDirectory: cache,
        ),
      );
      return Loaded((entry, streaming) async {
        String? text;
        List<ProofreadingCorrection> corrections;
        if (streaming) {
          final updates = await task.proofreadStream(entry['input']).toList();
          check(
            updates.where((u) => u.done).length == 1 && updates.last.done,
            'Proofreader terminal callback',
          );
          text = updates.map((u) => u.chunk ?? '').join();
          corrections = updates.last.corrections;
        } else {
          final result = await task.proofread(entry['input']);
          text = result.proofreadText;
          corrections = result.corrections;
        }
        return {
          'text': text,
          'corrections': [
            for (final c in corrections) {'type': c.type.name, 'text': c.text},
          ],
        };
      }, task.dispose);
    case 'summarizer':
      final task = await TextSummarizer.create(
        TextSummarizerOptions(
          modelPath: model(kind),
          maxNumTokens: options['budget'],
          cacheDirectory: cache,
          mode: TextSummarizerMode.values.byName(
            (options['mode'] as String).toLowerCase(),
          ),
        ),
      );
      return Loaded((entry, streaming) async {
        if (!streaming) return (await task.summarize(entry['input'])).summary;
        final updates = await task.summarizeStream(entry['input']).toList();
        check(
          updates.where((u) => u.done).length == 1 && updates.last.done,
          'Summarizer terminal callback',
        );
        return updates.map((u) => u.chunk ?? '').join();
      }, task.dispose);
    default:
      throw ArgumentError(kind);
  }
}

Future<void> validateOptions() async {
  final results = <Json>[];
  report['option_matrix'] = results;
  for (final entry in cases) {
    final task = await load(entry);
    final result = <String, dynamic>{
      'task': entry['task'],
      'name': entry['name'],
      'options': entry['options'],
    };
    try {
      // Google's long-summary output can depend on prior requests. Reproduce
      // the official generator's short completed + streamed prefix exactly.
      if (entry['task'] != 'embedding' && entry['name'] == 'long') {
        final prefix = cases.firstWhere(
          (c) =>
              c['task'] == entry['task'] &&
              c['name'] == 'short' &&
              jsonEncode(c['options']) == jsonEncode(entry['options']),
        );
        compare(
          await task.run(prefix, false),
          prefix['output'],
          'reference prefix completed',
        );
        compare(
          await task.run(prefix, true),
          prefix['stream_output'],
          'reference prefix streaming',
        );
        result['reference_prefix_replayed'] = true;
      }
      for (final streaming
          in entry['task'] == 'embedding' ? [false] : [false, true]) {
        Object? actual;
        String? error;
        try {
          actual = await task.run(entry, streaming);
        } catch (failure) {
          error = switch (failure) {
            TaskException e => e.message,
            _ => throw failure,
          };
        }
        final errorKey = streaming ? 'stream_error' : 'error';
        final outputKey = streaming ? 'stream_output' : 'output';
        if (entry.containsKey(errorKey)) {
          // Google's C library can append the cause to the message its Python
          // API reports (the Summarizer's over-budget error does).
          final expected = entry[errorKey] as String;
          check(
            error != null &&
                (error == expected || error.startsWith('$expected ')),
            'Unexpected native error: $error; expected ${entry[errorKey]}',
          );
        } else {
          check(error == null, 'Unexpected native error: $error');
          final label = '${entry['task']}/${entry['name']}/stream=$streaming';
          if (unreproducible(entry)) {
            follows(actual, entry[outputKey], label);
            result['compared_by_prefix'] = true;
            result[streaming ? 'stream_exact' : 'exact'] =
                actual == entry[outputKey];
          } else {
            compare(actual, entry[outputKey], label);
          }
        }
      }
      if (entry['task'] != 'embedding' && entry.containsKey('error')) {
        final short = cases.firstWhere(
          (c) =>
              c['task'] == entry['task'] &&
              c['name'] == 'short' &&
              jsonEncode(c['options']) == jsonEncode(entry['options']),
        );
        compare(
          await task.run(short, false),
          short['output'],
          'recovery after token-limit error',
        );
        result['recovered_after_error'] = true;
      }
      result['passed'] = true;
    } catch (failure) {
      result['failure'] = '$failure';
    } finally {
      try {
        await task.dispose();
      } on TaskException catch (error) {
        check(
          entry['name'] == 'over-capacity',
          'Unexpected dispose error: $error',
        );
        result['native_close_error'] = error.message;
      }
      results.add(result);
    }
    stdout.writeln(
      '${result['passed'] == true ? 'Validated' : 'FAILED'} '
      '${entry['task']} ${entry['name']} ${entry['options']}',
    );
  }
  final failures = [
    for (final result in results)
      if (result['failure'] case final String failure) failure,
  ];
  check(
    failures.isEmpty,
    '${failures.length} of ${results.length} option cases failed, the first: '
    '${failures.firstOrNull}',
  );
}

Json sample(String task) => cases.firstWhere(
  (c) =>
      c['task'] == task &&
      (task == 'embedding'
          ? c['name'] == 'default'
          : c['name'] == 'short' && c['options']['budget'] == 0),
);

Future<double> timed(Future<void> Function() action) async {
  final watch = Stopwatch()..start();
  await action();
  return watch.elapsedMicroseconds / 1000;
}

Json stats(List<double> values) {
  final sorted = [...values]..sort();
  double percentile(double p) => sorted[((sorted.length - 1) * p).ceil()];
  return {
    'count': values.length,
    'median_ms':
        (sorted[(sorted.length - 1) ~/ 2] + sorted[sorted.length ~/ 2]) / 2,
    'p95_ms': percentile(.95),
    'min_ms': sorted.first,
    'max_ms': sorted.last,
    'samples_ms': values,
  };
}

Future<void> benchmark(int iterations, int reloads) async {
  final metrics = <String, dynamic>{};
  report['benchmarks'] = metrics;
  report['rss_before_load_bytes'] = ProcessInfo.currentRss;
  final loaded = <String, Loaded>{};
  InteractiveSegmenter? segmenter;
  late VisionImage image;
  late List<Stroke> history;
  late List<double> expected;
  try {
    for (final kind in ['embedding', 'proofreader', 'summarizer']) {
      final startup = await timed(() async {
        loaded[kind] = await load(sample(kind));
      });
      metrics[kind] = <String, dynamic>{
        'create_ms': startup,
        'options': sample(kind)['options'],
        'input': sample(kind)['input'],
      };
    }
    metrics['segmenter'] = <String, dynamic>{
      'create_ms': await timed(() async {
        segmenter = await InteractiveSegmenter.create(
          InteractiveSegmenterOptions(modelPath: model('segmenter')),
        );
      }),
    };
    final fixtureDir =
        '${repo.path}/packages/mediapipe-task-vision/test/fixtures/interactive_segmentation';
    final reference =
        jsonDecode(
              await File('$fixtureDir/official_reference.json').readAsString(),
            )
            as Json;
    final entry = (reference['cases'] as List).cast<Json>().firstWhere(
      (c) => c['name'] == 'raw-dog',
    );
    final imageBytes = await File(
      '$fixtureDir/animals-299x150.rgb',
    ).readAsBytes();
    check(
      sha256.convert(imageBytes).toString() == reference['raw']['sha256'],
      'Segmenter input hash',
    );
    check(
      (await sha256.bind(File(model('segmenter')).openRead()).first)
              .toString() ==
          reference['model_sha256'],
      'Segmenter model hash',
    );
    image = VisionImage.fromPixels(
      pixels: imageBytes,
      width: 299,
      height: 150,
      format: VisionPixelFormat.rgb,
    );
    history = [
      for (final Json s in (entry['strokes'] as List).cast<Json>())
        Stroke(
          brushMode: BrushMode.values.byName(s['brush_mode']),
          points: [
            for (final p in s['points'])
              NormalizedKeypoint(
                x: (p[0] as num).toDouble(),
                y: (p[1] as num).toDouble(),
              ),
          ],
          isCompleted: s['is_completed'],
        ),
    ];
    final maskBytes = Uint8List.fromList(
      gzip.decode(await File('$fixtureDir/${entry['mask']}').readAsBytes()),
    );
    check(
      sha256.convert(maskBytes).toString() == entry['sha256'],
      'Segmenter reference hash',
    );
    final data = ByteData.sublistView(maskBytes);
    expected = List<double>.generate(
      maskBytes.length ~/ 4,
      (i) => data.getFloat32(i * 4, Endian.little),
    );
    metrics['segmenter']['set_image_ms'] = await timed(
      () => segmenter!.setImage(image),
    );
    ConfidenceMask? mask;
    metrics['segmenter']['first_segment_ms'] = await timed(() async {
      mask = await segmenter!.segment(history);
    });
    compare(mask!.confidence, expected, 'first mask');
    final latencies = {
      for (final kind in [...loaded.keys, 'segmenter']) kind: <double>[],
    };
    final streamLatencies = {
      'proofreader': <double>[],
      'summarizer': <double>[],
    };
    final memory = <Json>[];
    for (var i = -3; i < iterations; i++) {
      for (final entry in loaded.entries) {
        Object? output;
        final streaming = i.isOdd && entry.key != 'embedding';
        final ms = await timed(() async {
          output = await entry.value.run(sample(entry.key), streaming);
        });
        compare(
          output,
          sample(entry.key)['output'],
          '${entry.key} iteration $i',
        );
        if (i >= 0) {
          (streaming ? streamLatencies[entry.key]! : latencies[entry.key]!).add(
            ms,
          );
        }
      }
      final ms = await timed(() async {
        mask = await segmenter!.segment(history);
      });
      compare(mask!.confidence, expected, 'mask iteration $i');
      if (i >= 0) {
        latencies['segmenter']!.add(ms);
        memory.add({
          'iteration': i,
          'rss_bytes': ProcessInfo.currentRss,
          'peak_rss_bytes': ProcessInfo.maxRss,
        });
      }
    }
    for (final entry in latencies.entries) {
      metrics[entry.key]['completed'] = stats(entry.value);
    }
    for (final entry in streamLatencies.entries) {
      if (entry.value.isNotEmpty) {
        metrics[entry.key]['streaming'] = stats(entry.value);
      }
    }
    report['sustained_memory'] = memory;
    report['rss_change_bytes'] =
        (memory.last['rss_bytes'] as int) - (memory.first['rss_bytes'] as int);
    final resets = <double>[];
    for (var i = 0; i < reloads; i++) {
      resets.add(
        await timed(() async {
          await segmenter!.setImage(image);
          mask = await segmenter!.segment(history);
        }),
      );
      compare(mask!.confidence, expected, 'reset mask $i');
    }
    metrics['segmenter']['reset_and_first_segment'] = stats(resets);
  } finally {
    for (final task in loaded.values) {
      await task.dispose();
    }
    await segmenter?.dispose();
  }
  report['rss_after_sustained_dispose_bytes'] = ProcessInfo.currentRss;
  report['reloads_memory'] = <Json>[];
  for (final kind in ['embedding', 'proofreader', 'summarizer', 'segmenter']) {
    final times = <double>[];
    for (var i = 0; i < reloads; i++) {
      times.add(
        await timed(() async {
          if (kind == 'segmenter') {
            final task = await InteractiveSegmenter.create(
              InteractiveSegmenterOptions(modelPath: model(kind)),
            );
            try {
              await task.setImage(image);
              compare(
                (await task.segment(history)).confidence,
                expected,
                'segmenter reload $i',
              );
            } finally {
              await task.dispose();
            }
          } else {
            final task = await load(sample(kind));
            try {
              compare(
                await task.run(sample(kind), false),
                sample(kind)['output'],
                '$kind reload $i',
              );
            } finally {
              await task.dispose();
            }
          }
        }),
      );
      (report['reloads_memory'] as List).add({
        'task': kind,
        'reload': i,
        'rss_bytes': ProcessInfo.currentRss,
      });
    }
    metrics[kind]['create_run_dispose'] = stats(times);
  }
  report['rss_after_reloads_bytes'] = ProcessInfo.currentRss;
}

Future<void> validateCaches() async {
  final root = Directory('${repo.path}/build/task-benchmarks')
    ..createSync(recursive: true);
  final cacheReport = <Json>[];
  report['caches'] = cacheReport;
  for (final kind in ['proofreader', 'summarizer']) {
    final cache = await root.createTemp('$kind-cache-');
    final record = <String, dynamic>{
      'task': kind,
      'directory': cache.path,
      'passes': <Json>[],
    };
    for (var i = 0; i < 2; i++) {
      final ms = await timed(() async {
        final task = await load(sample(kind), cache: cache.path);
        try {
          compare(
            await task.run(sample(kind), false),
            sample(kind)['output'],
            '$kind cache pass $i',
          );
        } finally {
          await task.dispose();
        }
      });
      final files = <Json>[];
      await for (final file in cache.list(recursive: true)) {
        if (file is File) {
          files.add({
            'name': file.path.substring(cache.path.length + 1),
            'bytes': await file.length(),
            'modified': (await file.lastModified()).toUtc().toIso8601String(),
          });
        }
      }
      files.sort(
        (a, b) => (a['name'] as String).compareTo(b['name'] as String),
      );
      (record['passes'] as List).add({
        'cold': i == 0,
        'ms': ms,
        'files': files,
      });
    }
    final passes = record['passes'] as List;
    check(
      (passes[0]['files'] as List).isNotEmpty,
      '$kind did not populate its explicit cache',
    );
    compare(
      passes[0]['files'],
      passes[1]['files'],
      '$kind cache reused without rewriting',
    );
    cacheReport.add(record);
  }
}

Future<void> validateGpuRejection() async {
  for (final kind in _Generative.values) {
    // A model given by path is checked against the task's general table.
    final support = await switch (kind) {
      _Generative.embeddingGemma => queryTextEmbedderCapabilities(),
      _Generative.proofreader => queryTextProofreaderCapabilities(),
      _Generative.summarizer => queryTextSummarizerCapabilities(),
    };
    try {
      switch (kind) {
        case _Generative.embeddingGemma:
          final task = await TextEmbedder.create(
            TextEmbedderOptions(
              modelPath: model('embedding'),
              delegate: Delegate.gpu,
            ),
          );
          await task.dispose();
        case _Generative.proofreader:
          final task = await TextProofreader.create(
            TextProofreaderOptions(
              modelPath: model('proofreader'),
              delegate: Delegate.gpu,
            ),
          );
          await task.dispose();
        case _Generative.summarizer:
          final task = await TextSummarizer.create(
            TextSummarizerOptions(
              modelPath: model('summarizer'),
              delegate: Delegate.gpu,
            ),
          );
          await task.dispose();
      }
    } catch (error) {
      check(
        '$error'.contains(support.unavailableReasons[Delegate.gpu]!),
        'GPU error differs from capabilities',
      );
      continue;
    }
    throw StateError('GPU request unexpectedly succeeded for $kind');
  }
  report['gpu_rejections'] =
      'all three text tasks reject with their capability explanation';
}

/// The tasks this benchmark measures beyond the classic ones.
enum _Generative { embeddingGemma, proofreader, summarizer }
