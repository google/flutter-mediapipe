import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_core/native_assets.dart'
    show DownloadException, downloadVerified;
import 'package:mediapipe_core/src/verified_download.dart' show retryWait;
import 'package:test/test.dart';

void main() {
  late HttpServer server;
  late Directory root;
  late int requests;
  final good = utf8.encode('small verified model');
  final digest = sha256.convert(good).toString();

  setUp(() async {
    requests = 0;
    final wait = retryWait;
    retryWait = (_) async {};
    addTearDown(() => retryWait = wait);
    root = await Directory.systemTemp.createTemp('mediapipe-model-store-');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requests++;
      switch (request.uri.path) {
        case '/good':
          request.response.add(good);
        case '/bad':
          request.response.add(utf8.encode('wrong'));
        case '/partial':
          request.response.contentLength = good.length + 10;
          request.response.add(good);
          try {
            await request.response.close();
          } on HttpException {
            // The deliberately truncated body violates its announced size.
          }
          return;
        default:
          request.response.statusCode = 404;
      }
      await request.response.close();
    });
  });
  tearDown(() async {
    await server.close(force: true);
    await root.delete(recursive: true);
  });

  String url(String path) => 'http://127.0.0.1:${server.port}/$path';
  DownloadAsset asset(String primary, [List<String> mirrors = const []]) =>
      DownloadAsset(
        url: url(primary),
        mirrors: mirrors.map(url).toList(),
        sha256: digest,
      );

  test('primary fails and mirror succeeds', () async {
    final file = await downloadVerified(
      asset('missing', ['good']),
      File('${root.path}/runtime'),
    );
    expect(await file.readAsBytes(), good);
    expect(requests, 2);
  });

  test('all failures include every URL and reason', () async {
    final pin = asset('missing', ['bad']);
    await expectLater(
      downloadVerified(pin, File('${root.path}/runtime')),
      throwsA(
        isA<DownloadException>().having(
          (e) => e.toString(),
          'message',
          allOf(
            contains(pin.url),
            contains(pin.mirrors.single),
            contains('HTTP 404'),
            contains('SHA-256 mismatch'),
          ),
        ),
      ),
    );
  });

  test('wrong mirror bytes never become a file', () async {
    await expectLater(
      downloadVerified(asset('missing', ['bad']), File('${root.path}/runtime')),
      throwsA(isA<DownloadException>()),
    );
    expect(File('${root.path}/runtime').existsSync(), isFalse);
  });

  test('offline directory hit and wrong bytes', () async {
    final source = await Directory('${root.path}/source').create();
    await File('${source.path}/$digest').writeAsBytes(good);
    final file = await downloadVerified(
      asset('missing'),
      File('${root.path}/runtime'),
      source: source.path,
    );
    expect(await file.readAsBytes(), good);
    expect(requests, 0);
    await file.delete();
    await File('${source.path}/$digest').writeAsString('wrong');
    await expectLater(
      downloadVerified(asset('missing'), file, source: source.path),
      throwsA(isA<DownloadException>()),
    );
    expect(file.existsSync(), isFalse);
  });

  test(
    'model cache survives offline and coalesces concurrent requests',
    () async {
      final store = ModelStore(cacheDirectory: '${root.path}/models');
      final pin = asset('good');
      final files = [
        for (final source in await Future.wait(
          List.generate(4, (_) => store.get(pin)),
        ))
          File(source.path!),
      ];
      expect(files.map((f) => f.path).toSet().length, 1);
      expect(
        files.first.uri.path,
        endsWith('/${digest.substring(0, 16)}/good'),
      );
      expect(requests, 1);
      await server.close(force: true);
      expect(await File((await store.get(pin)).path!).readAsBytes(), good);
      // Another pin for the same bytes finds the verified copy offline.
      final other = DownloadAsset(
        url: 'https://invalid.example/other.task',
        sha256: digest,
      );
      expect((await store.get(other)).path, files.first.path);
      expect((await store.find(other))!.path, files.first.path);
      await store.clear();
      expect(files.first.existsSync(), isFalse);
    },
  );

  test('two isolates share one locked download', () async {
    final path = '${root.path}/models';
    final pin = asset('good');
    final receivers = [ReceivePort(), ReceivePort()];
    for (final receiver in receivers) {
      await Isolate.spawn(_isolatedGet, (
        path,
        pin.url,
        pin.sha256,
        receiver.sendPort,
      ));
    }
    final paths = await Future.wait(
      receivers.map((port) => port.first.then((value) => value as String)),
    );
    for (final receiver in receivers) {
      receiver.close();
    }
    expect(paths[0], paths[1]);
    expect(requests, 1);
  });

  test('model mirror fallback and checksum failure', () async {
    final store = ModelStore(cacheDirectory: '${root.path}/models');
    expect(
      await File(
        (await store.get(asset('missing', ['good']))).path!,
      ).readAsBytes(),
      good,
    );
    await store.clear();
    await expectLater(
      store.get(asset('missing', ['bad'])),
      throwsA(isA<ModelDownloadException>()),
    );
  });

  test('prefetch downloads once, then get serves the cached copy', () async {
    final store = ModelStore(cacheDirectory: '${root.path}/models');
    await store.prefetch(asset('good'));
    expect(requests, 1);
    expect(
      await File((await store.get(asset('good'))).path!).readAsBytes(),
      good,
    );
    expect(requests, 1);
  });

  test('an unreachable host names the network setting it may need', () async {
    // A port nothing listens on, so every request is refused.
    final closed = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = closed.port;
    await closed.close();
    final store = ModelStore(cacheDirectory: '${root.path}/models');
    await expectLater(
      store.get(
        DownloadAsset(url: 'http://127.0.0.1:$port/model', sha256: digest),
      ),
      throwsA(
        isA<ModelDownloadException>().having(
          (error) => error.hint,
          'hint',
          Platform.isMacOS
              ? contains('com.apple.security.network.client')
              : Platform.isAndroid
              ? contains('INTERNET')
              : isNull,
        ),
      ),
    );
  });

  test('a server that answers gives no network hint', () async {
    final store = ModelStore(cacheDirectory: '${root.path}/models');
    await expectLater(
      store.get(asset('missing')),
      throwsA(
        isA<ModelDownloadException>().having((e) => e.hint, 'hint', isNull),
      ),
    );
  });

  test('interrupted response leaves no usable model', () async {
    final store = ModelStore(cacheDirectory: '${root.path}/models');
    await expectLater(
      store.get(asset('partial')),
      throwsA(isA<ModelDownloadException>()),
    );
    final folder = Directory('${root.path}/models/${digest.substring(0, 16)}');
    expect(
      folder.existsSync() && folder.listSync().whereType<File>().isNotEmpty,
      isFalse,
    );
  });
}

Future<void> _isolatedGet((String, String, String, SendPort) args) async {
  final (path, url, digest, reply) = args;
  final model = DownloadAsset(url: url, sha256: digest);
  reply.send((await ModelStore(cacheDirectory: path).get(model)).path);
}
