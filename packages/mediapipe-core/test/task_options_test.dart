import 'dart:io';
import 'dart:typed_data';

import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_core/platform_interface.dart';
import 'package:test/test.dart';

const _pin = DownloadAsset(
  url: 'https://models.example/task/1/model.tflite',
  sha256: '0000000000000000000000000000000000000000000000000000000000000000',
);

final class _Options extends TaskOptions {
  _Options({super.model, super.modelPath, super.modelBytes, super.delegate})
    : super(family: 'mediapipe_test', registry: const {'model': _pin});
}

void main() {
  test('exactly one model source is accepted, the same way everywhere', () {
    expect(() => _Options(), throwsArgumentError);
    expect(
      () => _Options(model: _pin, modelPath: 'model.tflite'),
      throwsArgumentError,
    );
    expect(() => _Options(modelPath: ''), throwsArgumentError);
    expect(() => _Options(modelPath: 'a\u0000b'), throwsArgumentError);
    expect(() => _Options(modelBytes: Uint8List(0)), throwsArgumentError);
    expect(_Options(modelPath: 'model.tflite').modelPath, 'model.tflite');
    expect(_Options(model: _pin).model, _pin);
    expect(_Options(model: _pin).delegate, Delegate.cpu);
    expect(
      _Options(model: _pin, delegate: Delegate.gpu).delegate,
      Delegate.gpu,
    );
  });

  test('model bytes are copied and read-only', () {
    final bytes = Uint8List.fromList([1, 2, 3]);
    final options = _Options(modelBytes: bytes);
    bytes[0] = 9;
    expect(options.modelBytes, [1, 2, 3]);
    expect(() => options.modelBytes![0] = 0, throwsUnsupportedError);
    expect(options.modelPath, isNull);
  });

  test('a runtime can hold the model in memory for a reopen', () {
    final options = _Options(modelPath: 'model.tflite');
    holdModelBytes(options, Uint8List.fromList([7]));
    expect(options.modelPath, isNull);
    expect(options.modelBytes, [7]);
    // Another options object is unaffected.
    expect(_Options(modelPath: 'model.tflite').modelBytes, isNull);
  });

  test('a pinned model that is not bundled names the pubspec entry', () async {
    final cache = await Directory.systemTemp.createTemp('mediapipe-options-');
    ModelStore.allowDownloads = false;
    ModelStore.debugBundledModels = (_) async => null;
    ModelStore.debugCacheDirectory = cache.path;
    addTearDown(() async {
      ModelStore.debugBundledModels = null;
      ModelStore.debugCacheDirectory = null;
      await cache.delete(recursive: true);
    });
    await expectLater(
      resolveTaskModel(_Options(model: _pin)),
      throwsA(
        isA<RuntimeUnavailableException>().having(
          (e) => e.fix,
          'fix',
          contains('Add model to hooks.user_defines.mediapipe_test.models'),
        ),
      ),
    );
    // A path or bytes resolve to themselves without touching the store.
    await resolveTaskModel(_Options(modelPath: 'model.tflite'));
  });
}
