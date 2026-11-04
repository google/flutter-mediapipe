import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mediapipe_core/src/web_runtime_host.dart';
import 'package:test/test.dart';

void main() {
  final tarball = GZipEncoder().encodeBytes(
    TarEncoder().encodeBytes(
      Archive()
        ..addFile(
          ArchiveFile.bytes('package/text_bundle.mjs', utf8.encode('m')),
        )
        ..addFile(
          ArchiveFile.bytes('package/wasm/text_wasm_internal.wasm', [0, 1]),
        )
        ..addFile(ArchiveFile.bytes('package/README.md', utf8.encode('r'))),
    ),
  );

  WebRuntimePin pin({String? integrity, List<String>? files}) =>
      WebRuntimePin.fromJson({
        'package': '@mediapipe/tasks-text',
        'version': '1.0.1',
        'integrity': integrity ?? base64.encode(sha512.convert(tarball).bytes),
        'files': files ?? ['text_bundle.mjs', 'wasm/text_wasm_internal.wasm'],
        'sha384': {
          'text_bundle.mjs': base64.encode(
            sha384.convert(utf8.encode('m')).bytes,
          ),
          if (files?.contains('wasm/text_wasm_internal.wasm') ?? true)
            'wasm/text_wasm_internal.wasm': base64.encode(
              sha384.convert([0, 1]).bytes,
            ),
          if (files?.contains('wasm/missing.wasm') ?? false)
            'wasm/missing.wasm': base64.encode(sha384.convert([0]).bytes),
        },
      });

  final requests = <Uri>[];
  final client = MockClient((request) async {
    requests.add(request.url);
    return http.Response.bytes(tarball, 200);
  });
  late Directory output;
  setUp(() async {
    requests.clear();
    output = await Directory.systemTemp.createTemp('web-runtime-');
  });
  tearDown(() => output.delete(recursive: true));

  test('writes only the pinned files under <package>@<version>/', () async {
    final target = await hostWebRuntime(pin(), output, client: client);
    expect(
      requests.single.toString(),
      'https://registry.npmjs.org/@mediapipe/tasks-text/-/tasks-text-1.0.1.tgz',
    );
    expect(target.path, endsWith('@mediapipe/tasks-text@1.0.1/'));
    final names =
        target
            .listSync(recursive: true)
            .whereType<File>()
            .map((file) => file.path.substring(target.path.length))
            .toList()
          ..sort();
    expect(names, ['text_bundle.mjs', 'wasm/text_wasm_internal.wasm']);
    expect(output.listSync().map((e) => e.path.split('/').last), [
      '@mediapipe',
    ]);
  });

  test('generates file hashes from the integrity-checked tarball', () async {
    expect(await webRuntimeHashes(pin(), client: client), pin().sha384);
  });

  test('replaces an earlier copy', () async {
    await hostWebRuntime(pin(), output, client: client);
    final stale = File('${output.path}/@mediapipe/tasks-text@1.0.1/stale.js')
      ..writeAsStringSync('old');
    await hostWebRuntime(pin(), output, client: client);
    expect(stale.existsSync(), isFalse);
  });

  test('rejects a tarball that fails the integrity pin', () async {
    await expectLater(
      hostWebRuntime(
        pin(integrity: base64.encode(List.filled(64, 0))),
        output,
        client: client,
      ),
      throwsStateError,
    );
    expect(output.listSync(recursive: true), isEmpty);
  });

  test('leaves the previous copy when a pinned file is missing', () async {
    await hostWebRuntime(pin(), output, client: client);
    await expectLater(
      hostWebRuntime(
        pin(files: ['text_bundle.mjs', 'wasm/missing.wasm']),
        output,
        client: client,
      ),
      throwsStateError,
    );
    expect(
      File(
        '${output.path}/@mediapipe/tasks-text@1.0.1/text_bundle.mjs',
      ).existsSync(),
      isTrue,
    );
    expect(
      Directory('${output.path}/@mediapipe').listSync().map(
        (e) => e.uri.pathSegments.where((s) => s.isNotEmpty).last,
      ),
      ['tasks-text@1.0.1'],
    );
  });

  test('rejects pins whose files could leave the output folder', () {
    for (final file in ['../x.js', '/abs.js', 'a/b/c.js', 'x.txt']) {
      expect(() => pin(files: [file]), throwsFormatException, reason: file);
    }
  });

  test('every family pin in this repo parses', () {
    const prefix = 'mediapipe-task-';
    final families = [
      for (final entry in Directory('..').listSync())
        if (entry.uri.pathSegments.where((s) => s.isNotEmpty).last
            case final name when name.startsWith(prefix))
          name.substring(prefix.length),
    ];
    expect(families, containsAll(['vision', 'text', 'audio', 'decision']));
    for (final family in families) {
      final json =
          jsonDecode(
                File(
                  '../mediapipe-task-$family/assets/runtime.json',
                ).readAsStringSync(),
              )
              as Map<String, Object?>;
      expect(WebRuntimePin.fromJson(json).package, '@mediapipe/tasks-$family');
    }
  });
}
