import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';
import 'package:test/test.dart';

import 'support/vision_fixture.dart';
import 'support/face_reference.dart';

const _model = 'models/face_landmarker.task';
const _fixtures = 'test/fixtures/face_detection';
final _reference = loadFaceReference(
  'face_landmarker',
  'official_reference.json',
);

void main() {
  for (final delegate in Delegate.values) {
    group(
      delegate.name,
      () => _testDelegate(delegate),
      skip: delegate == Delegate.gpu && !gpuFaceTestsEnabled
          ? gpuFaceTestsSkipReason
          : false,
    );
  }
  test('CPU is the default delegate', () {
    expect(FaceLandmarkerOptions(modelPath: _model).delegate, Delegate.cpu);
  });
  test(
    'a refused GPU is reported, never replaced by CPU',
    () async {
      // CI runs this on llvmpipe without the renamed renderer, which Google's
      // Linux runtime refuses by name.
      await expectLater(
        FaceLandmarker.create(
          FaceLandmarkerOptions(modelPath: _model, delegate: Delegate.gpu),
        ),
        throwsA(
          isA<TaskException>()
              .having((error) => error.gpuUnavailable, 'gpuUnavailable', true)
              .having(
                (error) => error.message,
                'message',
                contains('kGpuService'),
              ),
        ),
      );
    },
    skip: Platform.environment['MEDIAPIPE_EXPECT_GPU_REFUSAL'] == null
        ? 'Set MEDIAPIPE_EXPECT_GPU_REFUSAL on a host that refuses the GPU.'
        : false,
  );
  tearDownAll(() => reportReferenceDeltas('face_landmarker'));
}

void _testDelegate(Delegate delegate) {
  void compare(FaceLandmarkerResult actual, Map<String, dynamic> expected) =>
      _compare(actual, expected, delegate);
  final reference = delegate == Delegate.cpu
      ? _reference
      : loadFaceReference('face_landmarker', 'official_gpu_reference.json');
  final cases = (reference['cases'] as List).cast<Map<String, dynamic>>();
  final rgbFrame = (cases.first['frames'] as List)
      .cast<Map<String, dynamic>>()
      .singleWhere((frame) => frame['name'] == 'rgb');
  setUpAll(() {
    expect(
      sha256.convert(File(_model).readAsBytesSync()).toString(),
      VisionModels.faceLandmarker.sha256,
    );
    expect(reference['model_sha256'], VisionModels.faceLandmarker.sha256);
    expect(reference['delegate'], delegate.name.toUpperCase());
  });

  for (final sequence in cases) {
    test(
      'official ${sequence['mode']} reference with ${sequence['num_faces']} faces',
      () async {
        final video = sequence['mode'] == 'VIDEO';
        final task = await FaceLandmarker.create(
          FaceLandmarkerOptions(
            delegate: delegate,
            modelPath: _model,
            runningMode: video ? RunningMode.video : RunningMode.image,
            numFaces: sequence['num_faces'] as int,
            outputFaceBlendshapes: true,
            outputFacialTransformationMatrixes: true,
          ),
        );
        expect(task.delegate, delegate);
        final frames = (sequence['frames'] as List)
            .cast<Map<String, dynamic>>();
        final requests = [
          for (final frame in frames)
            video
                ? task.detectForVideo(
                    _image(frame),
                    timestampMilliseconds: frame['timestamp_ms'] as int,
                    rotationDegrees: frame['rotation'] as int,
                  )
                : task.detect(
                    _image(frame),
                    rotationDegrees: frame['rotation'] as int,
                  ),
        ];
        final closing = task.dispose();
        expect(identical(closing, task.dispose()), isTrue);
        await expectLater(task.detect(_image(rgbFrame)), throwsStateError);
        final results = await Future.wait(requests);
        await closing;
        for (var i = 0; i < frames.length; i++) {
          compare(results[i], frames[i]);
        }
        final face = results.first.faceLandmarks.first;
        expect(() => face.clear(), throwsUnsupportedError);
        expect(
          () => results.first.faceLandmarks.clear(),
          throwsUnsupportedError,
        );
        expect(
          () => results.first.faceBlendshapes.first.clear(),
          throwsUnsupportedError,
        );
        expect(
          () => results.first.facialTransformationMatrixes.first.data.clear(),
          throwsUnsupportedError,
        );
      },
    );
  }

  test('model bytes are owned and optional outputs default to empty', () async {
    final bytes = File(_model).readAsBytesSync();
    final options = FaceLandmarkerOptions(
      delegate: delegate,
      modelBytes: bytes,
    );
    bytes.fillRange(0, bytes.length, 0);
    final task = await FaceLandmarker.create(options);
    try {
      final result = await task.detect(_image(rgbFrame));
      compare(result, {
        ...rgbFrame,
        'face_blendshapes': [],
        'facial_transformation_matrixes': [],
      });
    } finally {
      await task.dispose();
    }
  });

  test(
    'detector and landmarker coexist in one process with independent lifetimes',
    () async {
      // Where Face Detector's GPU is withdrawn (Linux, UP-046), its CPU runs
      // beside the GPU landmarker.
      final detectorCapabilities = await queryFaceDetectorCapabilities();
      final detector = await FaceDetector.create(
        FaceDetectorOptions(
          delegate: detectorCapabilities.supportedDelegates.contains(delegate)
              ? delegate
              : Delegate.cpu,
          modelPath: 'models/blaze_face_short_range.tflite',
        ),
      );
      final landmarker = await FaceLandmarker.create(
        FaceLandmarkerOptions(delegate: delegate, modelPath: _model),
      );
      try {
        for (var i = 0; i < 3; i++) {
          final results = await Future.wait<Object>([
            detector.detect(_image(rgbFrame)),
            landmarker.detect(_image(rgbFrame)),
          ]);
          expect(
            (results[0] as FaceDetectorResult).detections.single.keypoints,
            hasLength(6),
          );
          expect(
            (results[1] as FaceLandmarkerResult).faceLandmarks.single,
            hasLength(478),
          );
        }
        await detector.dispose();
        expect(
          (await landmarker.detect(_image(rgbFrame))).faceLandmarks.single,
          hasLength(478),
        );
      } finally {
        await detector.dispose();
        await landmarker.dispose();
      }
    },
  );

  for (final format in VisionPixelFormat.values) {
    test(
      'padded ${format.name} camera frames preserve the landmark coordinates',
      () async {
        final rgb = _image(rgbFrame).pixels!;
        final stride = 301 * format.channels + 20;
        final pixels = Uint8List(stride * 209)..fillRange(0, stride * 209, 127);
        for (var y = 0; y < 209; y++) {
          for (var x = 0; x < 301; x++) {
            final source = (y * 301 + x) * 3;
            final target = y * stride + x * format.channels;
            pixels[target] =
                rgb[source + (format == VisionPixelFormat.bgra ? 2 : 0)];
            pixels[target + 1] = rgb[source + 1];
            pixels[target + 2] =
                rgb[source + (format == VisionPixelFormat.bgra ? 0 : 2)];
            if (format.channels == 4) pixels[target + 3] = 255;
          }
        }
        final task = await FaceLandmarker.create(
          FaceLandmarkerOptions(
            delegate: delegate,
            modelPath: _model,
            numFaces: 2,
            outputFaceBlendshapes: true,
            outputFacialTransformationMatrixes: true,
          ),
        );
        try {
          final image = VisionImage.fromPixels(
            pixels: pixels,
            width: 301,
            height: 209,
            format: format,
            bytesPerRow: stride,
          );
          pixels.fillRange(0, pixels.length, 0);
          compare(await task.detect(image), rgbFrame);
        } finally {
          await task.dispose();
        }
      },
    );
  }

  test(
    'mode, timestamps, rotation and native errors leave video task usable',
    () async {
      final task = await FaceLandmarker.create(
        FaceLandmarkerOptions(
          delegate: delegate,
          modelPath: _model,
          runningMode: RunningMode.video,
        ),
      );
      try {
        await expectLater(task.detect(_image(rgbFrame)), throwsStateError);
        await task.detectForVideo(_image(rgbFrame), timestampMilliseconds: 10);
        for (final timestamp in [-1, 9, 10, 0x7fffffffffffffff]) {
          await expectLater(
            task.detectForVideo(
              _image(rgbFrame),
              timestampMilliseconds: timestamp,
            ),
            throwsArgumentError,
          );
        }
        await expectLater(
          task.detectForVideo(
            _image(rgbFrame),
            timestampMilliseconds: 11,
            rotationDegrees: 45,
          ),
          throwsArgumentError,
        );
        await expectLater(
          task.detectForVideo(
            VisionImage.fromFile('missing.jpg'),
            timestampMilliseconds: 11,
          ),
          throwsA(isA<TaskException>()),
        );
        await expectLater(
          task.detectForVideo(_image(rgbFrame), timestampMilliseconds: 11),
          throwsArgumentError,
        );
        expect(
          (await task.detectForVideo(
            _image(rgbFrame),
            timestampMilliseconds: 12,
          )).faceLandmarks.single,
          hasLength(478),
        );
      } finally {
        await task.dispose();
      }
    },
  );

  test(
    'invalid initialization fails promptly; later creation still succeeds',
    () async {
      for (final options in [
        FaceLandmarkerOptions(delegate: delegate, modelPath: 'missing.task'),
        FaceLandmarkerOptions(delegate: delegate, modelBytes: Uint8List(32)),
      ]) {
        await expectLater(
          FaceLandmarker.create(options).timeout(const Duration(seconds: 10)),
          throwsA(isA<TaskException>()),
        );
      }
      final task = await FaceLandmarker.create(
        FaceLandmarkerOptions(delegate: delegate, modelPath: _model),
      );
      try {
        await expectLater(
          task.detectForVideo(_image(rgbFrame), timestampMilliseconds: 0),
          throwsStateError,
        );
        expect(
          (await task.detect(_image(rgbFrame))).faceLandmarks.single,
          hasLength(478),
        );
      } finally {
        await task.dispose();
      }
    },
  );

  test(
    'options reject malformed model sources, face counts and thresholds',
    () {
      expect(
        () => FaceLandmarkerOptions(delegate: delegate),
        throwsArgumentError,
      );
      expect(
        () => FaceLandmarkerOptions(
          delegate: delegate,
          modelPath: _model,
          modelBytes: Uint8List(1),
        ),
        throwsArgumentError,
      );
      expect(
        () =>
            FaceLandmarkerOptions(delegate: delegate, modelBytes: Uint8List(0)),
        throwsArgumentError,
      );
      expect(
        () => FaceLandmarkerOptions(
          delegate: delegate,
          modelPath: 'bad\u0000path',
        ),
        throwsArgumentError,
      );
      for (final count in [0, -1, 0x80000000]) {
        expect(
          () => FaceLandmarkerOptions(
            delegate: delegate,
            modelPath: _model,
            numFaces: count,
          ),
          throwsArgumentError,
        );
      }
      for (final confidence in [-0.1, 1.1, double.nan, double.infinity]) {
        expect(
          () => FaceLandmarkerOptions(
            delegate: delegate,
            modelPath: _model,
            minFaceDetectionConfidence: confidence,
          ),
          throwsArgumentError,
        );
        expect(
          () => FaceLandmarkerOptions(
            delegate: delegate,
            modelPath: _model,
            minFacePresenceConfidence: confidence,
          ),
          throwsArgumentError,
        );
        expect(
          () => FaceLandmarkerOptions(
            delegate: delegate,
            modelPath: _model,
            minTrackingConfidence: confidence,
          ),
          throwsArgumentError,
        );
      }
    },
  );
}

VisionImage _image(Map<String, dynamic> frame) {
  final name = frame['name'] as String;
  if (name.endsWith('.jpg') || name.endsWith('.jpeg')) {
    final manifest =
        jsonDecode(File('$_fixtures/manifest.json').readAsStringSync())
            as Map<String, dynamic>;
    final entry = (manifest['files'] as List)
        .cast<Map<String, dynamic>>()
        .singleWhere((file) => file['file'] == name);
    return fixtureImage({...frame, ...entry});
  }
  return fixtureImage({
    ...frame,
    'name': {'rotated': 'rgb-rotated', 'pair': 'rgb-pair'}[name] ?? name,
    if (name != 'blank') 'raw': 'portrait-301x209.rgb',
    'sha256': _reference['raw_sha256'],
  });
}

void _compare(
  FaceLandmarkerResult actual,
  Map<String, dynamic> expected,
  Delegate delegate,
) {
  // Measured against the independent wheel, separately for each backend.
  // See fixtures/face_landmarker/README.md for observed maxima and provenance.
  final gpu = delegate == Delegate.gpu;
  final name = expected['name'] as String;
  void close(
    num measured,
    num official,
    num tolerance,
    String group,
    String at,
  ) {
    recordReferenceDelta(
      'face_landmarker',
      delegate.name,
      group,
      '$name.$at',
      measured,
      official,
    );
    expect(measured, closeTo(official, tolerance), reason: '$name.$at');
  }

  expect(actual.imageWidth, expected['width']);
  expect(actual.imageHeight, expected['height']);
  expect(actual.timestampMilliseconds, expected['timestamp_ms']);
  final faces = expected['face_landmarks'] as List;
  expect(
    actual.faceLandmarks,
    hasLength(faces.length),
    reason: expected['name'] as String,
  );
  for (var i = 0; i < faces.length; i++) {
    final points = faces[i] as List;
    expect(actual.faceLandmarks[i], hasLength(478));
    expect(points, hasLength(478));
    for (var j = 0; j < points.length; j++) {
      final point = points[j] as Map<String, dynamic>;
      final value = actual.faceLandmarks[i][j];
      final tolerance = gpu ? 0.002 : 0.0001;
      const group = 'face_landmarks';
      close(value.x, point['x'] as num, tolerance, group, 'faces[$i][$j].x');
      close(value.y, point['y'] as num, tolerance, group, 'faces[$i][$j].y');
      close(value.z, point['z'] as num, tolerance, group, 'faces[$i][$j].z');
      expect(value.visibility, point['visibility']);
      expect(value.presence, point['presence']);
      expect(value.name, point['name']);
    }
  }
  final expressions = expected['face_blendshapes'] as List;
  expect(actual.faceBlendshapes, hasLength(expressions.length));
  for (var i = 0; i < expressions.length; i++) {
    final categories = expressions[i] as List;
    expect(actual.faceBlendshapes[i], hasLength(52));
    for (var j = 0; j < categories.length; j++) {
      final value = actual.faceBlendshapes[i][j];
      final category = categories[j] as Map<String, dynamic>;
      expect(value.index, category['index']);
      close(
        value.score,
        category['score'] as num,
        gpu ? 0.04 : 0.002,
        'face_blendshapes',
        'faces[$i][$j].score',
      );
      expect(value.categoryName, category['category_name']);
      expect(value.displayName, category['display_name']);
    }
  }
  final matrices = expected['facial_transformation_matrixes'] as List;
  expect(actual.facialTransformationMatrixes, hasLength(matrices.length));
  for (var i = 0; i < matrices.length; i++) {
    final matrix = actual.facialTransformationMatrixes[i];
    expect(matrix.rows, 4);
    expect(matrix.columns, 4);
    for (var row = 0; row < 4; row++) {
      for (var column = 0; column < 4; column++) {
        // Python exposes row/column indexing; C stores the same data column-major.
        close(
          matrix.at(row, column),
          (matrices[i] as List)[row][column] as num,
          gpu ? 0.06 : 0.005,
          'facial_transformation_matrixes',
          'matrixes[$i][$row][$column]',
        );
      }
    }
  }
}
