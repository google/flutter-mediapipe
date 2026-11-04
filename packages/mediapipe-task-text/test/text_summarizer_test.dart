// Needs the generative text models (make models) and, off macOS arm64,
// same-host references; see dart_test.yaml.
@Tags(['modern-text'])
@TestOn('mac-os || linux || windows')
library;

import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:mediapipe_text/mediapipe_text.dart';
import 'package:mediapipe_text/src/io/third_party/mediapipe/generative_text_bindings.dart'
    as mp;
import 'package:test/test.dart';

import 'support/modern_text_reference.dart';

final model = File(
  'models/summarization_quant_200m_2modes.litertlm',
).absolute.path;
final reference = loadReference('summarizer');
final cases = (reference['cases'] as List).cast<Map<String, dynamic>>();

TextSummarizerMode modeFor(Map<String, dynamic> entry) =>
    entry['mode'] == 'TLDR'
    ? TextSummarizerMode.tldr
    : TextSummarizerMode.keypoints;

/// Exact matches with Google's text, of the completed summaries and streams
/// compared; printed when the suite ends.
var _exact = 0, _compared = 0;

void _count(String? actual, String? expected) {
  _compared++;
  if (actual == expected) _exact++;
}

/// The task's completed summary against Google's for [entry] ([expectFollows]).
void compare(TextSummarizerResult result, Map<String, dynamic> entry) {
  _count(result.summary, entry['result']['summary']);
  expectFollows(
    result.summary,
    entry['result']['summary'],
    reason: entry['name'],
  );
}

/// Google's streamed text can differ from its completed text for the same
/// input (upstream-issues.md UP-036), so the stream is compared with the
/// reference's own streamed chunks, joined ([expectFollows]).
void compareStream(
  List<TextSummarizerUpdate> updates,
  Map<String, dynamic> entry,
) {
  expect(updates, isNotEmpty);
  expect(updates.where((e) => e.done), hasLength(1));
  expect(updates.last.done, isTrue);
  final expected = (entry['stream'] as List)
      .map((e) => (e as Map)['chunk'] as String? ?? '')
      .join();
  final actual = updates.map((e) => e.chunk ?? '').join();
  _count(actual, expected);
  expectFollows(actual, expected, reason: '${entry['name']} stream');
}

Future<TextSummarizer> create([
  TextSummarizerMode mode = TextSummarizerMode.keypoints,
  int? budget,
]) => TextSummarizer.create(
  TextSummarizerOptions(modelPath: model, mode: mode, maxNumTokens: budget),
);

void main() {
  tearDownAll(() {
    // Kept in the test log for the record.
    // ignore: avoid_print
    print("Summarizer: $_exact of $_compared texts match Google's exactly");
  });
  test("the reference comes from this host's pinned runtime", () async {
    await expectReferenceRuntime(
      reference,
      () => queryTextSummarizerCapabilities(),
    );
  });

  test('FFI sizes and field offsets match the official Python ABI', () {
    final abi = reference['abi'];
    expect(
      sizeOf<mp.MpTextSummarizerOptions>(),
      abi['_MpTextSummarizerOptionsC']['size'],
    );
    expect(
      sizeOf<mp.MpTextSummarizerResult>(),
      abi['_MpTextSummarizerResultC']['size'],
    );
    expect(
      sizeOf<mp.MpTextSummarizerStreamResult>(),
      abi['_MpTextSummarizerStreamResultC']['size'],
    );
    using((arena) {
      final options = arena<mp.MpTextSummarizerOptions>();
      options.ref
        ..mode = mp.MpTextSummarizerMode.MP_TEXT_SUMMARIZER_MODE_KEYPOINTS
        ..max_num_tokens = 64
        ..cache_dir = Pointer.fromAddress(1234);
      final bytes = options
          .cast<Uint8>()
          .asTypedList(sizeOf<mp.MpTextSummarizerOptions>())
          .buffer
          .asByteData();
      final fields = abi['_MpTextSummarizerOptionsC']['offsets'];
      expect(bytes.getInt32(fields['mode'], Endian.host), 1);
      expect(bytes.getInt32(fields['max_num_tokens'], Endian.host), 64);
      expect(bytes.getUint64(fields['cache_dir'], Endian.host), 1234);
      final stream = arena<mp.MpTextSummarizerStreamResult>();
      stream.ref
        ..chunk = Pointer.fromAddress(5678)
        ..done = true;
      final data = stream
          .cast<Uint8>()
          .asTypedList(sizeOf<mp.MpTextSummarizerStreamResult>())
          .buffer
          .asByteData();
      final offsets = abi['_MpTextSummarizerStreamResultC']['offsets'];
      expect(data.getUint64(offsets['chunk'], Endian.host), 5678);
      expect(data.getUint8(offsets['done']), 1);
    });
  });

  for (final mode in TextSummarizerMode.values) {
    for (final budget in [null, 64]) {
      test(
        'official completed/streaming summaries: ${mode.name}, budget $budget',
        () async {
          final task = await create(mode, budget);
          try {
            expect(task.mode, mode);
            expect(task.delegate, Delegate.cpu);
            for (final entry in cases.where(
              (e) => modeFor(e) == mode && e['max_num_tokens'] == budget,
            )) {
              compare(await task.summarize(entry['input']), entry);
              compareStream(
                await task.summarizeStream(entry['input']).toList(),
                entry,
              );
            }
          } finally {
            await task.dispose();
          }
        },
        timeout: const Timeout(Duration(minutes: 2)),
      );
    }

    test('native empty-input errors preserve the task: ${mode.name}', () async {
      final task = await create(mode);
      try {
        final entry = (reference['errors'] as List).singleWhere(
          (e) => e['mode'] == mode.name.toUpperCase(),
        );
        final error = isA<TaskException>().having(
          (e) => e.message,
          'message',
          entry['message'],
        );
        await expectLater(task.summarize(''), throwsA(error));
        await expectLater(task.summarizeStream('').toList(), throwsA(error));
        final valid = cases.firstWhere((e) => modeFor(e) == mode);
        compare(await task.summarize(valid['input']), valid);
        compareStream(
          await task.summarizeStream(valid['input']).toList(),
          valid,
        );
      } finally {
        await task.dispose();
      }
    });
  }

  test(
    'mixed queued requests and both modes own results after disposal',
    () async {
      final tldr = await create(TextSummarizerMode.tldr);
      final keypoints = await create();
      final paragraph = cases.first;
      final bullets = cases.firstWhere(
        (e) => modeFor(e) == TextSummarizerMode.keypoints,
      );
      final first = tldr.summarizeStream(paragraph['input']).toList();
      final second = tldr.summarize(cases[1]['input']);
      final third = keypoints.summarize(bullets['input']);
      final closing = tldr.dispose();
      expect(identical(closing, tldr.dispose()), isTrue);
      final updates = await first;
      final result = await second;
      final otherMode = await third;
      await closing;
      await keypoints.dispose();
      compareStream(updates, paragraph);
      compare(result, cases[1]);
      compare(otherMode, bullets);
      await expectLater(tldr.summarize('closed'), throwsStateError);
      await expectLater(
        tldr.summarizeStream('closed').toList(),
        throwsStateError,
      );
    },
  );

  test('cancellation drains and the next request succeeds', () async {
    final task = await create(TextSummarizerMode.tldr);
    try {
      final first = Completer<void>();
      var delivered = 0;
      final subscription = task.summarizeStream(cases.first['input']).listen((
        _,
      ) {
        delivered++;
        if (!first.isCompleted) first.complete();
      });
      await first.future;
      final before = delivered;
      final cancelling = subscription.cancel();
      final next = task.summarize(cases[1]['input']);
      await cancelling;
      compare(await next, cases[1]);
      expect(delivered, before);
    } finally {
      await task.dispose();
    }
  });

  test(
    'paused streams do not block disposal; unlistened streams start no work',
    () async {
      final task = await create(TextSummarizerMode.tldr);
      final lazy = task.summarizeStream(cases[1]['input']);
      final updates = <TextSummarizerUpdate>[];
      final done = Completer<void>();
      final subscription =
          task
              .summarizeStream(cases.first['input'])
              .listen(
                updates.add,
                onDone: done.complete,
                onError: done.completeError,
              )
            ..pause();
      await task.dispose();
      expect(updates, isEmpty);
      subscription.resume();
      await done.future;
      compareStream(updates, cases.first);
      await expectLater(lazy.toList(), throwsStateError);
    },
  );

  test('zero budget, native cache and default mode preserve output', () async {
    final cache = Directory('build/summarizer-cache')
      ..createSync(recursive: true);
    final task = await TextSummarizer.create(
      TextSummarizerOptions(
        modelPath: model,
        maxNumTokens: 0,
        cacheDirectory: cache.absolute.path,
      ),
    );
    try {
      expect(task.mode, TextSummarizerMode.keypoints);
      final entry = cases.firstWhere((e) => modeFor(e) == task.mode);
      compare(await task.summarize(entry['input']), entry);
    } finally {
      await task.dispose();
    }
  });

  test('creation errors propagate without hanging', () async {
    await expectLater(
      TextSummarizer.create(TextSummarizerOptions(modelPath: '$model.missing')),
      throwsA(isA<TaskException>()),
    );
    await expectLater(
      TextSummarizer.create(
        TextSummarizerOptions(modelPath: model, delegate: Delegate.gpu),
      ),
      throwsA(
        isA<RuntimeUnavailableException>().having(
          (e) => e.fix,
          'fix',
          contains('CPU'),
        ),
      ),
    );
  }, timeout: const Timeout(Duration(seconds: 20)));

  test('invalid Dart inputs leave the task usable', () async {
    expect(() => TextSummarizerOptions(modelPath: ''), throwsArgumentError);
    expect(
      () => TextSummarizerOptions(modelPath: model, maxNumTokens: -1),
      throwsArgumentError,
    );
    expect(
      () => TextSummarizerOptions(modelPath: model, maxNumTokens: 0x80000000),
      throwsArgumentError,
    );
    expect(
      () => TextSummarizerOptions(modelPath: model, cacheDirectory: ''),
      throwsArgumentError,
    );
    final task = await create(TextSummarizerMode.tldr);
    try {
      await expectLater(task.summarize('bad\u0000text'), throwsArgumentError);
      await expectLater(
        task.summarizeStream('bad\u0000text').toList(),
        throwsArgumentError,
      );
      compare(await task.summarize(cases.first['input']), cases.first);
    } finally {
      await task.dispose();
    }
  });
}
