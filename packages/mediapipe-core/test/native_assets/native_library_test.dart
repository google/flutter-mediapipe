import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mediapipe_core/native_assets.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;
  late File destination;
  final bytes = utf8.encode('verified native library');
  final asset = DownloadAsset(
    url: 'https://example.invalid/runtime.dylib',
    sha256: sha256.convert(bytes).toString(),
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'mediapipe-download-test-',
    );
    destination = File.fromUri(directory.uri.resolve('runtime.dylib'));
  });
  tearDown(() => directory.delete(recursive: true));

  test(
    'returns only after the complete verified file has been written',
    () async {
      final client = MockClient((_) async => http.Response.bytes(bytes, 200));
      addTearDown(client.close);
      final file = await downloadVerified(asset, destination, client: client);
      expect(await file.readAsBytes(), bytes);
      expect(await directory.list().length, 1);
    },
  );

  test('reuses verified cached content without making a request', () async {
    await destination.writeAsBytes(bytes);
    final client = MockClient(
      (_) async => throw StateError('Unexpected request'),
    );
    addTearDown(client.close);
    await downloadVerified(asset, destination, client: client);
    expect(await destination.readAsBytes(), bytes);
  });

  test('repairs a corrupted cache entry', () async {
    await destination.writeAsString('corrupted');
    final client = MockClient((_) async => http.Response.bytes(bytes, 200));
    addTearDown(client.close);
    await downloadVerified(asset, destination, client: client);
    expect(await destination.readAsBytes(), bytes);
  });

  test(
    'rejects a checksum mismatch without replacing the destination',
    () async {
      await destination.writeAsString('previous download');
      final client = MockClient((_) async => http.Response('wrong bytes', 200));
      addTearDown(client.close);
      await expectLater(
        downloadVerified(asset, destination, client: client),
        throwsA(isA<DownloadException>()),
      );
      expect(await destination.readAsString(), 'previous download');
      expect(await directory.list().length, 1);
    },
  );

  test('reports HTTP failure without leaving partial files', () async {
    final client = MockClient((_) async => http.Response('missing', 404));
    addTearDown(client.close);
    await expectLater(
      downloadVerified(asset, destination, client: client),
      throwsA(isA<DownloadException>()),
    );
    expect(await directory.list().isEmpty, isTrue);
  });
}
