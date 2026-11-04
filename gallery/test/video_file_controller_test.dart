import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediapipe_gallery/live/live_task.dart';
import 'package:mediapipe_gallery/live/task_settings.dart';
import 'package:mediapipe_gallery/live/video_file_controller.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('video_frames');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<String> calls;
  late List<int> timestamps;
  late int nextFrame;

  setUp(() {
    calls = [];
    nextFrame = 0;
    // 33.333 and 33.4 ms both round to 33, so the second repeats the first.
    timestamps = [0, 33333, 33400, 66667];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'open':
          return {
            'id': 1,
            'width': 2,
            'height': 2,
            'rotation': 270,
            'durationUs': 100000,
            'frameRate': 30.0,
          };
        case 'next':
          if (nextFrame == timestamps.length) return null;
          return {
            'timestampUs': timestamps[nextFrame++],
            'width': 2,
            'height': 2,
            'layout': 'bgra',
            'planes': [
              [Uint8List(16), 8, 4],
            ],
          };
      }
      return null;
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  // Waits for the file and the task to be released before the mocked
  // channel goes away.
  Future<void> finish(VideoFileController video) async {
    await video.close();
    video.dispose();
  }

  Future<void> settle(VideoFileController video) async {
    for (var i = 0; i < 200 && (video.loading || video.playing); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  test('runs every frame in video mode with its own timestamp', () async {
    final task = _FakeTask();
    final video = VideoFileController(task);
    await video.open(
      '/clips/a.mp4',
      'a.mp4',
      delegate: Delegate.cpu,
      model: () async => Uint8List(0),
    );
    await settle(video);
    expect(task.modes, [RunningMode.video]);
    expect(task.timestamps, [0, 33, 67]);
    expect(task.rotations, everyElement(270));
    expect(video.done, isTrue);
    expect(video.error, isNull);
    expect(video.frames, 3);
    expect(video.duplicates, 1);
    expect(video.resultsMatchFrames, isTrue);
    expect(video.expectedFrames, 3);
    expect(video.rotationDegrees, 270);
    expect(video.picture, isNotNull);
    await finish(video);
    expect(task.closed, 1);
    expect(calls.where((method) => method == 'close'), hasLength(1));
  });

  test('a result for another timestamp is reported', () async {
    final task = _FakeTask()..timestampOffset = 1;
    final video = VideoFileController(task);
    await video.open(
      '/clips/a.mp4',
      'a.mp4',
      delegate: Delegate.cpu,
      model: () async => Uint8List(0),
    );
    await settle(video);
    expect(video.frames, 3);
    expect(video.resultsMatchFrames, isFalse);
    await finish(video);
  });

  test('pause stops after the frame in progress; play continues', () async {
    final task = _FakeTask()..gate = Completer<void>();
    final video = VideoFileController(task);
    await video.open(
      '/clips/a.mp4',
      'a.mp4',
      delegate: Delegate.cpu,
      model: () async => Uint8List(0),
    );
    while (task.timestamps.isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    video.pause();
    task.gate!.complete();
    task.gate = null;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(video.frames, 1);
    expect(video.playing, isFalse);
    expect(video.done, isFalse);
    video.play();
    await settle(video);
    expect(task.timestamps, [0, 33, 67]);
    expect(video.done, isTrue);
    await finish(video);
  });

  test('restart closes the task and opens a new one from frame one', () async {
    final task = _FakeTask();
    final video = VideoFileController(task);
    await video.open(
      '/clips/a.mp4',
      'a.mp4',
      delegate: Delegate.cpu,
      model: () async => Uint8List(0),
    );
    await settle(video);
    nextFrame = 0;
    await video.restart();
    await settle(video);
    expect(task.modes, [RunningMode.video, RunningMode.video]);
    expect(task.closed, 1);
    expect(task.timestamps, [0, 33, 67, 0, 33, 67]);
    expect(calls.where((method) => method == 'open'), hasLength(2));
    expect(video.frames, 3);
    await finish(video);
  });

  test('a refused GPU runs the file on CPU with a notice', () async {
    final task = _FakeTask()..refuseGpu = true;
    final video = VideoFileController(task);
    await video.open(
      '/clips/a.mp4',
      'a.mp4',
      delegate: Delegate.gpu,
      model: () async => Uint8List(0),
    );
    await settle(video);
    expect(task.delegates, [Delegate.gpu, Delegate.cpu]);
    expect(video.delegate, Delegate.cpu);
    expect(video.notice, startsWith('GPU unavailable, using CPU.'));
    expect(video.frames, 3);
    await finish(video);
  });

  test('a decoder failure is shown and releases the task', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'open', message: 'No video track.');
    });
    final task = _FakeTask();
    final video = VideoFileController(task);
    await video.open(
      '/clips/a.m4a',
      'a.m4a',
      delegate: Delegate.cpu,
      model: () async => Uint8List(0),
    );
    expect(video.error, contains('No video track.'));
    expect(video.playing, isFalse);
    expect(task.closed, 1);
    await finish(video);
  });
}

/// A video mode task that answers each frame with a Face Detector result for
/// that frame's timestamp, plus [timestampOffset].
final class _FakeTask implements LiveTask<Object?> {
  final modes = <RunningMode>[];
  final delegates = <Delegate>[];
  final timestamps = <int>[];
  final rotations = <int>[];
  int closed = 0;
  int timestampOffset = 0;
  bool refuseGpu = false;

  /// When set, the next frame waits for it.
  Completer<void>? gate;

  @override
  String get name => 'Fake';

  @override
  TaskSettingValues get settings => throw UnimplementedError();

  @override
  Future<void> open(
    Delegate delegate,
    Uint8List modelBytes, {
    RunningMode mode = RunningMode.liveStream,
  }) async {
    delegates.add(delegate);
    if (refuseGpu && delegate == Delegate.gpu) {
      throw const TaskException('No GPU here.', gpuUnavailable: true);
    }
    modes.add(mode);
  }

  @override
  Future<Object?> detectFrame(
    VisionImage frame,
    int timestampMilliseconds, {
    required int rotationDegrees,
  }) async {
    timestamps.add(timestampMilliseconds);
    rotations.add(rotationDegrees);
    await gate?.future;
    return FaceDetectorResult(
      imageWidth: 2,
      imageHeight: 2,
      detections: const [],
      timestampMilliseconds: timestampMilliseconds + timestampOffset,
    );
  }

  @override
  Future<void> close() async => closed++;

  @override
  Future<Object?> detectImage(VisionImage image) => throw UnimplementedError();

  @override
  void submit(
    VisionImage frame,
    int timestampMilliseconds, {
    required int rotationDegrees,
  }) => throw UnimplementedError();

  @override
  Stream<LiveResult<Object?>> get results => throw UnimplementedError();

  @override
  int get droppedFrames => 0;
}
