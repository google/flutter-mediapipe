import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:ffi/ffi.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';
import 'package:mediapipe_vision/src/third_party/mediapipe/vision_bindings.dart'
    as mp;
import 'package:test/test.dart';

import 'support/face_reference.dart' show gpuFaceTestsEnabled;

const fixtures = 'test/fixtures/interactive_segmentation';
const model = 'models/interactive_segmentation.task';
late Map<String, dynamic> reference;
late Uint8List rgb;

List<Stroke> strokes(Map<String, dynamic> entry) => [
  for (final dynamic stroke in entry['strokes'])
    Stroke(
      brushMode: BrushMode.values.byName(stroke['brush_mode'] as String),
      points: [
        for (final dynamic point in stroke['points'])
          NormalizedKeypoint(
            x: (point[0] as num).toDouble(),
            y: (point[1] as num).toDouble(),
          ),
      ],
      isCompleted: stroke['is_completed'] as bool,
    ),
];

VisionImage input(String kind, {int padding = 0, bool bgra = false}) {
  if (kind == 'file') {
    return VisionImage.fromFile('$fixtures/cats_and_dogs.jpg');
  }
  final width = reference['raw']['width'] as int;
  final height = reference['raw']['height'] as int;
  final channels = kind == 'rgba' || bgra ? 4 : 3;
  final stride = width * channels + padding;
  final bytes = Uint8List(height * stride)..fillRange(0, height * stride, 197);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final source = (y * width + x) * 3;
      final target = y * stride + x * channels;
      bytes[target] = kind == 'blank' ? 0 : rgb[source + (bgra ? 2 : 0)];
      bytes[target + 1] = kind == 'blank' ? 0 : rgb[source + 1];
      bytes[target + 2] = kind == 'blank' ? 0 : rgb[source + (bgra ? 0 : 2)];
      if (channels == 4) bytes[target + 3] = 255;
    }
  }
  return VisionImage.fromPixels(
    pixels: bytes,
    width: width,
    height: height,
    format: bgra
        ? VisionPixelFormat.bgra
        : channels == 4
        ? VisionPixelFormat.rgba
        : VisionPixelFormat.rgb,
    bytesPerRow: stride,
  );
}

void compare(ConfidenceMask mask, Map<String, dynamic> entry) {
  expect(mask.width, entry['width']);
  expect(mask.height, entry['height']);
  final bytes = Uint8List.fromList(
    gzip.decode(File('$fixtures/${entry['mask']}').readAsBytesSync()),
  );
  expect(sha256.convert(bytes).toString(), entry['sha256']);
  final expected = ByteData.sublistView(bytes);
  expect(mask.confidence.length * 4, bytes.length);
  var maximum = 0.0;
  for (var i = 0; i < mask.confidence.length; i++) {
    final value = mask.confidence[i];
    expect(value.isFinite, isTrue, reason: 'nonfinite pixel $i');
    maximum = math.max(
      maximum,
      (value - expected.getFloat32(i * 4, Endian.little)).abs(),
    );
  }
  expect(
    maximum,
    lessThanOrEqualTo(1e-6),
    reason: '${entry['name']} maximum pixel error',
  );
}

void main() {
  setUpAll(() {
    reference =
        jsonDecode(File('$fixtures/official_reference.json').readAsStringSync())
            as Map<String, dynamic>;
    expect(
      sha256.convert(File(model).readAsBytesSync()).toString(),
      VisionModels.interactiveSegmenter.sha256,
    );
    expect(
      sha256
          .convert(File('$fixtures/cats_and_dogs.jpg').readAsBytesSync())
          .toString(),
      reference['image']['sha256'],
    );
    rgb = File('$fixtures/animals-299x150.rgb').readAsBytesSync();
    expect(sha256.convert(rgb).toString(), reference['raw']['sha256']);
  });

  test(
    'stateful CPU masks match all official Python reference pixels',
    () async {
      final task = await InteractiveSegmenter.create(
        InteractiveSegmenterOptions(modelPath: model),
      );
      addTearDown(task.dispose);
      ConfidenceMask? retained;
      Map<String, dynamic>? retainedCase;
      for (final dynamic value in reference['cases']) {
        final entry = value as Map<String, dynamic>;
        if (entry['set_image'] as bool) {
          await task.setImage(input(entry['input'] as String));
        }
        final result = await task.segment(strokes(entry));
        compare(result, entry);
        retained ??= result;
        retainedCase ??= entry;
      }
      await task.dispose();
      compare(retained!, retainedCase!);
      expect(() => retained!.confidence[0] = 0, throwsUnsupportedError);
    },
    // Loads a 30 MB model and runs twenty segmentations; slow hosted runners
    // have taken over the default 30 seconds.
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'padded RGB, RGBA and BGRA match official masks with model bytes',
    () async {
      final task = await InteractiveSegmenter.create(
        InteractiveSegmenterOptions(modelBytes: File(model).readAsBytesSync()),
      );
      addTearDown(task.dispose);
      final entry =
          (reference['cases'] as List).firstWhere(
                (dynamic c) => c['name'] == 'raw-dog',
              )
              as Map<String, dynamic>;
      for (final kind in ['rgb', 'rgba', 'bgra']) {
        for (final padding in [1, 64]) {
          await task.setImage(
            input(
              kind == 'bgra' ? 'rgba' : kind,
              padding: padding,
              bgra: kind == 'bgra',
            ),
          );
          compare(await task.segment(strokes(entry)), entry);
        }
      }
    },
  );

  test(
    'invalid requests preserve the session and queued calls drain on disposal',
    () async {
      final task = await InteractiveSegmenter.create(
        InteractiveSegmenterOptions(modelPath: model),
      );
      addTearDown(task.dispose);
      final entry = (reference['cases'] as List)[1] as Map<String, dynamic>;
      final history = strokes(entry);
      await expectLater(task.segment(history), throwsA(isA<TaskException>()));
      await task.setImage(input('rgb'));
      await expectLater(task.segment([]), throwsArgumentError);
      await expectLater(
        task.setImage(VisionImage.fromFile('missing-segmenter-image.png')),
        throwsA(isA<TaskException>()),
      );
      compare(await task.segment(history), entry);
      // Snapshot lists when submitted; mutations cannot change queued native work.
      final mutable = List<Stroke>.of(history);
      final pending = task.segment(mutable);
      mutable.clear();
      final reset = task.setImage(input('rgb'));
      final more = [for (var i = 0; i < 3; i++) task.segment(history)];
      final closing = task.dispose();
      expect(identical(closing, task.dispose()), isTrue);
      await expectLater(task.segment(history), throwsStateError);
      await expectLater(task.setImage(input('rgb')), throwsStateError);
      compare(await pending, entry);
      await reset;
      for (final result in await Future.wait(more)) {
        compare(result, entry);
      }
      await closing;
    },
  );

  test(
    'face CPU and GPU runtimes coexist with the official segmenter',
    () async {
      final task = await InteractiveSegmenter.create(
        InteractiveSegmenterOptions(modelPath: model),
      );
      addTearDown(task.dispose);
      final entry = (reference['cases'] as List)[1] as Map<String, dynamic>;
      // GPU only where the face GPU suites run: Linux needs a renderer
      // Google accepts, which a plain hosted runner lacks.
      for (final delegate in [
        Delegate.cpu,
        if (gpuFaceTestsEnabled) Delegate.gpu,
      ]) {
        final detector = await FaceDetector.create(
          FaceDetectorOptions(
            modelPath: 'models/blaze_face_short_range.tflite',
            delegate: delegate,
          ),
        );
        final landmarker = await FaceLandmarker.create(
          FaceLandmarkerOptions(
            modelPath: 'models/face_landmarker.task',
            delegate: delegate,
          ),
        );
        try {
          await task.setImage(input('rgb'));
          final pending = task.segment(strokes(entry));
          final portrait = VisionImage.fromFile(
            'test/fixtures/face_detection/landmark-ex1.jpg',
          );
          expect((await detector.detect(portrait)).detections.length, 1);
          expect(
            (await landmarker.detect(portrait)).faceLandmarks.single.length,
            478,
          );
          compare(await pending, entry);
        } finally {
          await detector.dispose();
          await landmarker.dispose();
        }
      }
    },
  );

  test(
    'unsupported GPU and corrupt models fail without disabling later CPU use',
    () async {
      await expectLater(
        InteractiveSegmenter.create(
          InteractiveSegmenterOptions(modelPath: model, delegate: Delegate.gpu),
        ),
        throwsA(
          isA<RuntimeUnavailableException>().having(
            (e) => e.fix,
            'fix',
            contains('CPU only'),
          ),
        ),
      );
      await expectLater(
        InteractiveSegmenter.create(
          InteractiveSegmenterOptions(
            modelBytes: Uint8List.fromList([1, 2, 3]),
          ),
        ),
        throwsA(isA<TaskException>()),
      );
      final task = await InteractiveSegmenter.create(
        InteractiveSegmenterOptions(modelPath: model),
      );
      addTearDown(task.dispose);
      final entry = (reference['cases'] as List)[1] as Map<String, dynamic>;
      await task.setImage(input('rgb'));
      compare(await task.segment(strokes(entry)), entry);
    },
  );

  test('stroke validation and ownership', () {
    expect(() => InteractiveSegmenterOptions(), throwsArgumentError);
    expect(
      () => InteractiveSegmenterOptions(
        modelPath: model,
        modelBytes: Uint8List(1),
      ),
      throwsArgumentError,
    );
    expect(
      () => Stroke(
        brushMode: BrushMode.positive,
        points: [NormalizedKeypoint(x: double.nan, y: .5)],
      ),
      throwsArgumentError,
    );
    expect(
      () => Stroke(
        brushMode: BrushMode.positive,
        points: [NormalizedKeypoint(x: 1.1, y: .5)],
      ),
      throwsArgumentError,
    );
    expect(
      () => Stroke(brushMode: BrushMode.positive, points: []),
      throwsArgumentError,
    );
    final points = [NormalizedKeypoint(x: .5, y: .5)];
    final stroke = Stroke(brushMode: BrushMode.positive, points: points);
    points.clear();
    expect(stroke.points.length, 1);
    expect(() => stroke.points.clear(), throwsUnsupportedError);
    // Google's API takes a lasso of any length; its graph reads the box
    // around the points.
    expect(
      Stroke(brushMode: BrushMode.lasso, points: stroke.points).points,
      hasLength(1),
    );
  });

  test(
    'Dart ABI matches the official Python ctypes sizes and field offsets',
    () {
      final sizes = {
        'MpBaseOptionsC': sizeOf<mp.MpBaseOptions>(),
        'InteractiveSegmenterOptionsC':
            sizeOf<mp.MpInteractiveSegmenterOptions>(),
        'MpStrokePointC': sizeOf<mp.MpStrokePoint>(),
        'MpStrokeC': sizeOf<mp.MpStroke>(),
        'MpStrokesC': sizeOf<mp.MpStrokes>(),
      };
      for (final entry in sizes.entries) {
        expect(entry.value, reference['abi'][entry.key]['size']);
      }
      using((arena) {
        final base = arena<mp.MpBaseOptions>();
        base.ref
          ..model_asset_buffer = Pointer.fromAddress(11)
          ..model_asset_buffer_count = 12
          ..model_asset_path = Pointer.fromAddress(13)
          ..file_descriptor = 14
          ..delegateAsInt = 15
          ..host_environmentAsInt = 16
          ..host_systemAsInt = 17
          ..host_version = Pointer.fromAddress(18)
          ..ca_bundle_path = Pointer.fromAddress(19)
          ..app_id = Pointer.fromAddress(20)
          ..app_version = Pointer.fromAddress(21);
        final data = ByteData.sublistView(
          base.cast<Uint8>().asTypedList(sizeOf<mp.MpBaseOptions>()),
        );
        final offsets =
            reference['abi']['MpBaseOptionsC']['offsets']
                as Map<String, dynamic>;
        var expected = 11;
        for (final entry in offsets.entries) {
          expect(data.getUint32(entry.value as int, Endian.host), expected++);
        }
        final stroke = arena<mp.MpStroke>();
        stroke.ref
          ..brush_mode = mp.MpBrushMode.MP_BRUSH_MODE_LASSO
          ..points = Pointer.fromAddress(123)
          ..points_count = 9
          ..is_completed = true;
        final bytes = ByteData.sublistView(
          stroke.cast<Uint8>().asTypedList(sizeOf<mp.MpStroke>()),
        );
        final fields = reference['abi']['MpStrokeC']['offsets'];
        expect(bytes.getInt32(fields['brush_mode'] as int, Endian.host), 3);
        expect(bytes.getUint64(fields['points'] as int, Endian.host), 123);
        expect(bytes.getUint32(fields['points_count'] as int, Endian.host), 9);
        expect(bytes.getUint8(fields['is_completed'] as int), 1);
      });
    },
  );
}
