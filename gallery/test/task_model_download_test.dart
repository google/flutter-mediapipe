import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mediapipe_gallery/live/task_models.dart';

void main() {
  final body = utf8.encode('model bytes');
  TaskModel model(String path) =>
      TaskModel('Test', path, sha256.convert(body).toString(), body.length);

  // package:http is what downloads on the web, where Flutter's
  // NetworkAssetBundle needs dart:io's HttpClient and fails.
  test('a model downloads through package:http from Google\'s URL', () async {
    final asked = <Uri>[];
    final bytes = await http.runWithClient(
      () => downloadModel(model('test/a/1/a.tflite')),
      () => MockClient((request) async {
        asked.add(request.url);
        return http.Response.bytes(body, 200);
      }),
    );
    expect(bytes, body);
    expect(asked, [
      Uri.parse(
        'https://storage.googleapis.com/mediapipe-models/test/a/1/a.tflite',
      ),
    ]);
  });

  test('a download that is not the pinned model is refused', () async {
    final pinned = TaskModel('Other', 'test/b/1/b.tflite', '0' * 64, 1);
    await expectLater(
      http.runWithClient(
        () => downloadModel(pinned),
        () => MockClient((_) async => http.Response.bytes(body, 200)),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('an HTTP error is refused', () async {
    final missing = TaskModel('Missing', 'test/c/1/c.tflite', '1' * 64, 1);
    await expectLater(
      http.runWithClient(
        () => downloadModel(missing),
        () => MockClient((_) async => http.Response('gone', 404)),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('HTTP 404'),
        ),
      ),
    );
  });
}
