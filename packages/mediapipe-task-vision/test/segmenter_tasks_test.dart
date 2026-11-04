import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';
import 'package:test/test.dart';
import 'support/face_reference.dart';
import 'support/vision_fixture.dart';

const _fixtures = 'test/fixtures/face_detection';
final _models = {
  'image': ('models/deeplab_v3.tflite', VisionModels.imageSegmenter.sha256),
};
// DeepLab-v3's Pascal VOC order.
const _deepLabLabels = 21;
typedef _Task = (
  Future<Map<String, dynamic>> Function(VisionImage, int, int?),
  Future<void> Function(),
);

void main() {
  final reference = loadFaceReference(
    'segmenter_tasks',
    'official_reference.json',
  );
  final cases = (reference['cases'] as List).cast<Map<String, dynamic>>();
  setUpAll(() {
    for (final (name, row) in _models.entries.map((e) => (e.key, e.value))) {
      expect(sha256.convert(File(row.$1).readAsBytesSync()).toString(), row.$2);
      expect(reference['models'][name], row.$2);
    }
  });
  for (final expected in cases.where((c) => c['timestamp_ms'] == null)) {
    test(
      'official ${expected['task']} / ${expected['input']} / ${expected['options']}',
      () async {
        final (process, close) = await _create(expected);
        try {
          _compare(
            await process(
              _image(expected),
              expected['rotation_degrees'] as int,
              null,
            ),
            expected['result'],
          );
        } finally {
          await close();
        }
      },
      skip: cpuReferenceSkipReason,
    );
  }
  // The reference records one VIDEO sequence per mask selection.
  final videoFrames = <String, List<Map<String, dynamic>>>{};
  for (final c in cases.where(
    (c) => c['task'] == 'image' && c['timestamp_ms'] != null,
  )) {
    videoFrames.putIfAbsent('${c['options']}', () => []).add(c);
  }
  for (final MapEntry(key: options, value: frames) in videoFrames.entries) {
    test('image segmenter video / $options matches the official frames through '
        'queued disposal', () async {
      expect(frames, hasLength(3));
      final (process, close) = await _create(frames.first);
      final requests = [
        for (final frame in frames)
          process(_image(frame), 0, frame['timestamp_ms'] as int),
      ];
      final closing = close();
      expect(identical(closing, close()), isTrue);
      await expectLater(
        process(_image(frames.first), 0, 100),
        throwsStateError,
      );
      final results = await Future.wait(requests);
      await closing;
      for (var i = 0; i < frames.length; i++) {
        _compare(results[i], frames[i]['result']);
      }
    }, skip: cpuReferenceSkipReason);
  }
  test('the reference covers every mask selection in video mode', () {
    expect(videoFrames.keys, hasLength(3));
  });
  for (final name in _models.keys) {
    test(
      '$name native input/model errors leave later inference usable',
      () async {
        final expected = cases.firstWhere(
          (c) => c['task'] == name && c['input'] == 'file',
        );
        final (process, close) = await _create(expected);
        try {
          await expectLater(
            process(VisionImage.fromFile('missing-image.jpg'), 0, null),
            throwsA(isA<TaskException>()),
          );
          _compare(
            await process(_image(expected), 0, null),
            expected['result'],
          );
        } finally {
          await close();
        }
        await expectLater(
          _create(
            expected,
            modelBytes: Uint8List(32),
          ).timeout(const Duration(seconds: 10)),
          throwsA(isA<TaskException>()),
        );
        final (_, validClose) = await _create(expected);
        await validClose();
      },
      skip: cpuReferenceSkipReason,
    );
  }
  test('the model label list orders both mask kinds', () async {
    final expected = cases.firstWhere(
      (c) =>
          c['task'] == 'image' &&
          c['input'] == 'rgb' &&
          c['timestamp_ms'] == null,
    );
    final task = await ImageSegmenter.create(
      ImageSegmenterOptions(modelPath: _models['image']!.$1),
    );
    try {
      // The official Python bindings do not expose this list, so it is
      // checked against the model's documented categories, not an official
      // output.
      final result = await task.segment(_image(expected));
      expect(result.labels, hasLength(_deepLabLabels));
      expect(result.labels.first, 'background');
      expect(result.labels, contains('person'));
      expect(result.confidenceMasks, hasLength(_deepLabLabels));
      expect(() => result.labels.clear(), throwsUnsupportedError);
    } finally {
      await task.dispose();
    }
  }, skip: cpuReferenceSkipReason);
  // Image Segmenter's IMAGE mode on GPU, against the official GPU references
  // tool/prepare_gpu_reference.py --segmenter-tasks writes on this host (the
  // official macOS Metal path aborts in VIDEO mode; see its generator).
  group('GPU inference', () {
    final gpuReference = _gpuSkip == null
        ? loadFaceReference('segmenter_tasks', 'official_gpu_reference.json')
        : null;
    final gpuCases = [
      ...?(gpuReference?['cases'] as List?)?.cast<Map<String, dynamic>>(),
    ].where((c) => c['task'] == 'image' && c['timestamp_ms'] == null);
    tearDownAll(() => reportReferenceDeltas('image_segmenter'));
    for (final expected in gpuCases) {
      test(
        'official image / ${expected['input']} / ${expected['options']}',
        () async {
          final (process, close) = await _create(
            expected,
            delegate: Delegate.gpu,
          );
          try {
            _compare(
              await process(
                _image(expected),
                expected['rotation_degrees'] as int,
                null,
              ),
              expected['result'],
              'result',
              true,
            );
          } finally {
            await close();
          }
        },
      );
    }
  }, skip: _gpuSkip);

  test('options reject empty mask selections and malformed metadata', () {
    expect(
      () => ImageSegmenterOptions(
        modelPath: 'model',
        outputConfidenceMasks: false,
      ),
      throwsArgumentError,
    );
    expect(
      () => ImageSegmenterOptions(modelPath: 'model', displayNamesLocale: ''),
      throwsArgumentError,
    );
    expect(
      () => ImageSegmenterOptions(modelPath: 'model', modelBytes: Uint8List(4)),
      throwsArgumentError,
    );
    expect(
      () => Stroke(
        brushMode: BrushMode.positive,
        points: [NormalizedKeypoint(x: 1.5, y: 0.5)],
      ),
      throwsArgumentError,
    );
    expect(
      () => CategoryMask(width: 2, height: 2, categories: Uint8List(3)),
      throwsArgumentError,
    );
  });
}

VisionImage _image(Map<String, dynamic> expected) {
  if (expected['input'] == 'file') {
    final file = File('$_fixtures/${expected['file']}');
    expect(
      sha256.convert(file.readAsBytesSync()).toString(),
      expected['sha256'],
    );
    return VisionImage.fromFile(file.path);
  }
  // Every pixel case is the portrait, 301 by 209, or a blank of its size.
  final pixels = File('$_fixtures/portrait-301x209.rgb').readAsBytesSync();
  if (expected['input'] != 'blank') {
    expect(sha256.convert(pixels).toString(), expected['sha256']);
  }
  return pixelsImage(
    pixels,
    width: 301,
    height: 209,
    input: expected['input'] as String,
  );
}

Future<_Task> _create(
  Map<String, dynamic> expected, {
  Uint8List? modelBytes,
  Delegate delegate = Delegate.cpu,
}) async {
  final options = expected['options'] as Map<String, dynamic>;
  final name = expected['task'] as String;
  final modelPath = modelBytes == null ? _models[name]!.$1 : null;
  final confidence = options['output_confidence_masks'] as bool;
  final category = options['output_category_mask'] as bool;
  if (name == 'image') {
    final task = await ImageSegmenter.create(
      ImageSegmenterOptions(
        modelPath: modelPath,
        modelBytes: modelBytes,
        runningMode: expected['timestamp_ms'] == null
            ? RunningMode.image
            : RunningMode.video,
        outputConfidenceMasks: confidence,
        outputCategoryMask: category,
        delegate: delegate,
      ),
    );
    return (
      (image, rotation, timestamp) async => _summary(
        timestamp == null
            ? await task.segment(image, rotationDegrees: rotation)
            : await task.segmentForVideo(
                image,
                rotationDegrees: rotation,
                timestampMilliseconds: timestamp,
              ),
        image,
        timestamp,
      ),
      task.dispose,
    );
  }
  throw StateError('Unexpected task ${expected['task']}');
}

Map<String, dynamic> _summary(
  ImageSegmenterResult result,
  VisionImage image,
  int? timestamp,
) {
  if (image.width != null) {
    expect(result.imageWidth, image.width);
    expect(result.imageHeight, image.height);
  }
  expect(result.timestampMilliseconds, timestamp);
  if (result.confidenceMasks case final masks?) {
    expect(() => masks.clear(), throwsUnsupportedError);
  }
  if (result.qualityScores case final scores?) {
    expect(scores.every((value) => value >= 0 && value <= 1), isTrue);
    expect(() => scores[0] = 2, throwsUnsupportedError);
  }
  return {
    'confidence_masks': result.confidenceMasks
        ?.map((mask) => _mask(mask.width, mask.height, mask.confidence))
        .toList(),
    'category_mask': result.categoryMask == null
        ? null
        : _mask(
            result.categoryMask!.width,
            result.categoryMask!.height,
            result.categoryMask!.categories,
          ),
  };
}

/// The same native library fills both sides on one host, so the mask bytes
/// match exactly; the statistics only make a mismatch readable.
Map<String, dynamic> _mask(int width, int height, List<num> values) {
  expect(values, hasLength(width * height));
  var minimum = double.infinity;
  var maximum = double.negativeInfinity;
  var sum = 0.0;
  for (final value in values) {
    final number = value.toDouble();
    expect(number.isFinite, isTrue);
    if (number < minimum) minimum = number;
    if (number > maximum) maximum = number;
    sum += number;
  }
  final bytes = values is Float32List
      ? Float32List.fromList(values).buffer.asUint8List()
      : Uint8List.fromList(values.cast<int>());
  return {
    'width': width,
    'height': height,
    'sha256': sha256.convert(bytes).toString(),
    'minimum': minimum,
    'maximum': maximum,
    'mean': sum / values.length,
  };
}

void _compare(
  dynamic actual,
  dynamic expected, [
  String path = 'result',
  bool gpu = false,
]) {
  if (expected is Map) {
    expect(actual, isA<Map>(), reason: path);
    expect((actual as Map).keys, unorderedEquals(expected.keys), reason: path);
    for (final key in expected.keys) {
      // GPU masks come from another process's GPU run: the statistics are
      // compared, their exact bytes are not.
      if (gpu && key == 'sha256') continue;
      _compare(actual[key], expected[key], '$path.$key', gpu);
    }
  } else if (expected is List) {
    expect(actual, isA<List>(), reason: path);
    expect(actual, hasLength(expected.length), reason: path);
    for (var i = 0; i < expected.length; i++) {
      _compare(actual[i], expected[i], '$path[$i]', gpu);
    }
  } else if (expected is num && gpu && actual is num) {
    final group = path.contains('category_mask')
        ? 'category_mask'
        : 'confidence_masks';
    recordReferenceDelta(
      'image_segmenter',
      'gpu',
      group,
      path,
      actual,
      expected,
    );
    expect(actual, closeTo(expected, _gpuTolerances[group]!), reason: path);
  } else if (expected is double) {
    expect(actual, closeTo(expected, 0.00001), reason: path);
  } else {
    expect(actual, expected, reason: path);
  }
}

// Mask statistics on GPU against Google's own GPU masks from the same host:
// confidences in 0 to 1, category indices (a mean moves when an outline pixel
// changes class).
const _gpuTolerances = {'confidence_masks': 0.01, 'category_mask': 0.05};

/// Why the GPU comparisons cannot run on this host, or null when they can.
final _gpuSkip = Platform.isMacOS
    ? macosGpuWithdrawn
    : Platform.environment['MEDIAPIPE_GPU_REFERENCE_DIR'] == null
    ? 'GPU Image Segmenter compares with same-host official GPU outputs '
          '(MEDIAPIPE_GPU_REFERENCE_DIR).'
    : Platform.isLinux
    ? null
    : 'Desktop GPU is validated on Linux.';
