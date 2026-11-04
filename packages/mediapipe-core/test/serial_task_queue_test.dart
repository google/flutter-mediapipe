import 'dart:async';

import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_core/platform_interface.dart'
    show SerialTaskQueue, taskException;
import 'package:test/test.dart';

void main() {
  test('requests run one at a time, in the order they were added', () async {
    final queue = SerialTaskQueue('Task');
    final events = <String>[];
    Future<int> request(int id, Duration delay) => queue.add(() async {
      events.add('start $id');
      await Future<void>.delayed(delay);
      events.add('end $id');
      return id;
    });
    final results = await Future.wait([
      request(1, const Duration(milliseconds: 20)),
      request(2, Duration.zero),
      request(3, const Duration(milliseconds: 5)),
    ]);
    expect(results, [1, 2, 3]);
    expect(events, [
      'start 1',
      'end 1',
      'start 2',
      'end 2',
      'start 3',
      'end 3',
    ]);
  });

  test('a failure is reported once and does not stop the next', () async {
    final queue = SerialTaskQueue('Task');
    final failed = queue.add<int>(() => throw StateError('native'));
    final next = queue.add(() => 7);
    await expectLater(
      failed,
      throwsA(
        isA<TaskException>()
            .having((e) => e.message, 'message', 'Bad state: native')
            .having((e) => e.cause, 'cause', isA<StateError>()),
      ),
    );
    expect(await next, 7);
  });

  test("MediaPipe's own failures pass through unchanged", () {
    const runtime = RuntimeUnavailableException('none', fix: 'install');
    const task = TaskException('bad model', statusCode: 3);
    expect(taskException(runtime), same(runtime));
    expect(taskException(task), same(task));
    expect(
      taskException(ArgumentError('x')),
      isA<TaskException>().having(
        (e) => e.cause,
        'cause',
        isA<ArgumentError>(),
      ),
    );
  });

  test('close waits for accepted requests, then releases once', () async {
    final queue = SerialTaskQueue('DecisionMaker');
    final gate = Completer<void>();
    var released = 0;
    final pending = queue.add(() async {
      await gate.future;
      return 'done';
    });
    final closed = queue.close(() => released++);
    expect(identical(queue.close(() => released++), closed), isTrue);
    await expectLater(
      queue.add(() => 1),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          'DecisionMaker has been disposed.',
        ),
      ),
    );
    expect(released, 0);
    gate.complete();
    expect(await pending, 'done');
    await closed;
    expect(released, 1);
  });

  test('a failed release is reported as a TaskException', () async {
    final queue = SerialTaskQueue('Task');
    await expectLater(
      queue.close(() => throw StateError('close')),
      throwsA(isA<TaskException>()),
    );
  });
}
