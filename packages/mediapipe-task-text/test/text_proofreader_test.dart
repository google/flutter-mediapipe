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

final model = File('models/proofread_quant_200m.litertlm').absolute.path;
final reference = loadReference('proofreader');
final cases = (reference['cases'] as List).cast<Map<String, dynamic>>();

List<Map<String, String>> edits(List<ProofreadingCorrection> values) => [
  for (final value in values) {'type': value.type.name, 'text': value.text},
];

void compare(TextProofreaderResult result, Map<String, dynamic> entry) {
  expect(result.proofreadText, entry['result']['text'], reason: entry['name']);
  expect(edits(result.corrections), entry['result']['corrections']);
}

/// Google's streamed text can differ from its completed text for the same
/// input (upstream-issues.md UP-036), so the stream is compared with the
/// reference's own streamed events: the chunks joined, and the corrections
/// of the final one.
void compareStream(
  List<TextProofreaderUpdate> updates,
  Map<String, dynamic> entry,
) {
  expect(updates, isNotEmpty);
  expect(updates.where((e) => e.done), hasLength(1));
  expect(updates.last.done, isTrue);
  final events = (entry['stream'] as List).cast<Map<String, dynamic>>();
  expect(
    updates.map((e) => e.chunk ?? '').join(),
    events.map((e) => e['text'] as String? ?? '').join(),
  );
  expect(edits(updates.last.corrections), events.last['corrections']);
}

/// [compare] for a request run out of the reference's order.
void compareLoosely(TextProofreaderResult result, Map<String, dynamic> entry) =>
    expectFollows(
      result.proofreadText,
      entry['result']['text'],
      reason: entry['name'],
    );

/// [compareStream] for a request run out of the reference's order.
void compareStreamLoosely(
  List<TextProofreaderUpdate> updates,
  Map<String, dynamic> entry,
) {
  expect(updates, isNotEmpty);
  expect(updates.where((e) => e.done), hasLength(1));
  expect(updates.last.done, isTrue);
  final events = (entry['stream'] as List).cast<Map<String, dynamic>>();
  expectFollows(
    updates.map((e) => e.chunk ?? '').join(),
    events.map((e) => e['text'] as String? ?? '').join(),
    reason: '${entry['name']} stream',
  );
}

Future<TextProofreader> create([int? maxNumTokens]) => TextProofreader.create(
  TextProofreaderOptions(modelPath: model, maxNumTokens: maxNumTokens),
);

void main() {
  test("the reference comes from this host's pinned runtime", () async {
    await expectReferenceRuntime(
      reference,
      () => queryTextProofreaderCapabilities(),
    );
  });

  test(
    'zero token budget and an explicit native cache preserve output',
    () async {
      final cache = Directory('build/proofreader-cache')
        ..createSync(recursive: true);
      final task = await TextProofreader.create(
        TextProofreaderOptions(
          modelPath: model,
          maxNumTokens: 0,
          cacheDirectory: cache.absolute.path,
        ),
      );
      try {
        compare(await task.proofread(cases[0]['input']), cases[0]);
        compareStream(
          await task.proofreadStream(cases[0]['input']).toList(),
          cases[0],
        );
      } finally {
        await task.dispose();
      }
    },
  );

  test('proofreader FFI sizes and field offsets match official Python ABI', () {
    final abi = reference['abi'];
    expect(
      sizeOf<mp.MpTextProofreaderOptions>(),
      abi['_MpTextProofreaderOptionsC']['size'],
    );
    expect(sizeOf<mp.MpCorrection>(), abi['_MpCorrectionC']['size']);
    expect(
      sizeOf<mp.MpTextProofreaderResult>(),
      abi['_MpTextProofreaderResultC']['size'],
    );
    expect(
      sizeOf<mp.MpTextProofreaderStreamResult>(),
      abi['_MpTextProofreaderStreamResultC']['size'],
    );
    using((arena) {
      ByteData bytes<T extends NativeType>(Pointer<T> value, int length) =>
          value.cast<Uint8>().asTypedList(length).buffer.asByteData();
      final options = arena<mp.MpTextProofreaderOptions>();
      options.ref
        ..max_num_tokens = 123
        ..cache_dir = Pointer.fromAddress(456);
      final fields = abi['_MpTextProofreaderOptionsC']['offsets'];
      final data = bytes(options, sizeOf<mp.MpTextProofreaderOptions>());
      expect(data.getInt32(fields['max_num_tokens'], Endian.host), 123);
      expect(data.getUint64(fields['cache_dir'], Endian.host), 456);
      final stream = arena<mp.MpTextProofreaderStreamResult>();
      stream.ref
        ..chunk = Pointer.fromAddress(123)
        ..corrections_count = 7
        ..corrections = Pointer.fromAddress(456)
        ..done = true;
      final streamData = bytes(
        stream,
        sizeOf<mp.MpTextProofreaderStreamResult>(),
      );
      final offsets = abi['_MpTextProofreaderStreamResultC']['offsets'];
      expect(streamData.getUint64(offsets['chunk'], Endian.host), 123);
      expect(streamData.getInt32(offsets['corrections_count'], Endian.host), 7);
      expect(streamData.getUint64(offsets['corrections'], Endian.host), 456);
      expect(streamData.getUint8(offsets['done']), 1);
    });
  });

  for (final budget in [null, 64]) {
    test(
      'official completed and streaming results, token budget $budget',
      () async {
        final task = await create(budget);
        try {
          for (final entry in cases.where(
            (e) => e['max_num_tokens'] == budget,
          )) {
            compare(await task.proofread(entry['input']), entry);
            compareStream(
              await task.proofreadStream(entry['input']).toList(),
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

  test(
    'mixed requests serialize, disposal drains, and results remain owned',
    () async {
      final task = await create();
      final first = task.proofreadStream(cases[0]['input']).toList();
      final second = task.proofread(cases[1]['input']);
      final third = task.proofreadStream(cases[2]['input']).toList();
      final closing = task.dispose();
      expect(identical(closing, task.dispose()), isTrue);
      final updates = await first;
      final result = await second;
      final finalUpdates = await third;
      await closing;
      compareStreamLoosely(updates, cases[0]);
      compareLoosely(result, cases[1]);
      compareStreamLoosely(finalUpdates, cases[2]);
      expect(() => result.corrections.clear(), throwsUnsupportedError);
      expect(() => updates.last.corrections.clear(), throwsUnsupportedError);
      await expectLater(task.proofread('closed'), throwsStateError);
      await expectLater(
        task.proofreadStream('closed').toList(),
        throwsStateError,
      );
    },
  );

  test(
    'cancelling after first chunk drains native work before next request',
    () async {
      final task = await create();
      try {
        final firstChunk = Completer<void>();
        var delivered = 0;
        final subscription = task.proofreadStream(cases[6]['input']).listen((
          _,
        ) {
          delivered++;
          if (!firstChunk.isCompleted) firstChunk.complete();
        });
        await firstChunk.future;
        final beforeCancel = delivered;
        final cancellation = subscription.cancel();
        final next = task.proofread(cases[0]['input']);
        await cancellation;
        compareLoosely(await next, cases[0]);
        expect(delivered, beforeCancel);
      } finally {
        await task.dispose();
      }
    },
  );

  test(
    'paused stream buffers owned results without blocking disposal',
    () async {
      final task = await create();
      final updates = <TextProofreaderUpdate>[];
      final done = Completer<void>();
      final subscription =
          task
              .proofreadStream(cases[0]['input'])
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
      compareStreamLoosely(updates, cases[0]);
    },
  );

  test(
    'unlistened stream starts no work and fails if listened after disposal',
    () async {
      final task = await create();
      final stream = task.proofreadStream('She go home.');
      await task.dispose();
      await expectLater(stream.toList(), throwsStateError);
    },
  );

  test('creation failures return errors instead of hanging', () async {
    await expectLater(
      TextProofreader.create(
        TextProofreaderOptions(modelPath: '$model.missing'),
      ),
      throwsA(isA<TaskException>()),
    );
    await expectLater(
      TextProofreader.create(
        TextProofreaderOptions(modelPath: model, delegate: Delegate.gpu),
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

  test(
    'invalid inputs fail before native inference and leave task usable',
    () async {
      expect(() => TextProofreaderOptions(modelPath: ''), throwsArgumentError);
      expect(
        () => TextProofreaderOptions(modelPath: model, maxNumTokens: -1),
        throwsArgumentError,
      );
      expect(
        () =>
            TextProofreaderOptions(modelPath: model, maxNumTokens: 0x80000000),
        throwsArgumentError,
      );
      expect(
        () => TextProofreaderOptions(modelPath: model, cacheDirectory: ''),
        throwsArgumentError,
      );
      final task = await create();
      try {
        await expectLater(task.proofread('bad\u0000text'), throwsArgumentError);
        await expectLater(
          task.proofreadStream('bad\u0000text').toList(),
          throwsArgumentError,
        );
        compareLoosely(await task.proofread(cases[0]['input']), cases[0]);
      } finally {
        await task.dispose();
      }
    },
  );
}
