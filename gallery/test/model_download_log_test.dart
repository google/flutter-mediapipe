import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mediapipe_gallery/model_download_log.dart';

final _url = Uri.parse('https://example.com/models/model.task');
final _megabyte = Uint8List(1000 * 1000);

/// Sends a request through a [ModelDownloadLog] over a host that answers with
/// [body], and collects what it logs in [lines].
Future<http.StreamedResponse> _get(
  Stream<List<int>> body,
  List<String> lines, {
  int? size,
}) => ModelDownloadLog(
  MockClient.streaming(
    (_, _) async => http.StreamedResponse(body, 200, contentLength: size),
  ),
  lines.add,
).send(http.Request('GET', _url));

Stream<List<int>> _megabytes(int count) async* {
  for (var i = 0; i < count; i++) {
    yield _megabyte;
  }
}

void main() {
  test(
    'logs the answer, every 100 MB and the end, passing every byte',
    () async {
      final lines = <String>[];
      final response = await _get(_megabytes(250), lines, size: 250000000);
      expect(lines, ['MODEL_DOWNLOAD model.task: HTTP 200, 250 MB']);
      expect(await response.stream.length, 250);
      expect(lines.map((line) => line.replaceAll(RegExp(r'\d+ s'), 'T')), [
        'MODEL_DOWNLOAD model.task: HTTP 200, 250 MB',
        'MODEL_DOWNLOAD model.task: 100 of 250 MB in T',
        'MODEL_DOWNLOAD model.task: 200 of 250 MB in T',
        'MODEL_DOWNLOAD model.task: 250 of 250 MB in T, ended',
      ]);
    },
  );

  test('passes the bytes on unchanged, with the response\'s fields', () async {
    final response = await ModelDownloadLog(
      MockClient.streaming(
        (_, _) async => http.StreamedResponse(
          Stream.value([1, 2, 3]),
          206,
          contentLength: 3,
          headers: {'content-range': 'bytes 7-9/10'},
        ),
      ),
      (_) {},
    ).send(http.Request('GET', _url));
    expect(response.statusCode, 206);
    expect(response.contentLength, 3);
    expect(response.headers['content-range'], 'bytes 7-9/10');
    expect(await response.stream.toBytes(), [1, 2, 3]);
  });

  test('says a size only when the host gave one', () async {
    final lines = <String>[];
    final response = await _get(_megabytes(100), lines);
    await response.stream.drain<void>();
    expect(lines.first, 'MODEL_DOWNLOAD model.task: HTTP 200');
    expect(lines[1], startsWith('MODEL_DOWNLOAD model.task: 100 MB in '));
  });

  test('passes a dropped connection on, without calling it ended', () async {
    final lines = <String>[];
    final body = StreamController<List<int>>();
    final response = await _get(body.stream, lines);
    body.addError(http.ClientException('dropped'));
    await expectLater(
      response.stream.drain<void>(),
      throwsA(isA<http.ClientException>()),
    );
    expect(lines, hasLength(1));
  });

  // The fake clock would run any timer in the client: a line printed without
  // new bytes would hide a stalled download from the release suite's limit.
  testWidgets('goes quiet while a download is stalled', (tester) async {
    final lines = <String>[];
    final body = StreamController<List<int>>();
    final response = await _get(body.stream, lines);
    final subscription = response.stream.listen((_) {});
    addTearDown(subscription.cancel);
    addTearDown(body.close);
    for (var i = 0; i < 100; i++) {
      body.add(_megabyte);
    }
    await tester.pump();
    expect(lines, hasLength(2));
    await tester.pump(const Duration(hours: 1));
    expect(lines, hasLength(2));
  });

  // verified_download.dart gives up on a stalled body by cancelling this
  // stream, which must reach the connection underneath.
  test('passes a cancel on to a stalled connection', () async {
    var cancelled = false;
    final body = StreamController<List<int>>(
      onCancel: () {
        cancelled = true;
      },
    );
    final response = await _get(body.stream, []);
    unawaited(response.stream.listen((_) {}).cancel());
    await pumpEventQueue();
    expect(cancelled, isTrue);
  });
}
