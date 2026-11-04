import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:mediapipe_core/platform_interface.dart'
    show maxStreamTimestampMilliseconds;
import 'package:mediapipe_vision/mediapipe_vision.dart';
import 'package:mediapipe_vision/platform_interface.dart';
import 'package:mediapipe_vision/src/runner/vision_task_runner.dart';
import 'package:test/test.dart';

/// One request as a backend received it.
typedef _Call = ({
  int? timestamp,
  int rotation,
  VisionRegionOfInterest? region,
  int width,
});

/// A platform backend (Google's browser runtime or Android SDK) whose frames
/// finish when the test completes them, as those runtimes answer from their
/// own threads. Like Google's tracking, each result depends on the frames
/// before it: its height counts the frames the task has run.
final class _Backend<R> implements VisionTaskBackend<R> {
  _Backend(this._result);
  final R Function(_Call call, int seen) _result;
  final calls = <_Call>[];
  final _pending = <Completer<void>>[];
  var disposed = false;

  /// Answers every frame at once instead of waiting for [finish].
  var immediate = false;

  @override
  Future<R> detect(
    VisionImage image,
    int rotationDegrees,
    int? timestampMilliseconds, {
    VisionRegionOfInterest? regionOfInterest,
  }) async {
    final call = (
      timestamp: timestampMilliseconds,
      rotation: rotationDegrees,
      region: regionOfInterest,
      width: image.width!,
    );
    calls.add(call);
    final seen = calls.length;
    if (!immediate) {
      final done = Completer<void>();
      _pending.add(done);
      await done.future;
    }
    return _result(call, seen);
  }

  /// Completes the oldest frame still running, or fails it with [error].
  void finish([Object? error]) {
    final done = _pending.removeAt(0);
    error == null ? done.complete() : done.completeError(error);
  }

  @override
  Future<void> dispose() async => disposed = true;
}

FaceDetectorResult _faces(_Call call, int seen) => FaceDetectorResult(
  imageWidth: call.width,
  imageHeight: seen,
  detections: const [],
  timestampMilliseconds: call.timestamp,
);

/// A 1x1 frame whose width tells frames apart in a backend's log.
VisionImage _frame([int width = 1]) => VisionImage.fromPixels(
  pixels: Uint8List(width * 3),
  width: width,
  height: 1,
  format: VisionPixelFormat.rgb,
);

final _model = Uint8List.fromList([1]);

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late _Backend<FaceDetectorResult> backend;
  setUp(() {
    backend = _Backend(_faces);
    faceDetectorBackendFactory = (_) async => backend;
  });
  tearDown(() => faceDetectorBackendFactory = null);

  Future<FaceDetector> open([RunningMode mode = RunningMode.liveStream]) =>
      FaceDetector.create(
        FaceDetectorOptions(modelBytes: _model, runningMode: mode),
      );

  group('live stream', () {
    test('runs every frame with the arguments VIDEO would pass, and the '
        'same frames give the same results', () async {
      final frames = [
        for (var i = 0; i < 4; i++) (_frame(i + 1), i * 33, i * 90),
      ];
      backend.immediate = true;
      final video = await open(RunningMode.video);
      final videoResults = [
        for (final (image, timestamp, rotation) in frames)
          await video.detectForVideo(
            image,
            timestampMilliseconds: timestamp,
            rotationDegrees: rotation,
          ),
      ];
      await video.dispose();
      final videoCalls = [...backend.calls];

      backend = _Backend(_faces)..immediate = true;
      final live = await open();
      final liveResults = <FaceDetectorResult>[];
      final subscription = live.results.listen(liveResults.add);
      for (final (image, timestamp, rotation) in frames) {
        // Each frame after the last result, so none waits or is dropped.
        live.detectAsync(
          image,
          timestampMilliseconds: timestamp,
          rotationDegrees: rotation,
        );
        await _settle();
      }
      await live.dispose();
      await subscription.cancel();
      expect(backend.calls, videoCalls);
      expect(live.droppedFrames, 0);
      expect(
        [for (final r in liveResults) r.toString()],
        [for (final r in videoResults) r.toString()],
      );
    });

    test('the newest queued frame wins and the replaced ones are counted '
        'and get no result', () async {
      final task = await open();
      final results = <FaceDetectorResult>[];
      task.results.listen(results.add);
      for (var i = 0; i < 5; i++) {
        task.detectAsync(_frame(i + 1), timestampMilliseconds: i);
      }
      await _settle();
      expect(backend.calls.map((c) => c.timestamp), [0]);
      expect(task.droppedFrames, 3, reason: 'frames 1, 2 and 3 were replaced');
      backend.finish();
      await _settle();
      expect(backend.calls.map((c) => c.timestamp), [0, 4]);
      backend.finish();
      await _settle();
      expect(results.map((r) => r.timestampMilliseconds), [0, 4]);
      expect(results.map((r) => r.imageWidth), [1, 5]);
      // Idle again: the next frame runs at once.
      task.detectAsync(_frame(), timestampMilliseconds: 5);
      await _settle();
      expect(backend.calls.map((c) => c.timestamp), [0, 4, 5]);
      expect(task.droppedFrames, 3);
      backend.finish();
      await task.dispose();
    });

    test("a dropped frame's timestamp stays reserved, and bad timestamps "
        'throw at submission with the VIDEO message', () async {
      final video = await open(RunningMode.video);
      Object? videoError;
      try {
        await video.detectForVideo(_frame(), timestampMilliseconds: -1);
      } catch (error) {
        videoError = error;
      }
      await video.dispose();

      final task = await open();
      task.results.listen((_) {});
      task.detectAsync(_frame(), timestampMilliseconds: 10);
      task.detectAsync(_frame(), timestampMilliseconds: 20);
      task.detectAsync(_frame(), timestampMilliseconds: 30);
      expect(task.droppedFrames, 1, reason: 'frame 20 was replaced');
      for (final timestamp in [-1, 15, 20, 30]) {
        expect(
          () => task.detectAsync(_frame(), timestampMilliseconds: timestamp),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              (videoError! as ArgumentError).message,
            ),
          ),
          reason: '$timestamp',
        );
      }
      expect(
        () => task.detectAsync(
          _frame(),
          timestampMilliseconds: maxStreamTimestampMilliseconds + 1,
        ),
        throwsArgumentError,
      );
      expect(task.droppedFrames, 1, reason: 'refused frames are not dropped');
      backend.finish();
      await _settle();
      backend.finish();
      await task.dispose();
      expect(backend.calls.map((c) => c.timestamp), [10, 30]);
    });

    test('checks throw synchronously and leave nothing queued', () async {
      final task = await open();
      task.results.listen((_) {});
      expect(
        () => task.detectAsync(
          _frame(),
          timestampMilliseconds: 0,
          rotationDegrees: 45,
        ),
        throwsArgumentError,
      );
      // A refused rotation reserves no timestamp.
      task.detectAsync(_frame(), timestampMilliseconds: 0);
      backend.finish();
      await task.dispose();
      expect(backend.calls, hasLength(1));
    });

    test('a frame needs a listener, then cancelling discards later results '
        'while frames keep running', () async {
      final task = await open();
      expect(
        () => task.detectAsync(_frame(), timestampMilliseconds: 0),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Listen to FaceDetector.results'),
          ),
        ),
      );
      expect(backend.calls, isEmpty);
      final results = <int?>[];
      final subscription = task.results.listen(
        (r) => results.add(r.timestampMilliseconds),
      );
      // The refused frame reserved no timestamp.
      task.detectAsync(_frame(), timestampMilliseconds: 0);
      backend.finish();
      await _settle();
      expect(results, [0]);
      await subscription.cancel();
      task.detectAsync(_frame(), timestampMilliseconds: 1);
      await _settle();
      backend.finish();
      await _settle();
      expect(backend.calls, hasLength(2));
      expect(results, [0]);
      // One subscription only, as Google has one result listener.
      expect(() => task.results.listen((_) {}), throwsStateError);
      await task.dispose();
    });

    test('a paused listener gets every result, buffered, and does not '
        'block disposal', () async {
      final task = await open();
      final results = <int?>[];
      final done = Completer<void>();
      final subscription = task.results.listen(
        (r) => results.add(r.timestampMilliseconds),
        onDone: done.complete,
      )..pause();
      task.detectAsync(_frame(), timestampMilliseconds: 0);
      task.detectAsync(_frame(), timestampMilliseconds: 1);
      backend.finish();
      await _settle();
      backend.finish();
      await task.dispose();
      expect(results, isEmpty);
      subscription.resume();
      await done.future;
      expect(results, [0, 1]);
    });

    test('a failure reaches the listener, closes the stream and poisons the '
        'task; disposal still releases it', () async {
      final task = await open();
      final events = <Object>[];
      final done = Completer<void>();
      task.results.listen(
        events.add,
        onError: (Object error) => events.add(error),
        onDone: done.complete,
      );
      task.detectAsync(_frame(), timestampMilliseconds: 0);
      task.detectAsync(_frame(), timestampMilliseconds: 1);
      backend.finish(const TaskException('graph failed'));
      await done.future;
      expect(events, [
        isA<TaskException>().having(
          (e) => e.message,
          'message',
          'graph failed',
        ),
      ]);
      expect(task.droppedFrames, 1, reason: 'the queued frame never runs');
      expect(backend.calls, hasLength(1));
      expect(
        () => task.detectAsync(_frame(), timestampMilliseconds: 2),
        throwsA(same(events.single)),
      );
      await task.dispose();
      expect(backend.disposed, isTrue);
    });

    test("a failure that is not Google's arrives as a TaskException", () async {
      final task = await open();
      final errors = <Object>[];
      task.results.listen((_) {}, onError: errors.add);
      task.detectAsync(_frame(), timestampMilliseconds: 0);
      backend.finish(StateError('lost'));
      await _settle();
      await _settle();
      expect(errors.single, isA<TaskException>());
      await task.dispose();
    });

    test('disposal runs the frame in flight and the queued one, delivers '
        'both, then closes the stream; twice is once', () async {
      final task = await open();
      final events = <String>[];
      task.results.listen(
        (r) => events.add('result ${r.timestampMilliseconds}'),
        onDone: () => events.add('done'),
      );
      task.detectAsync(_frame(), timestampMilliseconds: 0);
      task.detectAsync(_frame(), timestampMilliseconds: 1);
      task.detectAsync(_frame(), timestampMilliseconds: 2);
      final disposal = task.dispose();
      expect(identical(task.dispose(), disposal), isTrue);
      expect(
        () => task.detectAsync(_frame(), timestampMilliseconds: 3),
        throwsStateError,
      );
      await _settle();
      expect(backend.disposed, isFalse);
      backend.finish();
      await _settle();
      expect(backend.calls.map((c) => c.timestamp), [0, 2]);
      backend.finish();
      await disposal;
      await _settle();
      expect(events, ['result 0', 'result 2', 'done']);
      expect(backend.disposed, isTrue);
      expect(task.droppedFrames, 1);
    });

    test('disposal with nothing submitted closes the stream', () async {
      final task = await open();
      final done = task.results.toList();
      await task.dispose();
      expect(await done, isEmpty);
      expect(backend.disposed, isTrue);
    });

    test('a deferred frame is made when it starts, and a dropped one '
        'never', () async {
      final task = await open();
      final made = <int>[];
      VisionImage deferred(int timestamp) => VisionImage.deferred(() {
        made.add(timestamp);
        return _frame(timestamp + 1);
      });
      final results = <int?>[];
      task.results.listen((r) => results.add(r.timestampMilliseconds));
      for (var i = 0; i < 4; i++) {
        task.detectAsync(deferred(i), timestampMilliseconds: i);
      }
      await _settle();
      expect(made, [0], reason: 'frame 3 waits unmade; 1 and 2 were dropped');
      expect(task.droppedFrames, 2);
      backend.finish();
      await _settle();
      expect(made, [0, 3]);
      expect(backend.calls.map((c) => c.width), [1, 4]);
      backend.finish();
      await task.dispose();
      expect(results, [0, 3]);
    });

    test("a result reaches the listener before the queued frame's "
        'producer runs', () async {
      final task = await open();
      final order = <String>[];
      task.results.listen(
        (r) => order.add('result ${r.timestampMilliseconds}'),
      );
      for (var i = 0; i < 2; i++) {
        task.detectAsync(
          VisionImage.deferred(() {
            order.add('convert $i');
            return _frame();
          }),
          timestampMilliseconds: i,
        );
      }
      await _settle();
      backend.finish();
      await _settle();
      backend.finish();
      await task.dispose();
      expect(order, ['convert 0', 'result 0', 'convert 1', 'result 1']);
    });

    test('an asynchronous producer is awaited', () async {
      final task = await open();
      final result = task.results.first;
      task.detectAsync(
        VisionImage.deferred(() async {
          await Future<void>.delayed(const Duration(milliseconds: 5));
          return _frame(7);
        }),
        timestampMilliseconds: 0,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      backend.finish();
      expect((await result).imageWidth, 7);
      await task.dispose();
    });

    test("a producer's error fails the frame and the task", () async {
      final task = await open();
      final errors = <Object>[];
      final done = Completer<void>();
      task.results.listen((_) {}, onError: errors.add, onDone: done.complete);
      task.detectAsync(
        VisionImage.deferred(() => throw StateError('no planes')),
        timestampMilliseconds: 0,
      );
      await done.future;
      expect(
        errors.single,
        isA<TaskException>().having(
          (e) => e.message,
          'message',
          contains('no planes'),
        ),
      );
      expect(backend.calls, isEmpty);
      expect(
        () => task.detectAsync(_frame(), timestampMilliseconds: 1),
        throwsA(same(errors.single)),
      );
      await task.dispose();
    });

    test('image and video mode refuse a deferred image', () async {
      final image = await open(RunningMode.image);
      final video = await open(RunningMode.video);
      final deferred = VisionImage.deferred(_frame);
      await expectLater(image.detect(deferred), throwsArgumentError);
      await expectLater(
        video.detectForVideo(deferred, timestampMilliseconds: 0),
        throwsArgumentError,
      );
      // The refused frame reserved no timestamp.
      final accepted = video.detectForVideo(_frame(), timestampMilliseconds: 0);
      await _settle();
      expect(backend.calls, hasLength(1));
      backend.finish();
      await accepted;
      await image.dispose();
      await video.dispose();
    });

    test('the other modes have no results and no live submissions', () async {
      final image = await open(RunningMode.image);
      final video = await open(RunningMode.video);
      final live = await open();
      final mode = isA<StateError>().having(
        (e) => e.message,
        'message',
        contains('requires liveStream mode'),
      );
      expect(() => image.results, throwsA(mode));
      expect(() => video.results, throwsA(mode));
      expect(
        () => video.detectAsync(_frame(), timestampMilliseconds: 0),
        throwsA(mode),
      );
      expect(image.droppedFrames, 0);
      expect(
        () => live.detectForVideo(_frame(), timestampMilliseconds: 0),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('created in liveStream mode'),
          ),
        ),
      );
      expect(() => live.detect(_frame()), throwsStateError);
      for (final task in [image, video, live]) {
        await task.dispose();
      }
    });
  });

  group('every task', () {
    final region = VisionRegionOfInterest(
      left: 0.1,
      top: 0.2,
      right: 0.8,
      bottom: 0.9,
    );

    /// Installs a backend that answers [result] at once through [install],
    /// opens a task with [open], submits one frame at timestamp 7 with
    /// [submit] and returns what the backend received, after checking the
    /// result arrived on [results].
    Future<_Call> one<T extends VisionTask, R>(
      void Function(_Backend<R>?) install,
      R result,
      Future<T> Function(RunningMode) open,
      Stream<R> Function(T) results,
      void Function(T, VisionImage) submit,
    ) async {
      final fake = _Backend<R>((call, seen) => result)..immediate = true;
      install(fake);
      addTearDown(() => install(null));
      final task = await open(RunningMode.liveStream);
      final received = results(task).first;
      submit(task, _frame());
      expect(await received, same(result));
      await task.dispose();
      return fake.calls.single;
    }

    test(
      'each submits through its own method and delivers its results',
      () async {
        final calls = [
          await one<FaceDetector, FaceDetectorResult>(
            (b) =>
                faceDetectorBackendFactory = b == null ? null : (_) async => b,
            FaceDetectorResult(
              imageWidth: 1,
              imageHeight: 1,
              detections: const [],
            ),
            (mode) => FaceDetector.create(
              FaceDetectorOptions(modelBytes: _model, runningMode: mode),
            ),
            (t) => t.results,
            (t, f) => t.detectAsync(f, timestampMilliseconds: 7),
          ),
          await one<FaceLandmarker, FaceLandmarkerResult>(
            (b) => faceLandmarkerBackendFactory = b == null
                ? null
                : (_) async => b,
            FaceLandmarkerResult(
              imageWidth: 1,
              imageHeight: 1,
              faceLandmarks: const [],
              faceBlendshapes: const [],
              facialTransformationMatrixes: const [],
            ),
            (mode) => FaceLandmarker.create(
              FaceLandmarkerOptions(modelBytes: _model, runningMode: mode),
            ),
            (t) => t.results,
            (t, f) => t.detectAsync(f, timestampMilliseconds: 7),
          ),
          await one<HandLandmarker, HandLandmarkerResult>(
            (b) => handLandmarkerBackendFactory = b == null
                ? null
                : (_) async => b,
            HandLandmarkerResult(
              handedness: const [],
              handLandmarks: const [],
              handWorldLandmarks: const [],
              imageWidth: 1,
              imageHeight: 1,
            ),
            (mode) => HandLandmarker.create(
              HandLandmarkerOptions(modelBytes: _model, runningMode: mode),
            ),
            (t) => t.results,
            (t, f) => t.detectAsync(f, timestampMilliseconds: 7),
          ),
          await one<GestureRecognizer, GestureRecognizerResult>(
            (b) => gestureRecognizerBackendFactory = b == null
                ? null
                : (_) async => b,
            GestureRecognizerResult(
              gestures: const [],
              handedness: const [],
              handLandmarks: const [],
              handWorldLandmarks: const [],
              imageWidth: 1,
              imageHeight: 1,
            ),
            (mode) => GestureRecognizer.create(
              GestureRecognizerOptions(modelBytes: _model, runningMode: mode),
            ),
            (t) => t.results,
            (t, f) => t.recognizeAsync(f, timestampMilliseconds: 7),
          ),
          await one<PoseLandmarker, PoseLandmarkerResult>(
            (b) => poseLandmarkerBackendFactory = b == null
                ? null
                : (_) async => b,
            PoseLandmarkerResult(
              poseLandmarks: const [],
              poseWorldLandmarks: const [],
              imageWidth: 1,
              imageHeight: 1,
            ),
            (mode) => PoseLandmarker.create(
              PoseLandmarkerOptions(modelBytes: _model, runningMode: mode),
            ),
            (t) => t.results,
            (t, f) => t.detectAsync(f, timestampMilliseconds: 7),
          ),
          await one<HolisticLandmarker, HolisticLandmarkerResult>(
            (b) => holisticLandmarkerBackendFactory = b == null
                ? null
                : (_) async => b,
            HolisticLandmarkerResult(
              faceLandmarks: const [],
              poseLandmarks: const [],
              poseWorldLandmarks: const [],
              leftHandLandmarks: const [],
              rightHandLandmarks: const [],
              leftHandWorldLandmarks: const [],
              rightHandWorldLandmarks: const [],
              imageWidth: 1,
              imageHeight: 1,
            ),
            (mode) => HolisticLandmarker.create(
              HolisticLandmarkerOptions(modelBytes: _model, runningMode: mode),
            ),
            (t) => t.results,
            (t, f) => t.detectAsync(f, timestampMilliseconds: 7),
          ),
          await one<ObjectDetector, ObjectDetectorResult>(
            (b) => objectDetectorBackendFactory = b == null
                ? null
                : (_) async => b,
            ObjectDetectorResult(
              imageWidth: 1,
              imageHeight: 1,
              detections: const [],
            ),
            (mode) => ObjectDetector.create(
              ObjectDetectorOptions(modelBytes: _model, runningMode: mode),
            ),
            (t) => t.results,
            (t, f) => t.detectAsync(f, timestampMilliseconds: 7),
          ),
          await one<ImageClassifier, ImageClassifierResult>(
            (b) => imageClassifierBackendFactory = b == null
                ? null
                : (_) async => b,
            ImageClassifierResult(
              classifications: const [],
              imageWidth: 1,
              imageHeight: 1,
            ),
            (mode) => ImageClassifier.create(
              ImageClassifierOptions(modelBytes: _model, runningMode: mode),
            ),
            (t) => t.results,
            (t, f) => t.classifyAsync(
              f,
              timestampMilliseconds: 7,
              regionOfInterest: region,
            ),
          ),
          await one<ImageEmbedder, ImageEmbedderResult>(
            (b) =>
                imageEmbedderBackendFactory = b == null ? null : (_) async => b,
            ImageEmbedderResult(
              embeddings: const [],
              imageWidth: 1,
              imageHeight: 1,
            ),
            (mode) => ImageEmbedder.create(
              ImageEmbedderOptions(modelBytes: _model, runningMode: mode),
            ),
            (t) => t.results,
            (t, f) => t.embedAsync(
              f,
              timestampMilliseconds: 7,
              regionOfInterest: region,
            ),
          ),
          await one<ImageSegmenter, ImageSegmenterResult>(
            (b) => imageSegmenterBackendFactory = b == null
                ? null
                : (_) async => b,
            ImageSegmenterResult(imageWidth: 1, imageHeight: 1),
            (mode) => ImageSegmenter.create(
              ImageSegmenterOptions(modelBytes: _model, runningMode: mode),
            ),
            (t) => t.results,
            (t, f) => t.segmentAsync(f, timestampMilliseconds: 7),
          ),
        ];
        expect(calls.map((c) => c.timestamp), everyElement(7));
        // Only the classifier and the embedder take a region of interest, as
        // in Google's runtime; the other methods have no such parameter.
        expect(
          [for (final c in calls) c.region != null],
          [false, false, false, false, false, false, false, true, true, false],
        );
        expect(calls[7].region, same(region));
        expect(calls[8].region, same(region));
      },
    );
  });

  group('native worker', () {
    late ReceivePort events;
    late List<Object?> seen;
    setUp(() {
      events = ReceivePort();
      seen = [];
      events.listen(seen.add);
    });
    tearDown(() => events.close());

    test('a dropped frame never reaches the worker isolate', () async {
      final runner = await VisionTaskRunner.open<int, _Options>(
        _Options(events.sendPort),
        name: 'Slow',
        backend: null,
        native: _Slow.new,
      );
      final results = <int>[];
      runner.results.listen(results.add);
      for (var i = 0; i < 6; i++) {
        // Deferred, so a producer that reached the worker would fail to send.
        runner.liveStream(VisionImage.deferred(_frame), 0, i);
      }
      await runner.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      // Frame 0 ran at once, frame 5 waited; 1 to 4 never left this isolate.
      expect(seen, [0, 5, 'closed']);
      expect(results, [0, 5]);
      expect(runner.droppedFrames, 4);
    });

    test('a failed frame poisons the task and the worker still closes '
        'its native task', () async {
      final runner = await VisionTaskRunner.open<int, _Options>(
        _Options(events.sendPort, failAt: 1),
        name: 'Failing',
        backend: null,
        native: _Slow.new,
      );
      final errors = <Object>[];
      final done = Completer<void>();
      runner.results.listen((_) {}, onError: errors.add, onDone: done.complete);
      runner.liveStream(_frame(), 0, 0);
      runner.liveStream(_frame(), 0, 1);
      await done.future;
      expect(errors.single, isA<TaskException>());
      expect(() => runner.liveStream(_frame(), 0, 2), throwsA(errors.single));
      await runner.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(seen, [0, 1, 'closed']);
    });
  });
}

/// Options whose native task reports to [events] on the worker isolate.
final class _Options extends VisionTaskOptions {
  _Options(this.events, {this.failAt})
    : super(modelBytes: Uint8List(1), runningMode: RunningMode.liveStream);
  final SendPort events;

  /// The timestamp whose frame fails, if any.
  final int? failAt;
}

/// Takes 100 ms a frame on the worker isolate, as a slow model would, and
/// reports each timestamp it receives.
final class _Slow implements NativeVisionTask<int> {
  _Slow(this.options);
  final _Options options;

  @override
  int process(VisionTaskInput input) {
    final timestamp = input.$3!;
    options.events.send(timestamp);
    sleep(const Duration(milliseconds: 100));
    if (timestamp == options.failAt) throw const TaskException('failed');
    return timestamp;
  }

  var _closed = false;

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    options.events.send('closed');
  }
}
