import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';
import 'package:test/test.dart';

import 'support/face_reference.dart';
import 'support/vision_fixture.dart';

const _model = 'models/efficientdet_lite0.tflite';
const _scoreThreshold = 0.3;
const _maxResults = 5;

void main() {
  for (final delegate in Delegate.values) {
    group(
      delegate.name,
      () => _testDelegate(delegate),
      skip: delegate == Delegate.cpu
          ? cpuReferenceSkipReason
          : delegate == Delegate.gpu && Platform.isMacOS
          ? macosGpuWithdrawn
          : delegate == Delegate.gpu &&
                !(Platform.isLinux &&
                    Platform.environment['MEDIAPIPE_GPU_REFERENCE_DIR'] != null)
          ? 'GPU object inference is validated on Linux against same-host '
                'references (MEDIAPIPE_GPU_REFERENCE_DIR).'
          : null,
    );
  }

  test('CPU is the default delegate', () {
    expect(ObjectDetectorOptions(modelPath: _model).delegate, Delegate.cpu);
  });

  // The hook bundles Google's vision library for this package's tests, so
  // the CPU path passes the capability gate and reaches Google's own model
  // loader.
  if (Platform.isMacOS) {
    test("macOS CPU runs on Google's vision library", () async {
      await expectLater(
        ObjectDetector.create(
          ObjectDetectorOptions(modelPath: 'missing-model.tflite'),
        ),
        throwsA(
          isA<TaskException>().having(
            (e) => e.message,
            'message',
            contains('missing-model.tflite'),
          ),
        ),
      );
    });
  }

  test('rejects a zero result limit', () {
    expect(
      () => ObjectDetectorOptions(modelPath: _model, maxResults: 0),
      throwsArgumentError,
    );
  });

  test('rejects an allowlist and a denylist together', () {
    expect(
      () => ObjectDetectorOptions(
        modelPath: _model,
        categoryAllowlist: const ['person'],
        categoryDenylist: const ['car'],
      ),
      throwsArgumentError,
    );
  });

  test('rejects two model sources', () {
    expect(
      () => ObjectDetectorOptions(
        modelPath: _model,
        modelBytes: Uint8List.fromList(const [1, 2, 3]),
      ),
      throwsArgumentError,
    );
  });
}

void _testDelegate(Delegate delegate) {
  final suffix = delegate == Delegate.gpu ? '_gpu' : '';
  final reference = loadFaceReference(
    'object_detection',
    'official${suffix}_reference.json',
  );
  final videoReference = loadFaceReference(
    'object_detection',
    'official${suffix}_video_reference.json',
  );
  final cases = (reference['cases'] as List).cast<Map<String, dynamic>>();
  late ObjectDetector detector;

  setUpAll(() async {
    expect(
      sha256.convert(File(_model).readAsBytesSync()).toString(),
      VisionModels.objectDetector.sha256,
    );
    expect(reference['model_sha256'], VisionModels.objectDetector.sha256);
    expect(reference['delegate'], delegate.name.toUpperCase());
    expect(reference['score_threshold'], _scoreThreshold);
    expect(reference['max_results'], _maxResults);
    detector = await ObjectDetector.create(
      ObjectDetectorOptions(
        delegate: delegate,
        modelPath: _model,
        scoreThreshold: _scoreThreshold,
        maxResults: _maxResults,
      ),
    );
  });
  tearDownAll(() async => detector.dispose());

  test('task exposes the selected delegate', () {
    expect(detector.delegate, delegate);
    expect(detector.runningMode, RunningMode.image);
  });

  test('queued requests complete before idempotent disposal', () async {
    final task = await ObjectDetector.create(
      ObjectDetectorOptions(
        delegate: delegate,
        modelPath: _model,
        scoreThreshold: _scoreThreshold,
        maxResults: _maxResults,
      ),
    );
    final expected = cases.where((c) => c['name'] == 'rgb').single;
    final requests = [
      for (var i = 0; i < 6; i++) task.detect(fixtureImage(expected)),
    ];
    final closing = task.dispose();
    expect(identical(closing, task.dispose()), isTrue);
    await expectLater(task.detect(fixtureImage(expected)), throwsStateError);
    final results = await Future.wait(requests);
    await closing;
    for (final result in results) {
      _expectMatches(result, expected);
      expect(() => result.detections.clear(), throwsUnsupportedError);
      expect(
        () => result.detections.first.categories.clear(),
        throwsUnsupportedError,
      );
    }
  });

  test('native input errors leave the detector usable', () async {
    await expectLater(
      detector.detect(VisionImage.fromFile('missing-image.jpg')),
      throwsA(isA<TaskException>()),
    );
    _expectMatches(
      await detector.detect(fixtureImage(cases.first)),
      cases.first,
    );
  });

  test(
    'invalid model initialization fails without poisoning later tasks',
    () async {
      for (final options in [
        ObjectDetectorOptions(
          delegate: delegate,
          modelPath: 'missing-model.tflite',
        ),
        ObjectDetectorOptions(delegate: delegate, modelBytes: Uint8List(32)),
      ]) {
        await expectLater(
          ObjectDetector.create(options).timeout(const Duration(seconds: 10)),
          throwsA(isA<TaskException>()),
        );
      }
      final task = await ObjectDetector.create(
        ObjectDetectorOptions(delegate: delegate, modelPath: _model),
      );
      await task.dispose();
    },
  );

  for (final expected in cases) {
    test('matches the official result for ${expected['name']}', () async {
      final result = await detector.detect(
        fixtureImage(expected),
        rotationDegrees: expected['rotation_degrees'] as int,
      );
      _expectMatches(result, expected);
    });
  }

  test('video mode reproduces the official frame sequence', () async {
    final frames = (videoReference['cases'] as List)
        .cast<Map<String, dynamic>>();
    final video = await ObjectDetector.create(
      ObjectDetectorOptions(
        delegate: delegate,
        modelPath: _model,
        runningMode: RunningMode.video,
        scoreThreshold: _scoreThreshold,
        maxResults: _maxResults,
      ),
    );
    try {
      for (final expected in frames) {
        final result = await video.detectForVideo(
          fixtureImage(expected),
          timestampMilliseconds: expected['timestamp_ms'] as int,
          rotationDegrees: expected['rotation_degrees'] as int,
        );
        expect(result.timestampMilliseconds, expected['timestamp_ms']);
        _expectMatches(result, expected);
      }
    } finally {
      await video.dispose();
    }
  });

  test('image mode rejects a video call', () async {
    expect(
      () => detector.detectForVideo(
        fixtureImage(cases.first),
        timestampMilliseconds: 0,
      ),
      throwsStateError,
    );
  });
}

void _expectMatches(
  ObjectDetectorResult result,
  Map<String, dynamic> expected,
) {
  expect(result.imageWidth, expected['width']);
  expect(result.imageHeight, expected['height']);
  final detections = (expected['detections'] as List)
      .cast<Map<String, dynamic>>();
  expect(result.detections, hasLength(detections.length));
  for (var i = 0; i < detections.length; i++) {
    final object = result.detections[i];
    final box = detections[i]['bounding_box'] as Map<String, dynamic>;
    // MediaPipe's C API reports edges; the Python API reports an origin
    // and a size. Compare the same rectangle in both spellings.
    expect(object.boundingBox.left, closeTo(box['origin_x'] as num, 1));
    expect(object.boundingBox.top, closeTo(box['origin_y'] as num, 1));
    expect(object.boundingBox.width, closeTo(box['width'] as num, 1));
    expect(object.boundingBox.height, closeTo(box['height'] as num, 1));
    final categories = (detections[i]['categories'] as List)
        .cast<Map<String, dynamic>>();
    expect(object.categories, hasLength(categories.length));
    for (var j = 0; j < categories.length; j++) {
      final category = object.categories[j];
      final expectedCategory = categories[j];
      // The official Python API leaves an unspecified index as None; the C API
      // spells the same absence as -1.
      expect(category.index, expectedCategory['index'] ?? -1);
      expect(
        category.score,
        closeTo(expectedCategory['score'] as num, 0.00001),
      );
      expect(category.categoryName, expectedCategory['category_name']);
      expect(category.displayName, expectedCategory['display_name']);
    }
  }
}
