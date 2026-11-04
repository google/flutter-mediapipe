import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';
import 'package:test/test.dart';
import 'support/face_reference.dart';
import 'support/vision_fixture.dart';

const _fixtures = 'test/fixtures/landmark_tasks';
final _models = {
  'hand': ('models/hand_landmarker.task', VisionModels.handLandmarker.sha256),
  'gesture': (
    'models/gesture_recognizer.task',
    VisionModels.gestureRecognizer.sha256,
  ),
  'pose': (
    'models/pose_landmarker_lite.task',
    VisionModels.poseLandmarker.sha256,
  ),
  'holistic': (
    'models/holistic_landmarker.task',
    VisionModels.holisticLandmarker.sha256,
  ),
};
typedef _Task = (
  Future<Map<String, dynamic>> Function(VisionImage, int, int?),
  Future<void> Function(),
);
final _selectedTasks =
    switch (Platform.environment['MEDIAPIPE_LANDMARK_TASKS']) {
      final value? => value.split(',').toSet(),
      null => _models.keys.toSet(),
    };

// Each selected task's GPU output is compared with the official wheel's GPU
// output for the cases that reference holds: on Linux, same-host ones
// (MEDIAPIPE_GPU_REFERENCE_DIR, from tool/prepare_gpu_reference.py
// --landmark-tasks or --hand). macOS runs none ([macosGpuWithdrawn]); its
// checked-in physical-Mac hand references stay for when the GPU returns.
final _gpuSkip = Platform.isMacOS
    ? macosGpuWithdrawn
    : Platform.isLinux &&
          Platform.environment['MEDIAPIPE_GPU_REFERENCE_DIR'] != null
    ? null
    : 'Landmark GPU is validated on Linux against same-host references '
          '(MEDIAPIPE_GPU_REFERENCE_DIR).';

void main() {
  final reference = loadFaceReference(
    'landmark_tasks',
    'official_reference.json',
  );
  final cases = (reference['cases'] as List).cast<Map<String, dynamic>>();
  setUpAll(() {
    for (final (name, row)
        in _models.entries
            .where((entry) => _selectedTasks.contains(entry.key))
            .map((e) => (e.key, e.value))) {
      expect(sha256.convert(File(row.$1).readAsBytesSync()).toString(), row.$2);
      expect(reference['models'][name], row.$2);
    }
  });
  tearDownAll(() {
    for (final task in _selectedTasks) {
      reportReferenceDeltas(task);
    }
  });
  for (final expected in cases.where(
    (c) => c['timestamp_ms'] == null && _selectedTasks.contains(c['task']),
  )) {
    test(
      'official ${expected['task']} / ${expected['input']} / ${expected['file']} / ${expected['options']}',
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
            expected['task'] as String,
          );
        } finally {
          await close();
        }
      },
      skip: cpuReferenceSkipReason,
    );
  }
  for (final name in _models.keys.where(_selectedTasks.contains)) {
    test(
      '$name video matches tracked and empty frames through queued disposal',
      () async {
        final frames = cases
            .where(
              (c) =>
                  c['task'] == name &&
                  c['timestamp_ms'] != null &&
                  (c['options'] as Map)['min_hand_landmarks_confidence'] ==
                      null,
            )
            .toList();
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
          _compare(results[i], frames[i]['result'], name);
        }
      },
      skip: cpuReferenceSkipReason,
    );
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
            name,
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
  group('gpu', () {
    final reference = _gpuSkip == null
        ? loadFaceReference('landmark_tasks', 'official_gpu_reference.json')
        : null;
    final cases = [
      ...?(reference?['cases'] as List?)?.cast<Map<String, dynamic>>(),
    ].where((c) => _selectedTasks.contains(c['task'])).toList();
    for (final expected in cases.where((c) => c['timestamp_ms'] == null)) {
      test(
        'official ${expected['task']} / ${expected['input']} / ${expected['file']} / ${expected['options']}',
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
              expected['task'] as String,
              gpu: true,
            );
          } finally {
            await close();
          }
        },
      );
    }
    for (final name in {
      for (final c in cases)
        if (c['timestamp_ms'] != null) c['task'] as String,
    }) {
      test('$name video matches tracked and empty frames', () async {
        final frames = cases
            .where(
              (c) =>
                  c['task'] == name &&
                  c['timestamp_ms'] != null &&
                  (c['options'] as Map)['min_hand_landmarks_confidence'] ==
                      null,
            )
            .toList();
        final (process, close) = await _create(
          frames.first,
          delegate: Delegate.gpu,
        );
        try {
          for (final frame in frames) {
            _compare(
              await process(_image(frame), 0, frame['timestamp_ms'] as int),
              frame['result'],
              name,
              gpu: true,
            );
          }
        } finally {
          await close();
        }
      });
    }
  }, skip: _gpuSkip);
  test(
    'invalid model tracking and classification options fail before native calls',
    () {
      expect(
        () => HandLandmarkerOptions(modelPath: 'model', numHands: 0),
        throwsArgumentError,
      );
      expect(
        () => PoseLandmarkerOptions(modelPath: 'model', numPoses: 0x80000000),
        throwsArgumentError,
      );
      expect(
        () => GestureRecognizerOptions(
          modelPath: 'model',
          minHandDetectionConfidence: double.nan,
        ),
        throwsArgumentError,
      );
      expect(
        () => HolisticLandmarkerOptions(
          modelPath: 'model',
          minPosePresenceConfidence: 1.1,
        ),
        throwsArgumentError,
      );
      expect(
        () => ClassifierOptions(
          categoryAllowlist: ['a'],
          categoryDenylist: ['b'],
        ),
        throwsArgumentError,
      );
      expect(
        () => ClassifierOptions(displayNamesLocale: 'en\u0000US'),
        throwsArgumentError,
      );
    },
  );
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
  final pixels = File('$_fixtures/${expected['raw']}').readAsBytesSync();
  expect(sha256.convert(pixels).toString(), expected['raw_sha256']);
  // A rotated case gives its image's size; the raw file is the other way up.
  final rotated = expected['input'] == 'rotated';
  return pixelsImage(
    pixels,
    width: expected[rotated ? 'height' : 'width'] as int,
    height: expected[rotated ? 'width' : 'height'] as int,
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
  final mode = expected['timestamp_ms'] == null
      ? RunningMode.image
      : RunningMode.video;
  switch (name) {
    case 'hand':
      final task = await HandLandmarker.create(
        HandLandmarkerOptions(
          modelPath: modelPath,
          modelBytes: modelBytes,
          runningMode: mode,
          delegate: delegate,
          numHands: options['num_hands'] as int,
        ),
      );
      return (
        (image, rotation, timestamp) async {
          final r = timestamp == null
              ? await task.detect(image, rotationDegrees: rotation)
              : await task.detectForVideo(
                  image,
                  rotationDegrees: rotation,
                  timestampMilliseconds: timestamp,
                );
          _size(
            r.imageWidth,
            r.imageHeight,
            r.timestampMilliseconds,
            image,
            timestamp,
          );
          return {
            'handedness': _categories(r.handedness),
            'hand_landmarks': _landmarks(r.handLandmarks),
            'hand_world_landmarks': _landmarks(r.handWorldLandmarks),
          };
        },
        task.dispose,
      );
    case 'gesture':
      final task = await GestureRecognizer.create(
        GestureRecognizerOptions(
          modelPath: modelPath,
          modelBytes: modelBytes,
          runningMode: mode,
          delegate: delegate,
          numHands: options['num_hands'] as int,
        ),
      );
      return (
        (image, rotation, timestamp) async {
          final r = timestamp == null
              ? await task.recognize(image, rotationDegrees: rotation)
              : await task.recognizeForVideo(
                  image,
                  rotationDegrees: rotation,
                  timestampMilliseconds: timestamp,
                );
          _size(
            r.imageWidth,
            r.imageHeight,
            r.timestampMilliseconds,
            image,
            timestamp,
          );
          return {
            'gestures': _categories(r.gestures),
            'handedness': _categories(r.handedness),
            'hand_landmarks': _landmarks(r.handLandmarks),
            'hand_world_landmarks': _landmarks(r.handWorldLandmarks),
          };
        },
        task.dispose,
      );
    case 'pose':
      final task = await PoseLandmarker.create(
        PoseLandmarkerOptions(
          modelPath: modelPath,
          modelBytes: modelBytes,
          runningMode: mode,
          delegate: delegate,
          outputSegmentationMasks: options['output_segmentation_masks'] as bool,
        ),
      );
      return (
        (image, rotation, timestamp) async {
          final r = timestamp == null
              ? await task.detect(image, rotationDegrees: rotation)
              : await task.detectForVideo(
                  image,
                  rotationDegrees: rotation,
                  timestampMilliseconds: timestamp,
                );
          _size(
            r.imageWidth,
            r.imageHeight,
            r.timestampMilliseconds,
            image,
            timestamp,
          );
          if (r.segmentationMasks case final masks?) {
            expect(() => masks.clear(), throwsUnsupportedError);
          }
          return {
            'pose_landmarks': _landmarks(r.poseLandmarks),
            'pose_world_landmarks': _landmarks(r.poseWorldLandmarks),
            'segmentation_masks': r.segmentationMasks?.map(_mask).toList(),
          };
        },
        task.dispose,
      );
    case 'holistic':
      final task = await HolisticLandmarker.create(
        HolisticLandmarkerOptions(
          modelPath: modelPath,
          modelBytes: modelBytes,
          runningMode: mode,
          delegate: delegate,
          outputFaceBlendshapes: options['output_face_blendshapes'] as bool,
          outputPoseSegmentationMask:
              options['output_segmentation_mask'] as bool,
          minHandLandmarksConfidence:
              (options['min_hand_landmarks_confidence'] as num?)?.toDouble() ??
              0.5,
          minPoseDetectionConfidence:
              (options['min_pose_detection_confidence'] as num?)?.toDouble() ??
              0.5,
          minPoseSuppressionThreshold:
              (options['min_pose_suppression_threshold'] as num?)?.toDouble() ??
              0.5,
          minPosePresenceConfidence:
              (options['min_pose_landmarks_confidence'] as num?)?.toDouble() ??
              0.5,
        ),
      );
      return (
        (image, rotation, timestamp) async {
          final r = timestamp == null
              ? await task.detect(image, rotationDegrees: rotation)
              : await task.detectForVideo(
                  image,
                  rotationDegrees: rotation,
                  timestampMilliseconds: timestamp,
                );
          _size(
            r.imageWidth,
            r.imageHeight,
            r.timestampMilliseconds,
            image,
            timestamp,
          );
          return {
            'face_landmarks': _points(r.faceLandmarks),
            'pose_landmarks': _points(r.poseLandmarks),
            'pose_world_landmarks': _points(r.poseWorldLandmarks),
            'left_hand_landmarks': _points(r.leftHandLandmarks),
            'right_hand_landmarks': _points(r.rightHandLandmarks),
            'left_hand_world_landmarks': _points(r.leftHandWorldLandmarks),
            'right_hand_world_landmarks': _points(r.rightHandWorldLandmarks),
            'face_blendshapes': r.faceBlendshapes == null
                ? null
                : _categoryList(r.faceBlendshapes!),
            'segmentation_mask': r.poseSegmentationMask == null
                ? null
                : _mask(r.poseSegmentationMask!),
          };
        },
        task.dispose,
      );
    default:
      throw StateError('Unknown fixture task $name');
  }
}

void _size(
  int width,
  int height,
  int? actualTimestamp,
  VisionImage image,
  int? timestamp,
) {
  if (image.width != null) {
    expect(width, image.width);
    expect(height, image.height);
  }
  expect(actualTimestamp, timestamp);
}

List<List<Map<String, dynamic>>> _landmarks(List<List<Object>> values) {
  expect(() => values.clear(), throwsUnsupportedError);
  return values.map(_points).toList();
}

/// Image or world landmarks, which share their fields.
List<Map<String, dynamic>> _points(List<Object> values) {
  expect(() => values.clear(), throwsUnsupportedError);
  return [
    for (final dynamic v in values)
      {
        'x': v.x,
        'y': v.y,
        'z': v.z,
        'visibility': v.visibility,
        'presence': v.presence,
        'name': v.name,
      },
  ];
}

List<List<Map<String, dynamic>>> _categories(
  List<List<MediaPipeCategory>> values,
) {
  expect(() => values.clear(), throwsUnsupportedError);
  return values.map(_categoryList).toList();
}

List<Map<String, dynamic>> _categoryList(List<MediaPipeCategory> values) {
  expect(() => values.clear(), throwsUnsupportedError);
  return [
    for (final v in values)
      {
        'index': v.index,
        'score': v.score,
        'category_name': v.categoryName,
        'display_name': v.displayName,
      },
  ];
}

Map<String, dynamic> _mask(ConfidenceMask mask) {
  final values = mask.confidence;
  expect(() => values[0] = 0, throwsUnsupportedError);
  var minimum = double.infinity;
  var maximum = double.negativeInfinity;
  var sum = 0.0;
  for (final value in values) {
    expect(value.isFinite, isTrue);
    if (value < minimum) minimum = value;
    if (value > maximum) maximum = value;
    sum += value;
  }
  return {
    'width': mask.width,
    'height': mask.height,
    'minimum': minimum,
    'maximum': maximum,
    'mean': sum / values.length,
    'samples': [
      for (var y = 0; y < mask.height; y += 17)
        for (var x = 0; x < mask.width; x += 19) values[y * mask.width + x],
    ],
  };
}

void _compare(
  dynamic actual,
  dynamic expected,
  String task, {
  String path = 'result',
  bool gpu = false,
}) {
  if (expected is Map) {
    expect(actual, isA<Map>(), reason: path);
    expect((actual as Map).keys, unorderedEquals(expected.keys), reason: path);
    for (final key in expected.keys) {
      _compare(actual[key], expected[key], task, path: '$path.$key', gpu: gpu);
    }
  } else if (expected is List) {
    expect(actual, isA<List>(), reason: path);
    expect(actual, hasLength(expected.length), reason: path);
    for (var i = 0; i < expected.length; i++) {
      _compare(actual[i], expected[i], task, path: '$path[$i]', gpu: gpu);
    }
  } else if (expected is double) {
    final group = path.contains('world_landmarks')
        ? 'world_landmarks'
        : path.contains('landmark')
        ? 'landmarks'
        : 'other';
    recordReferenceDelta(
      task,
      gpu ? 'gpu' : 'cpu',
      group,
      path,
      actual as num,
      expected,
    );
    expect(
      actual,
      closeTo(expected, gpu ? _gpuTolerances[group]! : 0.00001),
      reason: path,
    );
  } else {
    expect(actual, expected, reason: path);
  }
}

// GPU against the official wheel's GPU output on the same host. See
// fixtures/landmark_tasks/README.md for the measured maxima behind these
// (Hand; the other tasks' deltas are reported by reportReferenceDeltas).
const _gpuTolerances = {
  'landmarks': 0.002,
  'world_landmarks': 0.002,
  'other': 0.04,
};
