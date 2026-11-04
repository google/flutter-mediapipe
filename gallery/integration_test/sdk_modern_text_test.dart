import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mediapipe_text/mediapipe_text.dart';
import 'package:mediapipe_gallery/bundled_model_assets.dart';
import 'support/device_log.dart';

/// EmbeddingGemma, Proofreader and Summarizer through Google's official mobile
/// runtime (its 1.2.0 text library, which the text package's hook bundles on
/// Android and iOS), against Google's own outputs for the same model, runtime
/// version and inputs: the references the gallery's preparers bundle under
/// assets/references when these tasks are selected
/// (tool/prepare_modern_text_reference.py, from Google's wheel of that
/// version on the same architecture, else the text package's macOS
/// fixtures). Generated text must match exactly; embeddings come from another
/// build of the same runtime on another CPU and get a bound.
/// Runs on the Android emulator and iOS simulator in CI, and on phones.
///
/// EmbeddingGemma's vectors come from another build of the same release on
/// another CPU: the arm64 emulator and the iOS simulator reproduce Google's
/// wheel bit for bit, while Google's x86_64 Android build on the x86_64
/// emulator differs from its Linux x86_64 wheel by up to 0.008 per value
/// (upstream-issues.md UP-036). So each value gets a bound, and each vector
/// must point where Google's does.
const _embeddingBound = 2e-2;
const _embeddingCosine = 0.995;

/// Scalar-quantized bytes may round differently by a step or two across
/// builds.
const _quantizedBound = 2;

/// Generated text is compared with Google's wheel of the same release on the
/// same architecture, and Google's mobile and desktop builds of the same
/// release do not always agree to the last character: greedy decoding picks
/// a different word once floating-point noise flips a near-tie
/// (upstream-issues.md UP-036). The Proofreader matches exactly on every
/// build measured, so each of its outputs must match Google's from the
/// start for at least this many characters, or in full when Google's is
/// shorter. The Summarizer parts late in long summaries on the iOS
/// simulator and, on the x86_64 Android emulator, anywhere and differently
/// from run to run, so for it each output must have its mode's shape and a
/// majority of the cases must match Google's exactly, which a wrong prompt,
/// mode or token budget could not produce. Exact matches are counted in the
/// log.
const _minSharedPrefix = 80;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<Map<String, dynamic>> manifest() async =>
      jsonDecode(await rootBundle.loadString('assets/manifest.json'))
          as Map<String, dynamic>;

  /// Whether this build bundles the modern text tasks; a build prepared
  /// without them (the published galleries) has nothing to test here.
  Future<bool> bundled() async {
    final tasks = ((await manifest())['tasks'] as List).cast<String>();
    return tasks.contains('text_proofreader') &&
        tasks.contains('text_summarizer') &&
        tasks.contains('embedding_gemma');
  }

  Future<Map<String, dynamic>> reference(String name) async =>
      jsonDecode(
            await rootBundle.loadString(
              'assets/references/modern_text/$name.json',
            ),
          )
          as Map<String, dynamic>;

  /// The generative tasks read their model from a file, so each asset is
  /// written out once, beside the app.
  Future<String> modelFile(String name) async {
    final file = File(
      '${Directory.systemTemp.path}/mediapipe_modern_text/$name',
    );
    if (!await file.exists()) {
      await file.parent.create(recursive: true);
      final data = await rootBundle.load(bundledModelFile(name));
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
    }
    return file.path;
  }

  /// A reference is Google's answer only when it came from the wheel the
  /// tests pin, Google's 1.1.0 release candidate (core's `referenceWheels`),
  /// an older release than the device's library; the comparisons check each
  /// answer.
  Future<void> expectReferenceRuntime(
    Map<String, dynamic> reference,
    TaskCapabilities support,
  ) async {
    expect(support.supportedDelegates, {Delegate.cpu});
    expect(
      reference['runtime'],
      startsWith('mediapipe==1.1.0rc'),
      reason:
          'bundle references generated with the pinned reference wheel '
          '(prepare_gallery.dart --modern-text-reference)',
    );
  }

  testWidgets('EmbeddingGemma matches Google\'s reference embeddings', (
    tester,
  ) async {
    await tester.runAsync(() async {
      if (!await bundled()) {
        markTestSkipped('EmbeddingGemma is not bundled in this build.');
        return;
      }
      expect(Platform.isAndroid || Platform.isIOS, isTrue);
      final json = await reference('embedding_gemma');
      await expectReferenceRuntime(
        json,
        await queryTextEmbedderCapabilities(TextModels.embeddingGemma),
      );
      final cases = (json['cases'] as List).cast<Map<String, dynamic>>();
      final model = await modelFile('embedding_gemma.task');
      var worstFloat = 0.0;
      var worstQuantized = 0;
      for (final quantize in [false, true]) {
        final task = await TextEmbedder.create(
          TextEmbedderOptions(
            modelPath: model,
            quantize: quantize,
            l2Normalize: quantize,
          ),
        );
        try {
          for (final entry in cases.where(
            (entry) => entry['quantize'] == quantize,
          )) {
            final context = entry['context'] as Map<String, dynamic>?;
            final result = await task.embed(
              entry['text'] as String,
              formatContext: context == null
                  ? null
                  : TextFormatContext(
                      taskType: _embeddingType(context['task_type'] as String),
                      title: context['title'] as String?,
                      role: context['role'] == 'DOCUMENT'
                          ? TextRole.document
                          : TextRole.query,
                    ),
            );
            final expected = entry['embeddings'] as List;
            expect(result.embeddings, hasLength(expected.length));
            for (var i = 0; i < expected.length; i++) {
              final embedding = result.embeddings[i];
              final values = (expected[i]['values'] as List).cast<num>();
              expect(embedding.headIndex, expected[i]['head_index']);
              expect(embedding.length, 768, reason: entry['name']);
              if (quantize) {
                // Google's APIs list the scalar-quantized bytes unsigned, as
                // the reference holds them; one rounding step may wrap.
                final bytes = embedding.quantizedEmbedding!;
                for (var j = 0; j < values.length; j++) {
                  final raw = (bytes[j] - values[j].toInt()).abs();
                  final delta = math.min(raw, 256 - raw);
                  worstQuantized = math.max(worstQuantized, delta);
                  expect(
                    delta,
                    lessThanOrEqualTo(_quantizedBound),
                    reason: '${entry['name']} value $j',
                  );
                }
              } else {
                final floats = embedding.floatEmbedding!;
                var delta = 0.0;
                var dot = 0.0;
                var ours = 0.0;
                var theirs = 0.0;
                for (var j = 0; j < values.length; j++) {
                  delta = math.max(delta, (floats[j] - values[j]).abs());
                  dot += floats[j] * values[j];
                  ours += floats[j] * floats[j];
                  theirs += values[j] * values[j];
                }
                worstFloat = math.max(worstFloat, delta);
                expect(
                  delta,
                  lessThanOrEqualTo(_embeddingBound),
                  reason: '${entry['name']}: largest value difference',
                );
                expect(
                  dot / math.sqrt(ours * theirs),
                  greaterThanOrEqualTo(_embeddingCosine),
                  reason: '${entry['name']}: cosine similarity with Google\'s',
                );
              }
            }
          }
        } finally {
          await task.dispose();
        }
      }
      _report('embedding_gemma', {
        'cases': cases.length,
        'max_float_error': worstFloat,
        'max_quantized_error': worstQuantized,
      });
    });
  }, timeout: const Timeout(Duration(minutes: 10)));

  testWidgets('Proofreader matches Google\'s completed and streamed results', (
    tester,
  ) async {
    await tester.runAsync(() async {
      if (!await bundled()) {
        markTestSkipped('The Proofreader is not bundled in this build.');
        return;
      }
      final json = await reference('proofreader');
      await expectReferenceRuntime(
        json,
        await queryTextProofreaderCapabilities(),
      );
      final cases = (json['cases'] as List).cast<Map<String, dynamic>>();
      final model = await modelFile('proofread_quant_200m.litertlm');
      List<Map<String, String>> edits(List<ProofreadingCorrection> values) => [
        for (final value in values)
          {'type': value.type.name, 'text': value.text},
      ];
      final agreement = <Map<String, Object?>>[];
      final stopwatch = Stopwatch()..start();
      for (final budget in [null, 64]) {
        final task = await TextProofreader.create(
          TextProofreaderOptions(modelPath: model, maxNumTokens: budget),
        );
        try {
          for (final entry in cases.where(
            (entry) => entry['max_num_tokens'] == budget,
          )) {
            final input = entry['input'] as String;
            final expected = entry['result'] as Map<String, dynamic>;
            final result = await task.proofread(input);
            final updates = await task.proofreadStream(input).toList();
            expect(updates.where((u) => u.done), hasLength(1));
            expect(updates.last.done, isTrue);
            final streamed = updates.map((u) => u.chunk ?? '').join();
            agreement.add(
              _agreement(
                entry['name'] as String,
                expected['text'] as String?,
                result.proofreadText,
                streamed,
                expected['corrections'].toString() ==
                        edits(result.corrections).toString() &&
                    edits(updates.last.corrections).toString() ==
                        edits(result.corrections).toString(),
              ),
            );
          }
        } finally {
          await task.dispose();
        }
      }
      _report('proofreader', {
        'exact_matches':
            '${agreement.where((c) => c['match'] == true).length}'
            '/${agreement.length}',
        'cases': agreement,
        'ms': stopwatch.elapsedMilliseconds,
      });
      _expectAgreement(agreement);
    });
  }, timeout: const Timeout(Duration(minutes: 15)));

  testWidgets('Summarizer matches Google\'s results in both modes', (
    tester,
  ) async {
    await tester.runAsync(() async {
      if (!await bundled()) {
        markTestSkipped('The Summarizer is not bundled in this build.');
        return;
      }
      final json = await reference('summarizer');
      await expectReferenceRuntime(
        json,
        await queryTextSummarizerCapabilities(),
      );
      final cases = (json['cases'] as List).cast<Map<String, dynamic>>();
      final model = await modelFile('summarization_quant_200m_2modes.litertlm');
      final agreement = <Map<String, Object?>>[];
      final stopwatch = Stopwatch()..start();
      for (final mode in TextSummarizerMode.values) {
        for (final budget in [null, 64]) {
          final task = await TextSummarizer.create(
            TextSummarizerOptions(
              modelPath: model,
              mode: mode,
              maxNumTokens: budget,
            ),
          );
          try {
            expect(task.mode, mode);
            for (final entry in cases.where(
              (entry) =>
                  entry['mode'] == mode.name.toUpperCase() &&
                  entry['max_num_tokens'] == budget,
            )) {
              final input = entry['input'] as String;
              final summary = (await task.summarize(input)).summary;
              final updates = await task.summarizeStream(input).toList();
              expect(updates.where((u) => u.done), hasLength(1));
              expect(updates.last.done, isTrue);
              agreement.add({
                ..._agreement(
                  entry['name'] as String,
                  entry['result']['summary'] as String?,
                  summary,
                  updates.map((u) => u.chunk ?? '').join(),
                  true,
                ),
                'mode': mode.name,
              });
            }
            if (budget == null) {
              // Google refuses empty input with an error, not a summary.
              await expectLater(
                task.summarize(''),
                throwsA(isA<TaskException>()),
              );
              await expectLater(
                task.summarizeStream('').toList(),
                throwsA(isA<TaskException>()),
              );
            }
          } finally {
            await task.dispose();
          }
        }
      }
      _report('summarizer', {
        'exact_matches':
            '${agreement.where((c) => c['match'] == true).length}'
            '/${agreement.length}',
        'cases': agreement,
        'ms': stopwatch.elapsedMilliseconds,
      });
      _expectSummaries(agreement);
    });
  }, timeout: const Timeout(Duration(minutes: 15)));

  testWidgets('streams cancel, pause and dispose as on the desktop runtime', (
    tester,
  ) async {
    await tester.runAsync(() async {
      if (!await bundled()) {
        markTestSkipped('The Summarizer is not bundled in this build.');
        return;
      }
      final json = await reference('summarizer');
      final cases = (json['cases'] as List).cast<Map<String, dynamic>>();
      final tldr = cases.where((entry) => entry['mode'] == 'TLDR').toList();
      final model = await modelFile('summarization_quant_200m_2modes.litertlm');
      final task = await TextSummarizer.create(
        TextSummarizerOptions(modelPath: model, mode: TextSummarizerMode.tldr),
      );
      // Cancelling stops delivery; the next request waits for Google's
      // generation to finish and then answers as usual.
      final first = Completer<void>();
      var delivered = 0;
      final subscription = task
          .summarizeStream(tldr[0]['input'] as String)
          .listen((_) {
            delivered++;
            if (!first.isCompleted) first.complete();
          });
      await first.future;
      final before = delivered;
      final cancelling = subscription.cancel();
      final next = task.summarize(tldr[1]['input'] as String);
      await cancelling;
      _expectFollows(
        (await next).summary,
        tldr[1]['result']['summary'] as String,
        reason: 'the request after a cancel',
      );
      expect(delivered, before);
      // Pausing buffers updates; disposal drains accepted work first.
      final updates = <TextSummarizerUpdate>[];
      final done = Completer<void>();
      final paused =
          task
              .summarizeStream(tldr[1]['input'] as String)
              .listen(
                updates.add,
                onDone: done.complete,
                onError: done.completeError,
              )
            ..pause();
      final closing = task.dispose();
      expect(identical(closing, task.dispose()), isTrue);
      expect(updates, isEmpty);
      paused.resume();
      await done.future;
      await closing;
      _expectFollows(
        updates.map((u) => u.chunk ?? '').join(),
        tldr[1]['result']['summary'] as String,
        reason: 'the stream drained by dispose',
      );
      await expectLater(task.summarize('closed'), throwsStateError);
      await expectLater(
        task.summarizeStream('closed').toList(),
        throwsStateError,
      );
      _report('lifecycle', {'checks': 'cancel, pause, dispose'});
    });
  }, timeout: const Timeout(Duration(minutes: 10)));

  testWidgets('options the platform cannot honor fail before a model loads', (
    tester,
  ) async {
    await tester.runAsync(() async {
      if (!await bundled()) {
        markTestSkipped('The Proofreader is not bundled in this build.');
        return;
      }
      final model = await modelFile('proofread_quant_200m.litertlm');
      await expectLater(
        TextProofreader.create(
          TextProofreaderOptions(modelPath: model, delegate: Delegate.gpu),
        ),
        throwsA(isA<RuntimeUnavailableException>()),
      );
      final cache = Directory(
        '${Directory.systemTemp.path}/mediapipe_modern_text/cache',
      )..createSync(recursive: true);
      final withCache = TextProofreader.create(
        TextProofreaderOptions(modelPath: model, cacheDirectory: cache.path),
      );
      // Google's C API takes the cache directory on every native platform.
      final task = await withCache;
      try {
        final result = await task.proofread('She go home.');
        expect(result.proofreadText, isNotEmpty);
        await expectLater(task.proofread('bad\u0000text'), throwsArgumentError);
      } finally {
        await task.dispose();
      }
      await expectLater(
        TextProofreader.create(
          TextProofreaderOptions(modelPath: '$model.missing'),
        ),
        throwsA(isA<TaskException>()),
      );
      _report('options', {'checks': 'gpu, cache directory, bad path'});
    });
  }, timeout: const Timeout(Duration(minutes: 5)));
}

/// Google's Python enum names (`RETRIEVAL_QUERY`) to the Dart enum.
EmbeddingType _embeddingType(String name) => switch (name) {
  'RETRIEVAL_QUERY' => EmbeddingType.retrievalQuery,
  'RETRIEVAL_DOCUMENT' => EmbeddingType.retrievalDocument,
  'SEMANTIC_SIMILARITY' => EmbeddingType.semanticSimilarity,
  'CLASSIFICATION' => EmbeddingType.classification,
  'CLUSTERING' => EmbeddingType.clustering,
  'QUESTION_ANSWERING' => EmbeddingType.questionAnswering,
  'FACT_CHECKING' => EmbeddingType.factChecking,
  'CODE_RETRIEVAL' => EmbeddingType.codeRetrieval,
  _ => throw ArgumentError.value(name, 'task_type'),
};

/// How one generated text compares with Google's wheel (exact, or the length
/// of the shared prefix where they part) and whether the completed and
/// streamed paths, which run the same model here, agreed with each other.
Map<String, Object?> _agreement(
  String name,
  String? expected,
  String? completed,
  String streamed,
  bool correctionsMatch,
) {
  final a = expected ?? '';
  final b = completed ?? '';
  return {
    'name': name,
    'match': a == b && correctionsMatch,
    'stream_agrees': streamed == b,
    'shared_prefix': _sharedPrefix(a, b),
    'stream_shared_prefix': _sharedPrefix(b, streamed),
    'expected_length': a.length,
    'actual_length': b.length,
    if (a != b) 'completed': b,
    if (streamed != b) 'streamed': streamed,
  };
}

/// Every case must follow Google's wheel for [_minSharedPrefix] characters
/// (or in full when shorter), and its streamed text must follow its
/// completed text the same way.
void _expectAgreement(List<Map<String, Object?>> agreement) {
  for (final c in agreement) {
    final expected = c['expected_length'] as int;
    final required = math.min(_minSharedPrefix, expected);
    expect(
      c['shared_prefix'] as int,
      greaterThanOrEqualTo(required),
      reason:
          "${c['name']}: Google's wheel of this runtime version answered "
          'differently from the start: ${c['completed']}',
    );
    expect(
      c['stream_shared_prefix'] as int,
      greaterThanOrEqualTo(
        math.min(_minSharedPrefix, c['actual_length'] as int),
      ),
      reason:
          '${c['name']}: the streamed text differs from the completed text '
          'from the start: ${c['streamed']}',
    );
  }
}

/// Every summary has its mode's shape (key points are a bulleted list, a
/// TL;DR is prose), and at least half the cases match Google's exactly.
void _expectSummaries(List<Map<String, Object?>> agreement) {
  for (final c in agreement) {
    final text = (c['completed'] ?? '') as String;
    final exact = c['match'] == true;
    final bulleted = exact
        ? c['mode'] == TextSummarizerMode.keypoints.name
        : text.trimLeft().startsWith('*');
    expect(
      exact || text.trim().isNotEmpty,
      isTrue,
      reason: '${c['name']}: empty summary',
    );
    expect(
      bulleted,
      c['mode'] == TextSummarizerMode.keypoints.name,
      reason: '${c['name']}: not shaped like its mode: $text',
    );
  }
  final exact = agreement.where((c) => c['match'] == true).length;
  expect(
    exact * 2,
    greaterThanOrEqualTo(agreement.length),
    reason:
        "only $exact of ${agreement.length} summaries match Google's wheel of "
        'this runtime version exactly',
  );
}

/// Google's generation is not reproducible across devices (UP-036: the
/// Galaxy A12 wrote a different, correct TL;DR for the lifecycle case), so a
/// lifecycle check asks of one summary what the suite asks of every case:
/// that it follows Google's for [_minSharedPrefix] characters.
void _expectFollows(String? actual, String expected, {required String reason}) {
  expect(actual, isNotNull, reason: reason);
  expect(
    _sharedPrefix(actual!, expected),
    greaterThanOrEqualTo(math.min(_minSharedPrefix, expected.length)),
    reason: '$reason: "$actual" against "$expected"',
  );
}

int _sharedPrefix(String a, String b) {
  var prefix = 0;
  while (prefix < a.length && prefix < b.length && a[prefix] == b[prefix]) {
    prefix++;
  }
  return prefix;
}

// Kept in the device log (logcat, the simulator console) for the record.
void _report(String event, Map<String, Object?> data) =>
    logRecord('SDK_MODERN_TEXT', {'event': event, ...data});
