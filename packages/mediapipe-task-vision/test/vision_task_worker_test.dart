import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:mediapipe_vision/mediapipe_vision.dart';
import 'package:mediapipe_vision/src/io/gpu_frame_budget.dart';
import 'package:mediapipe_vision/src/io/vision_task_worker.dart';
import 'package:mediapipe_vision/src/runner/native_interface.dart';
import 'package:test/test.dart';

/// Options whose fake native task reports opening and closing to [events].
final class _Options extends VisionTaskOptions {
  _Options(this.events, {super.delegate = Delegate.cpu, super.modelPath})
    : super(
        modelBytes: modelPath == null ? Uint8List(1) : null,
        runningMode: RunningMode.video,
      );
  final SendPort events;
}

/// Native tasks opened so far on this worker isolate.
var _opened = 0;

/// Answers every frame with its own number, so results show which native
/// task processed them.
final class _Native implements NativeVisionTask<int> {
  _Native(this.options, [String? source]) : number = ++_opened {
    options.events.send(
      source == null ? 'open $number' : 'open $number $source',
    );
  }

  final _Options options;
  final int number;
  var _closed = false;

  @override
  int process(VisionTaskInput input) => number;

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    options.events.send('close $number');
  }
}

_Native _open(_Options options) => _Native(options);

/// Opens once, then fails, as a GPU that disappeared would.
_Native _openOnce(_Options options) {
  if (_opened == 1) throw const TaskException('No GPU.');
  return _Native(options);
}

/// Opens the way MediaPipe does from a model path: the file must still exist.
_Native _openFromFile(_Options options) {
  if (options.modelPath case final path?) {
    if (!File(path).existsSync()) {
      throw TaskException('Unable to open file at $path');
    }
    return _Native(options, 'from its file');
  }
  return _Native(options, 'from ${options.modelBytes!.length} bytes');
}

/// 4x4 RGBA: 64 bytes for the GPU.
final _frame = VisionImage.fromPixels(
  pixels: Uint8List(64),
  width: 4,
  height: 4,
  format: VisionPixelFormat.rgba,
);

void main() {
  late ReceivePort events;
  late List<String> log;
  setUp(() {
    events = ReceivePort();
    log = [];
    events.listen((event) => log.add(event as String));
  });
  tearDown(() => events.close());

  /// Lets the worker's last messages arrive.
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 50));

  test('reopens the native task each time the budget is spent', () async {
    final worker = await VisionTaskWorker.create(
      _Options(events.sendPort),
      _open,
      'reopen',
      reopenAfterBytes: 128,
    );
    final answers = [
      for (var i = 0; i < 5; i++) await worker.processVideo(_frame, 0, i, null),
    ];
    await worker.dispose();
    await settle();
    expect(answers, [1, 1, 2, 2, 3]);
    expect(log, [
      'open 1',
      'close 1',
      'open 2',
      'close 2',
      'open 3',
      'close 3',
    ]);
  });

  test('keeps one native task without a budget', () async {
    final worker = await VisionTaskWorker.create(
      _Options(events.sendPort),
      _open,
      'no budget',
    );
    final answers = [
      for (var i = 0; i < 5; i++) await worker.processVideo(_frame, 0, i, null),
    ];
    await worker.dispose();
    await settle();
    expect(answers, [1, 1, 1, 1, 1]);
    expect(log, ['open 1', 'close 1']);
  });

  test('fails the task when reopening fails', () async {
    final worker = await VisionTaskWorker.create(
      _Options(events.sendPort),
      _openOnce,
      'reopen fails',
      reopenAfterBytes: 64,
    );
    expect(await worker.processVideo(_frame, 0, 0, null), 1);
    await expectLater(
      worker.processVideo(_frame, 0, 1, null),
      throwsA(
        isA<TaskException>().having((e) => e.message, 'message', 'No GPU.'),
      ),
    );
    await worker.dispose();
    await settle();
    expect(log, ['open 1', 'close 1']);
  });

  test('reopens from memory after the model file is deleted', () async {
    final folder = Directory.systemTemp.createTempSync('vision-worker-model-');
    addTearDown(() => folder.deleteSync(recursive: true));
    final model = File('${folder.path}/model.tflite')
      ..writeAsBytesSync([1, 2, 3]);
    final worker = await VisionTaskWorker.create(
      _Options(events.sendPort, modelPath: model.path),
      _openFromFile,
      'model file deleted',
      reopenAfterBytes: 64,
    );
    // MediaPipe has read the file once the task exists, so apps may delete it.
    model.deleteSync();
    final answers = [
      for (var i = 0; i < 3; i++) await worker.processVideo(_frame, 0, i, null),
    ];
    await worker.dispose();
    await settle();
    expect(answers, [1, 2, 3]);
    expect(log, [
      'open 1 from its file',
      'close 1',
      'open 2 from 3 bytes',
      'close 2',
      'open 3 from 3 bytes',
      // The budget is spent again by the last frame, but the task reopens
      // only for a next one.
      'close 3',
    ]);
  });

  group('GpuFrameBudget', () {
    test('applies to GPU tasks on macOS only', () {
      expect(
        GpuFrameBudget(
          _Options(events.sendPort, delegate: Delegate.gpu),
        ).limitBytes,
        Platform.isMacOS ? 1 << 30 : isNull,
      );
      expect(GpuFrameBudget(_Options(events.sendPort)).limitBytes, isNull);
      // Face Detector's LiteRT GPU can keep twice each frame.
      expect(
        GpuFrameBudget(
          FaceDetectorOptions(modelPath: 'face.tflite', delegate: Delegate.gpu),
        ).limitBytes,
        Platform.isMacOS ? 1 << 29 : isNull,
      );
    });

    test('counts four bytes a pixel, and a 12 MP photo for a file', () {
      final budget = GpuFrameBudget(
        _Options(events.sendPort),
        limitBytes: 4000 * 3000 * 4 + 64,
      );
      expect(budget.spend(VisionImage.fromFile('photo.jpg')), isFalse);
      expect(budget.spend(_frame), isTrue);
      expect(budget.spend(_frame), isFalse);
    });
  });
}
