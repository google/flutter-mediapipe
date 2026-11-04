@TestOn('vm')
library;

import 'dart:async';
import 'dart:isolate';

import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_core/task_worker.dart';
import 'package:test/test.dart';

/// Answers a request with it in capitals; 'fail' throws a StateError,
/// 'task' a TaskException, and 'die' ends the worker isolate. A stream of
/// 'n' emits 0 to n - 1. Reports each run and the close to [_log].
final class _Fake extends WorkerTask<String, String, int> {
  _Fake(this._log);
  final SendPort _log;

  @override
  String run(String input) {
    _log.send('run $input');
    switch (input) {
      case 'fail':
        throw StateError('native');
      case 'task':
        throw const TaskException('bad input', statusCode: 3);
      case 'die':
        Isolate.exit();
    }
    return input.toUpperCase();
  }

  @override
  Future<void> stream(String input, void Function(int update) emit) async {
    for (var i = 0; i < int.parse(input); i++) {
      emit(i);
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
  }

  @override
  void close() => _log.send('close');
}

WorkerTask<String, String, int> _fake(SendPort log) => _Fake(log);

WorkerTask<String, String, int> _unavailable(SendPort log) =>
    throw const RuntimeUnavailableException('No library.', fix: 'Add one.');

WorkerTask<String, String, int> _broken(SendPort log) =>
    throw StateError('constructor');

void main() {
  late ReceivePort log;
  late List<Object?> events;
  setUp(() {
    log = ReceivePort();
    events = [];
    log.listen(events.add);
  });
  tearDown(() => log.close());

  Future<TaskWorker<String, String, int>> started([
    void Function(MediaPipeException)? onFailure,
  ]) async {
    final worker = TaskWorker<String, String, int>('Fake', onFailure);
    await worker.start(log.sendPort, _fake);
    return worker;
  }

  test('requests run in call order, then one close', () async {
    final worker = await started();
    final results = Future.wait([worker.run('a'), worker.run('b')]);
    final disposal = worker.dispose();
    expect(identical(worker.dispose(), disposal), isTrue);
    await expectLater(
      worker.run('c'),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          'Fake has been disposed.',
        ),
      ),
    );
    expect(await results, ['A', 'B']);
    await disposal;
    await pumpEventQueue();
    expect(events, ['run a', 'run b', 'close']);
  });

  test('a failed request is reported, and the next one runs', () async {
    final worker = await started();
    await expectLater(
      worker.run('fail'),
      throwsA(
        isA<TaskException>().having((e) => e.cause, 'cause', isA<StateError>()),
      ),
    );
    await expectLater(
      worker.run('task'),
      throwsA(isA<TaskException>().having((e) => e.statusCode, 'status', 3)),
    );
    expect(await worker.run('ok'), 'OK');
    await worker.dispose();
  });

  test('a stream delivers its updates, and cancelling waits for it', () async {
    final worker = await started();
    expect(await worker.stream('3').toList(), [0, 1, 2]);
    final first = Completer<int>();
    late StreamSubscription<int> subscription;
    subscription = worker.stream('200').listen(first.complete);
    expect(await first.future, 0);
    await subscription.cancel();
    expect(await worker.run('after'), 'AFTER');
    await worker.dispose();
  });

  test('a task that cannot be made fails start with its error', () async {
    await expectLater(
      TaskWorker<String, String, int>('Fake').start(log.sendPort, _unavailable),
      throwsA(isA<RuntimeUnavailableException>()),
    );
    await expectLater(
      TaskWorker<String, String, int>('Fake').start(log.sendPort, _broken),
      throwsA(
        isA<TaskException>().having((e) => e.cause, 'cause', isA<StateError>()),
      ),
    );
  });

  test('a worker that dies fails its requests and every later one', () async {
    final heard = <MediaPipeException>[];
    final worker = await started(heard.add);
    final exited = isA<TaskException>().having(
      (e) => e.message,
      'message',
      'Fake worker exited.',
    );
    await expectLater(worker.run('die'), throwsA(exited));
    expect(heard, [exited]);
    await expectLater(worker.run('a'), throwsA(exited));
    expect(() => worker.stream('1'), throwsA(exited));
    await worker.dispose();
    expect(events, ['run die']);
  });
}
