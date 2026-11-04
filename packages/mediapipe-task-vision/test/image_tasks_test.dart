import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';
import 'package:test/test.dart';

import 'support/face_reference.dart';
import 'support/vision_fixture.dart';

const _classifierModel = 'models/efficientnet_lite0.tflite';
const _embedderModel = 'models/mobilenet_v3_small.tflite';

void main() {
  final reference = loadFaceReference('image_tasks', 'official_reference.json');
  final cases = (reference['cases'] as List).cast<Map<String, dynamic>>();
  group('CPU inference', () {
    setUpAll(() {
      expect(
        sha256.convert(File(_classifierModel).readAsBytesSync()).toString(),
        VisionModels.imageClassifier.sha256,
      );
      expect(
        sha256.convert(File(_embedderModel).readAsBytesSync()).toString(),
        VisionModels.imageEmbedder.sha256,
      );
      expect(reference['models'], {
        'classifier': VisionModels.imageClassifier.sha256,
        'embedder': VisionModels.imageEmbedder.sha256,
      });
    });

    for (final expected in cases.where((c) => c['timestamp_ms'] == null)) {
      test(
        'official ${expected['task']} / ${expected['input']} / ${expected['options']}',
        () => _runCase(expected),
      );
    }

    for (final taskName in ['classifier', 'embedder']) {
      test('$taskName video results survive queued disposal', () async {
        final frames = cases
            .where(
              (c) =>
                  c['task'] == taskName &&
                  c['timestamp_ms'] != null &&
                  (taskName == 'classifier' ||
                      (c['options'] as Map)['l2_normalize'] == false),
            )
            .toList();
        if (taskName == 'classifier') {
          final task = await ImageClassifier.create(
            ImageClassifierOptions(
              modelPath: _classifierModel,
              maxResults: 3,
              runningMode: RunningMode.video,
            ),
          );
          final requests = [
            for (final frame in frames)
              task.classifyForVideo(
                _image(frame),
                timestampMilliseconds: frame['timestamp_ms'] as int,
              ),
          ];
          final closing = task.dispose();
          expect(identical(closing, task.dispose()), isTrue);
          await expectLater(
            task.classifyForVideo(
              _image(frames.first),
              timestampMilliseconds: 100,
            ),
            throwsStateError,
          );
          final results = await Future.wait(requests);
          await closing;
          for (var i = 0; i < frames.length; i++) {
            _compareClassifier(results[i], frames[i]);
            expect(results[i].timestampMilliseconds, frames[i]['timestamp_ms']);
          }
        } else {
          final task = await ImageEmbedder.create(
            ImageEmbedderOptions(
              modelPath: _embedderModel,
              runningMode: RunningMode.video,
            ),
          );
          final requests = [
            for (final frame in frames)
              task.embedForVideo(
                _image(frame),
                timestampMilliseconds: frame['timestamp_ms'] as int,
              ),
          ];
          final closing = task.dispose();
          expect(identical(closing, task.dispose()), isTrue);
          final results = await Future.wait(requests);
          await closing;
          for (var i = 0; i < frames.length; i++) {
            _compareEmbedder(results[i], frames[i]);
            expect(results[i].timestampMilliseconds, frames[i]['timestamp_ms']);
          }
        }
      });
    }

    test(
      'model bytes own their input and native errors leave tasks usable',
      () async {
        final expected = cases.first;
        final source = File(_classifierModel).readAsBytesSync();
        final options = ImageClassifierOptions(
          modelBytes: source,
          maxResults: 3,
        );
        source.fillRange(0, source.length, 0);
        final task = await ImageClassifier.create(options);
        try {
          await expectLater(
            task.classify(VisionImage.fromFile('missing-image.jpg')),
            throwsA(isA<TaskException>()),
          );
          _compareClassifier(await task.classify(_image(expected)), expected);
        } finally {
          await task.dispose();
        }
        await expectLater(
          ImageEmbedder.create(
            ImageEmbedderOptions(modelBytes: Uint8List(32)),
          ).timeout(const Duration(seconds: 10)),
          throwsA(isA<TaskException>()),
        );
        final valid = await ImageEmbedder.create(
          ImageEmbedderOptions(modelPath: _embedderModel),
        );
        await valid.dispose();
      },
    );

    test('mode and timestamp errors do not reserve invalid requests', () async {
      final expected = cases.where((c) => c['task'] == 'embedder').first;
      final task = await ImageEmbedder.create(
        ImageEmbedderOptions(
          modelPath: _embedderModel,
          runningMode: RunningMode.video,
        ),
      );
      try {
        await expectLater(task.embed(_image(expected)), throwsStateError);
        for (final timestamp in [-1, 0x7fffffffffffffff]) {
          await expectLater(
            task.embedForVideo(
              _image(expected),
              timestampMilliseconds: timestamp,
            ),
            throwsArgumentError,
          );
        }
        await expectLater(
          task.embedForVideo(
            _image(expected),
            timestampMilliseconds: 10,
            rotationDegrees: 45,
          ),
          throwsArgumentError,
        );
        _compareEmbedder(
          await task.embedForVideo(_image(expected), timestampMilliseconds: 10),
          expected,
        );
        await expectLater(
          task.embedForVideo(_image(expected), timestampMilliseconds: 10),
          throwsArgumentError,
        );
      } finally {
        await task.dispose();
      }
    });
  }, skip: cpuReferenceSkipReason);

  // GPU output against Google's own GPU output from the same host (Linux's
  // wheel on OpenGL ES; macOS withdraws Metal for now, UP-057), generated by
  // tool/prepare_gpu_reference.py --image-tasks. Nothing is checked in: GPU
  // results depend on the GPU and its driver.
  group('GPU inference', () {
    final gpuReference = _gpuSkip == null
        ? loadFaceReference('image_tasks', 'official_gpu_reference.json')
        : null;
    final gpuCases = [
      ...?(gpuReference?['cases'] as List?)?.cast<Map<String, dynamic>>(),
    ];
    tearDownAll(() {
      reportReferenceDeltas('image_classifier');
      reportReferenceDeltas('image_embedder');
    });
    for (final expected in gpuCases.where((c) => c['timestamp_ms'] == null)) {
      test(
        'official ${expected['task']} / ${expected['input']} / ${expected['options']}',
        () => _runCase(expected, delegate: Delegate.gpu),
      );
    }
  }, skip: _gpuSkip);

  test('options validate region, model and classification configuration', () {
    expect(
      () => VisionRegionOfInterest(left: 0.8, top: 0, right: 0.2, bottom: 1),
      throwsArgumentError,
    );
    expect(
      () =>
          VisionRegionOfInterest(left: double.nan, top: 0, right: 1, bottom: 1),
      throwsArgumentError,
    );
    expect(
      () => ImageClassifierOptions(modelPath: _classifierModel, maxResults: 0),
      throwsArgumentError,
    );
    expect(
      () => ImageClassifierOptions(
        modelPath: _classifierModel,
        maxResults: 0x100000000,
      ),
      throwsArgumentError,
    );
    expect(
      () => ImageClassifierOptions(
        modelPath: _classifierModel,
        categoryAllowlist: ['cat'],
        categoryDenylist: ['dog'],
      ),
      throwsArgumentError,
    );
    expect(() => ImageEmbedderOptions(), throwsArgumentError);
  });

  test(
    'cosine similarity handles signed quantized vectors and rejects incompatible inputs',
    () {
      Embedding floats(List<double> values) =>
          Embedding(floatEmbedding: Float32List.fromList(values), headIndex: 0);
      Embedding quantized(List<int> values) => Embedding(
        quantizedEmbedding: Uint8List.fromList(values),
        headIndex: 0,
      );
      expect(ImageEmbedder.cosineSimilarity(floats([1, 0]), floats([0, 1])), 0);
      expect(
        ImageEmbedder.cosineSimilarity(quantized([255, 0]), quantized([1, 0])),
        -1,
      );
      expect(
        () => ImageEmbedder.cosineSimilarity(floats([1]), quantized([1])),
        throwsArgumentError,
      );
      expect(
        () => ImageEmbedder.cosineSimilarity(floats([0]), floats([0])),
        throwsArgumentError,
      );
      expect(
        () => ImageEmbedder.cosineSimilarity(floats([double.nan]), floats([1])),
        throwsArgumentError,
      );
    },
  );
}

/// Why the GPU comparisons cannot run on this host, or null when they can.
final _gpuSkip = Platform.isMacOS
    ? macosGpuWithdrawn
    : Platform.environment['MEDIAPIPE_GPU_REFERENCE_DIR'] == null
    ? 'GPU image tasks compare with same-host official GPU outputs '
          '(MEDIAPIPE_GPU_REFERENCE_DIR).'
    : Platform.isLinux
    ? null
    : 'Desktop GPU is validated on Linux.';

// The same library and GPU as the reference, reached through another
// process: scores and float embeddings move by float rounding on the GPU.
const _gpuScoreTolerance = 0.001;
const _gpuEmbeddingTolerance = 0.001;

/// Runs one IMAGE-mode reference case on [delegate] and compares it.
Future<void> _runCase(
  Map<String, dynamic> expected, {
  Delegate delegate = Delegate.cpu,
}) async {
  final options = expected['options'] as Map<String, dynamic>;
  final gpu = delegate == Delegate.gpu;
  if (expected['task'] == 'classifier') {
    final task = await ImageClassifier.create(
      ImageClassifierOptions(
        modelPath: _classifierModel,
        maxResults: options['max_results'] as int,
        delegate: delegate,
      ),
    );
    try {
      _compareClassifier(
        await task.classify(
          _image(expected),
          rotationDegrees: expected['rotation_degrees'] as int,
          regionOfInterest: _region(expected),
        ),
        expected,
        gpu: gpu,
      );
    } finally {
      await task.dispose();
    }
  } else {
    final task = await ImageEmbedder.create(
      ImageEmbedderOptions(
        modelPath: _embedderModel,
        l2Normalize: options['l2_normalize'] as bool,
        quantize: options['quantize'] as bool,
        delegate: delegate,
      ),
    );
    try {
      _compareEmbedder(
        await task.embed(
          _image(expected),
          rotationDegrees: expected['rotation_degrees'] as int,
          regionOfInterest: _region(expected),
        ),
        expected,
        gpu: gpu,
      );
    } finally {
      await task.dispose();
    }
  }
}

VisionImage _image(Map<String, dynamic> expected) => fixtureImage({
  ...expected,
  'name': expected['input'] == 'rotated' ? 'rgb-rotated' : expected['input'],
  if (expected['input'] == 'blank') 'raw': null,
});

VisionRegionOfInterest? _region(Map<String, dynamic> expected) {
  final region = expected['region'] as Map<String, dynamic>?;
  return region == null
      ? null
      : VisionRegionOfInterest(
          left: region['left'] as double,
          top: region['top'] as double,
          right: region['right'] as double,
          bottom: region['bottom'] as double,
        );
}

void _compareClassifier(
  ImageClassifierResult actual,
  Map<String, dynamic> expected, {
  bool gpu = false,
}) {
  expect(actual.imageWidth, expected['width']);
  expect(actual.imageHeight, expected['height']);
  final heads = (expected['result']['classifications'] as List)
      .cast<Map<String, dynamic>>();
  expect(actual.classifications, hasLength(heads.length));
  for (var i = 0; i < heads.length; i++) {
    final actualHead = actual.classifications[i];
    final expectedHead = heads[i];
    expect(actualHead.headIndex, expectedHead['head_index']);
    expect(actualHead.headName, expectedHead['head_name']);
    final categories = expectedHead['categories'] as List;
    expect(actualHead.categories, hasLength(categories.length));
    for (var j = 0; j < categories.length; j++) {
      expect(actualHead.categories[j].index, categories[j]['index']);
      if (gpu) {
        recordReferenceDelta(
          'image_classifier',
          'gpu',
          'categories',
          'classifications[$i].categories[$j].score',
          actualHead.categories[j].score,
          categories[j]['score'] as num,
        );
      }
      expect(
        actualHead.categories[j].score,
        closeTo(
          categories[j]['score'] as num,
          gpu ? _gpuScoreTolerance : 0.00001,
        ),
      );
      expect(
        actualHead.categories[j].categoryName,
        categories[j]['category_name'],
      );
      expect(
        actualHead.categories[j].displayName,
        categories[j]['display_name'],
      );
    }
    expect(() => actualHead.categories.clear(), throwsUnsupportedError);
  }
}

void _compareEmbedder(
  ImageEmbedderResult actual,
  Map<String, dynamic> expected, {
  bool gpu = false,
}) {
  expect(actual.imageWidth, expected['width']);
  expect(actual.imageHeight, expected['height']);
  final heads = (expected['result']['embeddings'] as List)
      .cast<Map<String, dynamic>>();
  expect(actual.embeddings, hasLength(heads.length));
  for (var i = 0; i < heads.length; i++) {
    final actualHead = actual.embeddings[i];
    final expectedHead = heads[i];
    expect(actualHead.headIndex, expectedHead['head_index']);
    expect(actualHead.headName, expectedHead['head_name']);
    final values = expectedHead['embedding'] as List;
    if ((expected['options'] as Map)['quantize'] == true) {
      if (gpu) {
        // A float that rounds differently moves its byte by one.
        final quantized = actualHead.quantizedEmbedding!;
        expect(quantized, hasLength(values.length));
        for (var j = 0; j < values.length; j++) {
          expect(quantized[j], closeTo(values[j] as num, 1));
        }
      } else {
        expect(actualHead.quantizedEmbedding, values);
      }
      expect(actualHead.floatEmbedding, isNull);
      expect(
        () => actualHead.quantizedEmbedding![0] = 0,
        throwsUnsupportedError,
      );
    } else {
      expect(actualHead.quantizedEmbedding, isNull);
      expect(actualHead.floatEmbedding, hasLength(values.length));
      for (var j = 0; j < values.length; j++) {
        if (gpu) {
          recordReferenceDelta(
            'image_embedder',
            'gpu',
            'embedding',
            'embeddings[$i][$j]',
            actualHead.floatEmbedding![j],
            values[j] as num,
          );
        }
        expect(
          actualHead.floatEmbedding![j],
          closeTo(values[j] as num, gpu ? _gpuEmbeddingTolerance : 0.00001),
        );
      }
      expect(() => actualHead.floatEmbedding!.clear(), throwsUnsupportedError);
    }
  }
}
