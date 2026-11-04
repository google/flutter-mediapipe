import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_core/platform_interface.dart';
import 'package:mediapipe_core/src/model_bundle.dart';
import 'package:mediapipe_core/src/model_bundler.dart';
import 'package:test/test.dart';

void main() {
  final faceBytes = utf8.encode('pretend face model');
  final yamnetBytes = utf8.encode('pretend yamnet model');
  final faceSha = sha256.convert(faceBytes).toString();
  final yamnetSha = sha256.convert(yamnetBytes).toString();
  // Unreachable primary URLs: every download must come from the mirror.
  final face = DownloadAsset(
    url: 'http://127.0.0.1:9/models/face_detector.tflite',
    sha256: faceSha,
  );
  final yamnet = DownloadAsset(
    url: 'http://127.0.0.1:9/models/yamnet.tflite',
    sha256: yamnetSha,
  );
  final vision = {'face_detector': face};
  final audio = {'yamnet': yamnet};

  late HttpServer mirror;
  late Directory root;
  late List<String> requests;

  setUp(() async {
    requests = [];
    root = await Directory.systemTemp.createTemp('mediapipe-bundling-');
    mirror = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    mirror.listen((request) async {
      final name = request.uri.pathSegments.last;
      requests.add(name);
      final body = {faceSha: faceBytes, yamnetSha: yamnetBytes}[name];
      if (body == null) {
        request.response.statusCode = 404;
      } else {
        request.response.add(body);
      }
      await request.response.close();
    });
  });
  tearDown(() async {
    ModelStore.allowDownloads = false;
    ModelStore.debugBundledModels = null;
    ModelStore.debugCacheDirectory = null;
    await mirror.close(force: true);
    await root.delete(recursive: true);
  });

  String source() => 'http://127.0.0.1:${mirror.port}/';
  File bundled(String sha) => File('${root.path}/${bundledModelKey(sha)}');
  Future<BundleResult> bundle(
    Map<String, List<String>> listed, {
    bool check = false,
    bool declared = true,
  }) => bundleModels(
    root,
    [
      for (final MapEntry(:key, :value) in listed.entries)
        FamilyModels(key, value, key == 'mediapipe_vision' ? vision : audio),
    ],
    declared: declared,
    source: source(),
    check: check,
  );

  group('pubspec', () {
    test('lists models per family, without duplicates', () {
      expect(
        listedModels({
          'hooks': {
            'user_defines': {
              'mediapipe_vision': {
                'tasks': ['face_detector'],
                'models': ['face_detector', 'face_detector'],
              },
              'mediapipe_audio': {
                'models': ['yamnet'],
              },
              'something_else': {
                'models': ['ignored'],
              },
            },
          },
        }),
        {
          'mediapipe_vision': ['face_detector'],
          'mediapipe_audio': ['yamnet'],
        },
      );
      expect(listedModels({'name': 'app'}), isEmpty);
    });

    test('rejects a models entry that is not a list of names', () {
      for (final models in <Object>[
        'face_detector',
        [1],
        [''],
      ]) {
        final pubspec = {
          'hooks': {
            'user_defines': {
              'mediapipe_vision': {'models': models},
            },
          },
        };
        expect(() => listedModels(pubspec), throwsFormatException);
      }
    });

    test('reads asset_source like the build hooks', () {
      Map<String, Object> pubspec(Object source) => {
        'hooks': {
          'user_defines': {
            'mediapipe_core': {'asset_source': source},
          },
        },
      };
      expect(
        bundleSource(pubspec('https://mirror.example/m/'), root),
        'https://mirror.example/m/',
      );
      // URIs compare the same with either path separator.
      expect(
        Directory(bundleSource(pubspec('mirror'), root)!).uri,
        root.uri.resolve('mirror/'),
      );
      expect(bundleSource({}, root), isNull);
      expect(() => bundleSource(pubspec(''), root), throwsFormatException);
    });

    test('recognizes the assets/mediapipe/ declaration', () {
      bool declares(List<Object> assets) => declaresBundledModels({
        'flutter': {'assets': assets},
      });
      expect(declares(['assets/mediapipe/']), isTrue);
      expect(declares(['assets/mediapipe']), isTrue);
      expect(declares(['./assets/mediapipe/']), isTrue);
      expect(
        declares([
          {'path': 'assets/mediapipe/'},
        ]),
        isTrue,
      );
      expect(declares(['assets/']), isFalse);
      expect(declaresBundledModels({'name': 'app'}), isFalse);
    });
  });

  group('bundleModels', () {
    test('downloads, verifies and names each model by its SHA-256', () async {
      final result = await bundle({
        'mediapipe_vision': ['face_detector'],
        'mediapipe_audio': ['yamnet'],
      });
      expect(result.problems, isEmpty);
      expect(await bundled(faceSha).readAsBytes(), faceBytes);
      expect(await bundled(yamnetSha).readAsBytes(), yamnetBytes);
      expect(requests, unorderedEquals([faceSha, yamnetSha]));
      expect(result.lines.first, startsWith('Downloaded: '));
      final manifest =
          jsonDecode(
                await File(
                  '${root.path}/$bundledModelsFolder$bundledModelsManifest',
                ).readAsString(),
              )
              as Map;
      expect(manifest['models'], [
        {
          'model': 'mediapipe_audio: yamnet',
          'file': yamnetSha,
          'url': yamnet.url,
        },
        {
          'model': 'mediapipe_vision: face_detector',
          'file': faceSha,
          'url': face.url,
        },
      ]);
    });

    test('reuses verified files and removes unlisted ones', () async {
      await bundle({
        'mediapipe_vision': ['face_detector'],
        'mediapipe_audio': ['yamnet'],
      });
      requests.clear();
      final again = await bundle({
        'mediapipe_vision': ['face_detector'],
      });
      expect(again.problems, isEmpty);
      expect(requests, isEmpty);
      expect(again.lines.first, startsWith('Up to date: '));
      expect(await bundled(yamnetSha).exists(), isFalse);
      expect(again.lines, contains(contains('Removed ')));
    });

    test('replaces a bundled file that no longer matches its pin', () async {
      await bundle({
        'mediapipe_vision': ['face_detector'],
      });
      await bundled(faceSha).writeAsString('tampered');
      requests.clear();
      final repaired = await bundle({
        'mediapipe_vision': ['face_detector'],
      });
      expect(repaired.problems, isEmpty);
      expect(requests, [faceSha]);
      expect(await bundled(faceSha).readAsBytes(), faceBytes);
    });

    test('--check verifies without downloading or writing', () async {
      final listed = {
        'mediapipe_vision': ['face_detector'],
      };
      final missing = await bundle(listed, check: true);
      expect(missing.problems, isNotEmpty);
      expect(requests, isEmpty);
      expect(await Directory('${root.path}/assets').exists(), isFalse);

      await bundle(listed);
      requests.clear();
      expect((await bundle(listed, check: true)).problems, isEmpty);

      await bundled(faceSha).writeAsString('tampered');
      expect(
        (await bundle(listed, check: true)).problems.single,
        contains('does not match its pin'),
      );
      await bundle(listed);
      await bundled(yamnetSha).writeAsBytes(yamnetBytes);
      expect(
        (await bundle(listed, check: true)).problems.single,
        contains('no longer listed'),
      );
      expect(requests, [faceSha]);
    });

    test('rejects an unknown name before touching files', () async {
      final result = await bundle({
        'mediapipe_vision': ['face_detektor'],
      });
      expect(result.problems.single, contains('face_detector'));
      expect(await Directory('${root.path}/assets').exists(), isFalse);
      expect(requests, isEmpty);
    });

    test('fails until pubspec.yaml declares the folder', () async {
      final result = await bundle({
        'mediapipe_vision': ['face_detector'],
      }, declared: false);
      expect(result.problems.single, contains('- assets/mediapipe/'));
      // The models are in place, so declaring the folder is the only step left.
      expect(await bundled(faceSha).exists(), isTrue);
    });

    test('does nothing when no models are listed', () async {
      final result = await bundle({}, declared: false);
      expect(result.problems, isEmpty);
      expect(await Directory('${root.path}/assets').exists(), isFalse);
    });
  });

  test('the registry program round-trips each family\'s models', () {
    final program = registryProgram(['mediapipe_vision', 'mediapipe_audio']);
    expect(program, contains("import 'package:mediapipe_vision/models.dart'"));
    expect(program, contains('VisionModels.byName'));
    expect(program, contains('AudioModels.byName'));
    final decoded = decodeRegistry({
      'face_detector': [
        face.url,
        face.sha256,
        ['https://mirror.example/face'],
      ],
    });
    expect(decoded['face_detector']!.sha256, faceSha);
    expect(decoded['face_detector']!.mirrors, ['https://mirror.example/face']);
  });

  group('ModelStore and model:', () {
    late Directory store;
    late int bundleReads;

    setUp(() {
      store = Directory('${root.path}/support');
      ModelStore.debugCacheDirectory = store.path;
      bundleReads = 0;
    });

    void bundles(Map<String, List<int>> models) {
      ModelStore.debugBundledModels = (sha) async {
        bundleReads++;
        final bytes = models[sha];
        return bytes == null ? null : Uint8List.fromList(bytes);
      };
    }

    test('find copies a bundled model into the cache once', () async {
      bundles({faceSha: faceBytes});
      final first = await ModelStore().find(face);
      expect(first, isNotNull);
      expect(first!.path, endsWith('face_detector.tflite'));
      expect(await File(first.path!).readAsBytes(), faceBytes);
      final second = await ModelStore().find(face);
      expect(second!.path, first.path);
      expect(bundleReads, 1);
      expect(requests, isEmpty);
    });

    test('find never downloads', () async {
      bundles({});
      expect(await ModelStore().find(face), isNull);
      expect(requests, isEmpty);
    });

    test('a bundled copy that does not match its pin is refused', () async {
      bundles({faceSha: utf8.encode('tampered')});
      await expectLater(
        ModelStore().find(face),
        throwsA(isA<RuntimeUnavailableException>()),
      );
    });

    test('model: uses the bundled copy with downloads off', () async {
      bundles({faceSha: faceBytes});
      final source = await resolvePinnedModel(face);
      expect(await File(source.path!).readAsBytes(), faceBytes);
      expect(requests, isEmpty);
    });

    test('model: names the pubspec entry when a model is not bundled', () {
      bundles({});
      expect(
        () => resolvePinnedModel(
          face,
          family: 'mediapipe_vision',
          registry: vision,
        ),
        throwsA(
          isA<RuntimeUnavailableException>()
              .having((e) => e.message, 'message', contains('not bundled'))
              .having(
                (e) => e.fix,
                'fix',
                allOf(
                  contains(
                    'Add face_detector to '
                    'hooks.user_defines.mediapipe_vision.models',
                  ),
                  contains('dart run mediapipe_core:bundle_models'),
                  contains('ModelStore.allowDownloads = true'),
                ),
              ),
        ),
      );
      expect(requests, isEmpty);
    });

    test('model: downloads only when the app allows it', () async {
      bundles({});
      ModelStore.allowDownloads = true;
      final mirrored = DownloadAsset(
        url: 'http://127.0.0.1:${mirror.port}/$faceSha',
        sha256: faceSha,
      );
      final source = await resolvePinnedModel(mirrored);
      expect(await File(source.path!).readAsBytes(), faceBytes);
      expect(requests, [faceSha]);
    });
  });
}
