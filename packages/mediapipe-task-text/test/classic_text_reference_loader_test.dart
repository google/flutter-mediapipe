import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

import 'support/classic_text_reference.dart';

void main() {
  late Directory root;
  late File reference;
  late Map<String, dynamic> manifest;
  Future<void> receipt() =>
      File('${root.path}/provenance.json').writeAsString(jsonEncode(manifest));
  Map<String, dynamic> load() => loadClassicTextReference(directory: root.path);

  setUp(() async {
    root = await Directory.systemTemp.createTemp('official-text-test-');
    final baseline = File('test/fixtures/classic_text/official_reference.json');
    // What the generator writes on this host: the baseline's outputs from this
    // host's pinned library.
    final host = officialTextRuntime()!;
    final content =
        jsonDecode(await baseline.readAsString()) as Map<String, dynamic>
          ..['runtime'] = host.runtime
          ..['library_sha256'] = host.library;
    reference = await File(
      '${root.path}/official_reference.json',
    ).writeAsString(jsonEncode(content));
    manifest = {
      'source': 'official-python-api',
      'runtime': host.runtime,
      'delegate': 'CPU',
      'library_sha256': host.library,
      'wheel_sha256': host.wheel,
      'reference_sha256': sha256
          .convert(await reference.readAsBytes())
          .toString(),
      'baseline_sha256': sha256
          .convert(await baseline.readAsBytes())
          .toString(),
    };
    await receipt();
  });
  tearDown(() => root.delete(recursive: true));

  test('verified host reference preserves every case', () {
    expect(load()['cases'], hasLength(26));
  });

  test(
    'missing reference fails instead of using the checked-in baseline',
    () async {
      await reference.delete();
      expect(load, throwsA(isA<FileSystemException>()));
    },
  );

  test('changed reference bytes are rejected', () async {
    await reference.writeAsString('${await reference.readAsString()} ');
    expect(load, throwsStateError);
  });

  test("a library other than this host's pin is rejected", () async {
    manifest['library_sha256'] = '0' * 64;
    await receipt();
    expect(load, throwsStateError);
  });

  test('a receipt for a different baseline is rejected', () async {
    manifest['baseline_sha256'] = '0' * 64;
    await receipt();
    expect(load, throwsStateError);
  });

  test(
    'wrong model provenance is rejected even with a matching digest',
    () async {
      final data = jsonDecode(await reference.readAsString());
      data['models']['embedder']['sha256'] = '0' * 64;
      await reference.writeAsString(jsonEncode(data));
      manifest['reference_sha256'] = sha256
          .convert(await reference.readAsBytes())
          .toString();
      await receipt();
      expect(load, throwsStateError);
    },
  );
}
