import 'dart:async';

import 'package:http/http.dart' as http;

/// An HTTP client that says how a model's download is going: a download can
/// take minutes, and the test suites print nothing meanwhile.
///
/// It logs only when an answer or bytes arrive, never on a timer, so a stopped
/// download goes quiet. tool/ci/run_release_suite.py reads these lines: only
/// one with more megabytes than the last counts as a sign of life.
final class ModelDownloadLog extends http.BaseClient {
  ModelDownloadLog(this._inner, this._log);

  static const _megabyte = 1000 * 1000;

  /// How many megabytes pass between two lines, so a model logs a few lines.
  static const _step = 100;

  final http.Client _inner;
  final void Function(String line) _log;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(request);
    final name = 'MODEL_DOWNLOAD ${request.url.pathSegments.last}';
    final size = response.contentLength;
    _log(
      '$name: HTTP ${response.statusCode}'
      '${size == null ? '' : ', ${size ~/ _megabyte} MB'}',
    );
    final clock = Stopwatch()..start();
    var received = 0;
    var told = 0;
    String sofar() =>
        '${received ~/ _megabyte}${size == null ? '' : ' of ${size ~/ _megabyte}'} '
        'MB in ${clock.elapsed.inSeconds} s';
    return http.StreamedResponse(
      // Not an async* generator: cancelling one waits for its next event, so
      // a stalled stream, which the download's own timeout drops, stays open.
      response.stream.transform(
        StreamTransformer.fromHandlers(
          handleData: (chunk, sink) {
            received += chunk.length;
            if (received ~/ (_step * _megabyte) > told) {
              told = received ~/ (_step * _megabyte);
              _log('$name: ${sofar()}');
            }
            sink.add(chunk);
          },
          handleDone: (sink) {
            _log('$name: ${sofar()}, ended');
            sink.close();
          },
        ),
      ),
      response.statusCode,
      contentLength: size,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  @override
  void close() => _inner.close();
}
