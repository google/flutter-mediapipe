import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediapipe_audio/mediapipe_audio.dart';
import 'package:mediapipe_audio/platform_interface.dart';
import 'package:mediapipe_gallery/audio/microphone.dart';
import 'package:mediapipe_gallery/audio_page.dart';
import 'package:mediapipe_gallery/catalog.dart';
import 'package:mediapipe_gallery/ui/components.dart';

/// 16-bit little-endian PCM of [values].
Uint8List _pcm(Iterable<int> values) {
  final list = values.toList();
  final bytes = ByteData(list.length * 2);
  for (final (i, value) in list.indexed) {
    bytes.setInt16(i * 2, value, Endian.little);
  }
  return bytes.buffer.asUint8List();
}

/// Google's browser task, faked, under the page's tasks: each result names
/// its call, and [failAt] fails one call as Google's runtime would.
final class _FakeClips implements AudioTaskBackend {
  _FakeClips(this.failAt);

  final int? failAt;
  var calls = 0;
  var disposed = false;

  /// Holds [dispose] until it completes, as a slow runtime would.
  Completer<void>? disposeGate;

  @override
  Future<List<Object?>> classify(Float32List samples, double rate) async {
    final call = calls++;
    if (call == failAt) throw const TaskException('Fake graph failure.');
    return [
      {
        'timestampMs': 0,
        'classifications': [
          {
            'headIndex': 0,
            'headName': '',
            'categories': [
              {
                'index': 0,
                'score': 0.9,
                'categoryName': 'Call $call',
                'displayName': '',
              },
            ],
          },
        ],
      },
    ];
  }

  @override
  Future<void> dispose() async {
    await disposeGate?.future;
    disposed = true;
  }
}

void main() {
  group('PcmBlocks', () {
    test('a sample split between chunks waits for its second byte', () {
      final blocks = PcmBlocks(16000);
      final pcm = _pcm([for (var i = 0; i < 48; i++) i * 100]);
      // 16 samples and the first byte of the 17th.
      final (first, start) = blocks.add(Uint8List.sublistView(pcm, 0, 33))!;
      expect(start, 0);
      expect(first.samples, [for (var i = 0; i < 16; i++) i * 100 / 32768]);
      final (second, next) = blocks.add(Uint8List.sublistView(pcm, 33))!;
      expect(next, 1);
      expect(second.samples, [for (var i = 16; i < 48; i++) i * 100 / 32768]);
      expect(blocks.sentMilliseconds, 3);
    });

    test('a chunk too short to advance the millisecond waits for the next', () {
      final blocks = PcmBlocks(16000);
      expect(blocks.add(_pcm(List.filled(10, 1))), isNull);
      final (block, start) = blocks.add(_pcm(List.filled(10, 2)))!;
      expect(start, 0);
      expect(block.samples, [
        ...List.filled(10, 1 / 32768),
        ...List.filled(10, 2 / 32768),
      ]);
      // 20 samples sent: the next block starts 1.25 ms in.
      expect(blocks.add(_pcm(List.filled(16, 3)))!.$2, 1);
    });
  });

  group('the microphone mode', () {
    late StreamController<Uint8List> microphone;
    late List<_FakeClips> backends;
    var stopped = false;
    int? failAt;

    // How often the page started the microphone, and gates that hold the
    // stream task's creation and the microphone's start.
    var starts = 0;
    Completer<void>? streamGate;
    Completer<void>? microphoneGate;

    // Core caches its platform query, and a future first made inside one
    // test's fake clock would never complete in the next test: make it here.
    setUpAll(() async {
      await queryAudioClassifierCapabilities();
      // The page passes YAMNet's pin, which core copies out of the bundle
      // into its cache; tests have no application support directory.
      ModelStore.debugCacheDirectory = Directory.systemTemp
          .createTempSync('gallery-models-')
          .path;
    });

    setUp(() {
      backends = [];
      stopped = false;
      failAt = null;
      starts = 0;
      streamGate = microphoneGate = null;
      microphone = StreamController<Uint8List>(onCancel: () => stopped = true);
      audioTaskBackendFactory = (options) async {
        final backend = _FakeClips(backends.isEmpty ? null : failAt);
        backends.add(backend);
        // The first backend is the clips task's, the second the stream's.
        if (backends.length == 2) await streamGate?.future;
        return backend;
      };
    });
    tearDown(() => audioTaskBackendFactory = null);

    Future<bool> bundled() async {
      try {
        await rootBundle.load('assets/mediapipe/${AudioModels.yamnet.sha256}');
        return true;
      } on Object {
        return false;
      }
    }

    /// The page, once it has classified the sample clip: it keeps its
    /// controls disabled meanwhile.
    Future<void> openPage(WidgetTester tester) async {
      final task = supportedTasks(
        const TaskPlatform(
          operatingSystem: 'macos',
          architecture: 'arm64',
          version: '15.0',
        ),
        {'audio_classifier'},
      ).single;
      await tester.pumpWidget(
        MaterialApp(
          home: AudioPage(
            task: task,
            microphone: (rate) async {
              starts++;
              await microphoneGate?.future;
              return microphone.stream;
            },
          ),
        ),
      );
      await _until(
        tester,
        () => find.textContaining('Done in').evaluate().isNotEmpty,
      );
    }

    Future<void> open(WidgetTester tester) async {
      await openPage(tester);
      await tester.tap(find.byKey(const ValueKey('audio-source-microphone')));
      await _until(
        tester,
        () => find.textContaining('Listening').evaluate().isNotEmpty,
      );
    }

    /// [windows] of YAMNet's 15,600 samples, in recorder chunks of 4,001
    /// bytes.
    Future<void> feed(WidgetTester tester, int windows) async {
      final pcm = _pcm(List.filled(windows * 15600, 1000));
      for (var at = 0; at < pcm.length; at += 4001) {
        microphone.add(
          Uint8List.sublistView(pcm, at, (at + 4001).clamp(0, pcm.length)),
        );
      }
      await _settle(tester);
    }

    testWidgets('lists the newest eight windows, each at its start', (
      tester,
    ) async {
      if (await tester.runAsync(bundled) != true) {
        markTestSkipped('This build bundles no Audio Classifier.');
        return;
      }
      await open(tester);
      await feed(tester, 9);
      await _until(tester, () => find.text('Call 8').evaluate().isNotEmpty);
      for (var i = 0; i < 8; i++) {
        expect(find.byKey(ValueKey('audio-window-$i')), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('audio-window-8')), findsNothing);
      // Newest first: window 8 starts 8 * 975 ms into the stream.
      expect(find.text('7.800 s'), findsOneWidget);
      expect(find.text('0.975 s'), findsOneWidget);
      expect(find.text('0.000 s'), findsNothing);
      expect(find.text('Call 8'), findsOneWidget);
      expect(find.text('Call 0'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('audio-source-clips')));
      await _until(tester, () => backends[1].disposed);
      // Leaving the mode stops the microphone and disposes the stream task.
      expect(stopped, isTrue);
      expect(backends[1].disposed, isTrue);
    });

    testWidgets('shows a failure and stops the microphone', (tester) async {
      if (await tester.runAsync(bundled) != true) {
        markTestSkipped('This build bundles no Audio Classifier.');
        return;
      }
      failAt = 1;
      await open(tester);
      await feed(tester, 3);
      await _until(tester, () => backends[1].disposed);
      expect(find.text('Error'), findsOneWidget);
      expect(find.textContaining('Fake graph failure.'), findsOneWidget);
      expect(stopped, isTrue);
      expect(backends[1].disposed, isTrue);
    });

    testWidgets('leaving the mode while its stream opens closes the stream', (
      tester,
    ) async {
      if (await tester.runAsync(bundled) != true) {
        markTestSkipped('This build bundles no Audio Classifier.');
        return;
      }
      final gate = streamGate = Completer<void>();
      await openPage(tester);
      await tester.tap(find.byKey(const ValueKey('audio-source-microphone')));
      await _until(tester, () => backends.length == 2);
      await tester.tap(find.byKey(const ValueKey('audio-source-clips')));
      await _settle(tester);
      gate.complete();
      await _until(tester, () => backends[1].disposed);
      expect(backends[1].disposed, isTrue);
      expect(starts, 0);
    });

    testWidgets('leaving the mode while the microphone starts stops it', (
      tester,
    ) async {
      if (await tester.runAsync(bundled) != true) {
        markTestSkipped('This build bundles no Audio Classifier.');
        return;
      }
      final gate = microphoneGate = Completer<void>();
      await openPage(tester);
      await tester.tap(find.byKey(const ValueKey('audio-source-microphone')));
      await _until(tester, () => starts == 1);
      await tester.tap(find.byKey(const ValueKey('audio-source-clips')));
      await _until(tester, () => backends[1].disposed);
      gate.complete();
      await _until(tester, () => stopped);
      expect(stopped, isTrue);
      expect(backends[1].disposed, isTrue);
    });

    testWidgets('a settings change queued first opens the only stream', (
      tester,
    ) async {
      if (await tester.runAsync(bundled) != true) {
        markTestSkipped('This build bundles no Audio Classifier.');
        return;
      }
      await openPage(tester);
      // The rebuild waits on the clips task's disposal while the mode opens.
      final gate = backends.single.disposeGate = Completer<void>();
      tester
          .widget<CountStepper>(
            find.byKey(const ValueKey('setting-maxResults')),
          )
          .onIncrease!();
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('audio-source-microphone')));
      await _settle(tester);
      gate.complete();
      await _until(
        tester,
        () => find.textContaining('Listening').evaluate().isNotEmpty,
      );
      await feed(tester, 1);
      await _until(tester, () => find.text('Call 0').evaluate().isNotEmpty);
      expect(find.text('Call 0'), findsOneWidget);
      expect(backends, hasLength(2));
      expect(backends[1].disposed, isFalse);
    });
  });
}

/// Lets the tasks, the fake runtime and the page's frames go on a while.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
}

/// Settles until [done], for at most ten seconds.
Future<void> _until(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 1000 && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
}
