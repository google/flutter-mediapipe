import 'dart:async';
import 'dart:typed_data';

import 'package:mediapipe_retrieval/mediapipe_retrieval.dart';
import 'package:mediapipe_retrieval/platform_interface.dart';
import 'package:mediapipe_retrieval/src/results/decoders.dart';
import 'package:test/test.dart';
import 'package:mediapipe_core/platform_interface.dart'
    show largeModelNeeds64Bit;

TaskPlatform _platform(String os, String arch, [String? version]) =>
    TaskPlatform(operatingSystem: os, architecture: arch, version: version);

/// A backend that records requests and answers in Google's shapes.
final class _FakeBackend implements RetrievalBackend {
  final requests = <Map<String, Object?>>[];
  final created = <Map<String, Object?>>[];
  bool disposed = false;

  @override
  Future<Object?> run(Map<String, Object?> request) async {
    requests.add(request);
    return switch (request['method']) {
      'embedText' || 'embedImage' || 'embedAudio' => {
        'embeddings': [
          {
            'floatEmbedding': [0.6, 0.8],
            'headIndex': 0,
            'headName': '',
          },
        ],
      },
      'retriever.create' => {'id': 7},
      'retriever.retrieve' => {
        'records': [
          {
            'id': 'dog',
            'text': 'A dog.',
            'score': 0.9,
            'metadata': {'t': 'a'},
          },
        ],
      },
      'retriever.getAllRecordIds' => {
        'ids': ['dog', 'cat'],
      },
      _ => null,
    };
  }

  @override
  Future<void> dispose() async => disposed = true;
}

const _arm32 = TaskPlatform(operatingSystem: 'android', architecture: 'arm');

void main() {
  test(
    '32-bit Android refuses the retrieval tasks, their models need 64-bit',
    () {
      for (final capabilities in [
        universalEmbedderCapabilitiesForPlatform(_arm32),
        semanticRetrieverCapabilitiesForPlatform(_arm32),
      ]) {
        expect(capabilities.supportedDelegates, isEmpty);
        expect(
          capabilities.unavailableReasons[Delegate.cpu],
          largeModelNeeds64Bit,
        );
      }
    },
  );

  group('options are checked the same way everywhere', () {
    test('embedder options refuse negative limits and bad paths', () {
      expect(
        () => UniversalEmbedderOptions(
          modelPath: 'm.litertlm',
          maxInputLength: -1,
        ),
        throwsArgumentError,
      );
      expect(
        () => UniversalEmbedderOptions(
          modelPath: 'm.litertlm',
          visionTokensPerImage: -1,
        ),
        throwsArgumentError,
      );
      expect(
        () => UniversalEmbedderOptions(modelPath: 'm.litertlm', cacheDir: ''),
        throwsArgumentError,
      );
      final options = UniversalEmbedderOptions(modelPath: 'm.litertlm');
      expect(options.l2Normalize, isTrue);
      expect(options.activationDataType, ActivationDataType.modelDefault);
    });

    test('content parts need their data', () {
      expect(() => TextPart(''), throwsArgumentError);
      expect(() => TextPart('a\u0000b'), throwsArgumentError);
      expect(() => ImagePart(), throwsArgumentError);
      expect(() => ImagePart(imageBytes: Uint8List(0)), throwsArgumentError);
      expect(() => AudioPart(audioPath: ''), throwsArgumentError);
      expect(ImagePart(filePath: 'a.jpg').toJson()['kind'], 'image');
      expect(
        AudioPart(audioData: Float32List.fromList([0.1])).toJson()['kind'],
        'audio',
      );
    });
  });

  group('results decode the same way from either runtime', () {
    test(
      'embeddings come as JSON lists in browsers and typed data natively',
      () {
        final fromJson = decodeEmbedderResult({
          'embeddings': [
            {
              'floatEmbedding': [1, 2.5],
              'quantizedEmbedding': <int>[],
              'headIndex': 0,
              'headName': '',
            },
          ],
        });
        expect(fromJson.embeddings.single.floatEmbedding, [1.0, 2.5]);
        expect(fromJson.embeddings.single.quantizedEmbedding, isNull);
        expect(fromJson.embeddings.single.headName, isNull);
        final native = decodeEmbedderResult({
          'embeddings': [
            {
              'floatEmbedding': null,
              'quantizedEmbedding': Uint8List.fromList([1, 255]),
              'headIndex': 1,
              'headName': 'head',
            },
          ],
        });
        expect(native.embeddings.single.quantizedEmbedding, [1, 255]);
        expect(native.embeddings.single.headName, 'head');
        expect(
          () => decodeEmbedderResult({
            'embeddings': [
              {'floatEmbedding': null, 'quantizedEmbedding': null},
            ],
          }),
          throwsA(isA<TaskException>()),
        );
      },
    );

    test('records keep their id, text, score and metadata', () {
      final result = decodeRetrievalResult({
        'records': [
          {
            'id': 'a',
            'text': 'A.',
            'score': 0.75,
            'metadata': {'k': 'v'},
          },
          {'id': 'b', 'score': 0.5},
        ],
      });
      expect(result.records.map((r) => r.id), ['a', 'b']);
      expect(result.records.first.metadata, {'k': 'v'});
      expect(result.records.last.text, '');
      expect(result.records.last.metadata, isEmpty);
      expect(
        decodeRecordIds({
          'ids': ['x'],
        }),
        ['x'],
      );
    });
  });

  group('requests take Google\'s shapes on any backend', () {
    late _FakeBackend backend;
    late UniversalEmbedder embedder;

    setUp(() async {
      backend = _FakeBackend();
      retrievalBackendFactory = (options) async {
        backend.created.add(options);
        return backend;
      };
      embedder = await UniversalEmbedder.create(
        UniversalEmbedderOptions(modelPath: 'model.litertlm'),
      );
    });
    tearDown(() => retrievalBackendFactory = null);

    test('the embedder forwards its options and inputs', () async {
      expect(backend.created.single['modelPath'], 'model.litertlm');
      expect(backend.created.single['l2Normalize'], isTrue);
      expect(backend.created.single['maxInputLength'], isNull);
      expect(backend.created.single['activationDataType'], isNull);
      final result = await embedder.embedText('hello');
      expect(
        result.embeddings.single.floatEmbedding,
        Float32List.fromList([0.6, 0.8]),
      );
      expect(backend.requests.last, {'method': 'embedText', 'text': 'hello'});
      await embedder.embedImage(Uint8List.fromList([1, 2]));
      expect(backend.requests.last['method'], 'embedImage');
      expect(() => embedder.embedAudio(Float32List(0)), throwsArgumentError);
      expect(
        UniversalEmbedder.cosineSimilarity(
          result.embeddings.single,
          result.embeddings.single,
        ),
        closeTo(1, 1e-9),
      );
    });

    test('a retriever runs on its embedder with the id it was given', () async {
      final retriever = await SemanticRetriever.create(
        SemanticRetrieverOptions(
          embedder: embedder,
          chunkSize: 64,
          chunkOverlap: 16,
        ),
      );
      expect(backend.requests.last, {
        'method': 'retriever.create',
        'databasePath': null,
        'embeddingDimension': 768,
        'chunkSize': 64,
        'chunkOverlap': 16,
        'chunkingMode': 'character',
      });
      await retriever.insertDocument('dog', 'A dog.', metadata: {'t': 'a'});
      expect(backend.requests.last, {
        'method': 'retriever.insertDocument',
        'recordId': 'dog',
        'text': 'A dog.',
        'metadata': {'t': 'a'},
        'retriever': 7,
      });
      final result = await retriever.retrieve('a puppy');
      expect(result.records.single.id, 'dog');
      expect(backend.requests.last, {
        'method': 'retriever.retrieve',
        'parts': [
          {'kind': 'text', 'text': 'a puppy'},
        ],
        'limit': 5,
        'minSimilarity': 0.5,
        'metadataFilter': null,
        'retriever': 7,
      });
      await retriever.retrieve('a puppy', limit: 2, metadataFilter: {'t': 'a'});
      expect(backend.requests.last['limit'], 2);
      expect(backend.requests.last['metadataFilter'], {'t': 'a'});
      expect(() => retriever.retrieve('x', limit: 0), throwsArgumentError);
      expect(() => retriever.insertDocument('', 'x'), throwsArgumentError);
      expect(
        () => retriever.insertDocument('a', 'x', metadata: {'': 'v'}),
        throwsArgumentError,
      );
      expect(await retriever.getAllRecordIds(), ['dog', 'cat']);
      expect(retriever.delegate, Delegate.cpu);
      await retriever.dispose();
      expect(backend.requests.last, {
        'method': 'retriever.close',
        'retriever': 7,
      });
      expect(() => retriever.deleteAll(), throwsStateError);
    });

    test(
      'disposing the embedder first leaves the retriever disposable',
      () async {
        final retriever = await SemanticRetriever.create(
          SemanticRetrieverOptions(embedder: embedder),
        );
        await embedder.dispose();
        expect(backend.disposed, isTrue);
        await retriever.dispose();
        expect(() => embedder.embedText('x'), throwsStateError);
        await embedder.dispose();
      },
    );

    test('a chunk overlap must be shorter than the chunk', () {
      expect(
        () => SemanticRetrieverOptions(embedder: embedder, chunkOverlap: 512),
        throwsArgumentError,
      );
      expect(
        () =>
            SemanticRetrieverOptions(embedder: embedder, embeddingDimension: 0),
        throwsArgumentError,
      );
      expect(
        () => SemanticRetrieverOptions(embedder: embedder, databasePath: ''),
        throwsArgumentError,
      );
    });
  });

  group('capabilities', () {
    test('the CPU on every native target', () {
      for (final (os, arch, version) in [
        ('macos', 'arm64', '15.0'),
        ('linux', 'x64', null),
        ('windows', 'x64', null),
        ('android', 'arm64', '14'),
        ('android', 'x64', '14'),
        ('ios', 'arm64', '17.0'),
      ]) {
        for (final capabilities in [
          universalEmbedderCapabilitiesForPlatform(
            _platform(os, arch, version),
          ),
          semanticRetrieverCapabilitiesForPlatform(
            _platform(os, arch, version),
          ),
        ]) {
          expect(capabilities.supportedDelegates, {Delegate.cpu}, reason: os);
          expect(capabilities.runtimeVersion, '1.2.0');
          expect(
            capabilities.unavailableReasons[Delegate.gpu],
            contains('CPU'),
          );
        }
      }
      expect(
        universalEmbedderCapabilitiesForPlatform(
          _platform('macos', 'arm64', '13.0'),
        ).isSupported,
        isFalse,
      );
    });

    test('a target without the library says so for both delegates', () {
      for (final (os, arch) in [
        ('macos', 'x64'),
        ('linux', 'arm64'),
        ('windows', 'arm64'),
      ]) {
        final capabilities = semanticRetrieverCapabilitiesForPlatform(
          _platform(os, arch, null),
        );
        expect(capabilities.supportedDelegates, isEmpty, reason: '$os/$arch');
        for (final delegate in Delegate.values) {
          expect(
            capabilities.unavailableReasons[delegate],
            allOf(contains('covers'), isNot(contains('GPU path'))),
            reason: '$os/$arch ${delegate.name}',
          );
        }
      }
    });

    test('browsers get the GPU on a hardware WebGPU adapter (UP-052)', () {
      TaskPlatform web(String? gpu) => TaskPlatform(
        operatingSystem: 'web',
        architecture: 'unknown',
        gpu: gpu,
      );
      const metal = 'WebGPU apple metal-3';
      expect(
        universalEmbedderCapabilitiesForPlatform(web(metal)).isSupported,
        isFalse,
        reason: 'no plugin',
      );
      retrievalBackendFactory = (_) => throw UnimplementedError();
      addTearDown(() => retrievalBackendFactory = null);
      for (final capabilities in [
        universalEmbedderCapabilitiesForPlatform(web(metal)),
        semanticRetrieverCapabilitiesForPlatform(web(metal)),
      ]) {
        expect(capabilities.supportedDelegates, {Delegate.gpu});
        expect(
          capabilities.unavailableReasons[Delegate.cpu],
          contains('UP-052'),
        );
      }
      for (final gpu in [
        null,
        'WebGPU google swiftshader',
        'WebGPU apple metal-3 (fallback adapter)',
        'Mali-G715 (ARM)',
      ]) {
        final refused = universalEmbedderCapabilitiesForPlatform(web(gpu));
        expect(refused.isSupported, isFalse, reason: '$gpu');
        expect(refused.unavailableReasons[Delegate.gpu], contains('UP-052'));
      }
    });

    test('WebKit gets neither task: Google\'s runtime embeds everything as '
        'zeros there (UP-054)', () {
      TaskPlatform web(
        BrowserEngine? engine, [
        String gpu = 'WebGPU apple apple',
      ]) => TaskPlatform(
        operatingSystem: 'web',
        architecture: 'unknown',
        gpu: gpu,
        browserEngine: engine,
      );
      retrievalBackendFactory = (_) => throw UnimplementedError();
      addTearDown(() => retrievalBackendFactory = null);
      for (final query in [
        universalEmbedderCapabilitiesForPlatform,
        semanticRetrieverCapabilitiesForPlatform,
      ]) {
        final refused = query(web(BrowserEngine.webkit));
        expect(refused.isSupported, isFalse);
        for (final delegate in Delegate.values) {
          expect(
            refused.unavailableReasons[delegate],
            contains('UP-054'),
            reason: '$delegate',
          );
        }
        for (final engine in [BrowserEngine.blink, BrowserEngine.gecko, null]) {
          expect(query(web(engine)).supportedDelegates, {Delegate.gpu});
        }
        // Without a hardware adapter the reason stays UP-052.
        expect(
          query(
            web(BrowserEngine.webkit, 'WebGPU apple apple (fallback adapter)'),
          ).unavailableReasons[Delegate.gpu],
          contains('UP-052'),
        );
      }
    });
  });
}
