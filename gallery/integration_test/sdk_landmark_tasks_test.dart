import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';
import 'package:mediapipe_vision/platform_interface.dart';
import 'package:mediapipe_gallery/main.dart';

import 'support/mask_grids.dart';
import 'support/official_landmark_references.dart';
import 'support/official_mask_references.dart';
import 'support/sdk_frames.dart';
import 'package:mediapipe_gallery/bundled_model_assets.dart';
import 'support/device_log.dart';

/// As in sdk_hand_landmarker_test.dart: `required` fails when the SDK refuses
/// the GPU, `optional` records a refusal at creation, `skip` runs CPU only.
/// The iOS simulator and the Android emulator need `skip`.
const _gpu = String.fromEnvironment('SDK_GPU', defaultValue: 'optional');

/// Comma-separated subset of `pose,gesture,holistic`; empty runs all three.
const _only = String.fromEnvironment('SDK_TASKS');

/// Another runtime build and image decoder than the reference's, so the bound
/// is the cross-runtime one the Android face test uses for CPU against GPU.
const _crossRuntime = 0.03;

// Pose Landmarker, Gesture Recognizer and Holistic Landmarker through
// mediapipe_vision on Google's vision library, on iOS and Android.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  for (final subject in _subjects) {
    if (_only.isNotEmpty && !_only.split(',').contains(subject.name)) continue;

    testWidgets(
      'official SDK ${subject.name}: reference, pixels, rotation, CPU and GPU',
      (tester) async {
        await tester.runAsync(() async {
          expect(Platform.isAndroid || Platform.isIOS, isTrue);
          expect(
            subject.registered(),
            isFalse,
            reason:
                "Android and iOS run Google's C library through FFI, not a plugin backend",
          );
          final assets = await GalleryAssets.unpack();
          final model = await loadBundledModel(subject.model);
          final frame = await loadSample(subject.sample);
          final references = <Delegate, _Parts>{};
          // The package withdraws Holistic's GPU where Google's runtime cannot
          // open its face blendshapes model (UP-026, iPhones included) and
          // refuses it before Google's graph exists. A phone that must run the
          // GPU may lose it only to that documented gap.
          final capabilities = await subject.capabilities();
          final gpuDeclared = capabilities.supportedDelegates.contains(
            Delegate.gpu,
          );
          if (!gpuDeclared && _gpu == 'required') {
            expect(
              capabilities.unavailableReasons[Delegate.gpu],
              contains('UP-026'),
            );
            await expectLater(
              subject.open(model, Delegate.gpu, RunningMode.image),
              throwsA(isA<RuntimeUnavailableException>()),
            );
            _report(subject, 'gpu_withdrawn', {
              'reason': capabilities.unavailableReasons[Delegate.gpu],
            });
          }
          for (final delegate in [
            Delegate.cpu,
            if (_gpu != 'skip' && gpuDeclared) Delegate.gpu,
          ]) {
            final _Task task;
            try {
              task = await subject.open(model, delegate, RunningMode.image);
            } on TaskException catch (error) {
              if (delegate == Delegate.cpu || _gpu == 'required') {
                rethrow;
              }
              _report(subject, 'gpu_unavailable', {'error': error.message});
              continue;
            }
            try {
              final file = await task.image(
                VisionImage.fromFile(assets.path(subject.sample)),
              );
              subject.check(file);
              final official = _officialDelta(subject, file.parts);
              expect(official, lessThan(_crossRuntime));
              // Holistic carries state between IMAGE calls, in Google's own
              // Python API too, so only a fresh task's first result repeats.
              Future<_Result> first(
                VisionImage image, {
                int rotation = 0,
              }) async {
                if (!subject.statefulImages) {
                  return task.image(image, rotation: rotation);
                }
                final fresh = await subject.open(
                  model,
                  delegate,
                  RunningMode.image,
                );
                try {
                  return await fresh.image(image, rotation: rotation);
                } finally {
                  await fresh.dispose();
                }
              }

              // Google's reference turned the upright pixels a quarter turn
              // counterclockwise, then asked for rotation_degrees 90, and
              // reports points in the turned pixels' frame.
              final turned = await first(
                rotatedImage(frame, 270),
                rotation: 90,
              );
              subject.check(turned);
              final officialTurned = _officialDelta(
                subject,
                turned.parts,
                key: '${subject.name}@90',
              );
              // The reference is Google's CPU result. Google's Pose GPU turns
              // rotated input differently from its CPU (0.16 apart in the
              // macOS wheel itself), so there the value is only recorded.
              if (delegate == Delegate.cpu || subject.gpuRotationMatchesCpu) {
                expect(officialTurned, lessThan(_crossRuntime));
              }

              final reference = await first(frame.image);
              subject.check(reference);
              references[delegate] = reference.parts;
              for (final format in VisionPixelFormat.values) {
                final padded = await first(paddedImage(frame, format));
                expect(
                  _delta(reference.parts, padded.parts),
                  lessThan(1e-5),
                  reason: format.name,
                );
              }
              for (final turn in [90, 180, 270]) {
                final rotated = rotatedImage(frame, (360 - turn) % 360);
                final result = await first(rotated, rotation: turn);
                subject.check(result);
                expect(
                  result.width,
                  turn % 180 == 0 ? frame.width : frame.height,
                );
              }
              final blank = await task.image(blankImage());
              expect(blank.parts.values.every((p) => p.isEmpty), isTrue);
              _report(subject, 'image', {
                'delegate': delegate.name,
                'official_max_delta': official,
                'official_rotated_max_delta': officialTurned,
                ...file.extra,
              });
            } finally {
              await task.dispose();
            }
            await task.dispose();
            await expectLater(task.image(frame.image), throwsStateError);
          }
          if (references.length == 2) {
            final delta = _delta(
              references[Delegate.cpu]!,
              references[Delegate.gpu]!,
            );
            // Recorded, not asserted: each delegate already matched Google's
            // reference above. On a Galaxy S24's Adreno GPU, Pose was 0.003
            // (CPU) and 0.006 (GPU) from it, yet 0.038 apart on these pixels.
            _report(subject, 'cpu_gpu', {'max_landmark_delta': delta});
          }
          await expectLater(
            subject.open(
              Uint8List.fromList([1, 2, 3]),
              Delegate.cpu,
              RunningMode.image,
            ),
            throwsA(isA<TaskException>()),
          );
          if (subject.maskOf case final maskOf?) {
            await _checkMasks(subject, maskOf, model, frame, assets);
          }
        });
      },
      timeout: const Timeout(Duration(minutes: 4)),
    );

    testWidgets(
      'official SDK ${subject.name} VIDEO: tracking, blank, queued frames',
      (tester) async {
        await tester.runAsync(() async {
          final frame = await loadSample(subject.sample);
          final task = await subject.open(
            await loadBundledModel(subject.model),
            Delegate.cpu,
            RunningMode.video,
          );
          try {
            await expectLater(task.image(frame.image), throwsStateError);
            await expectLater(task.video(frame.image, -1), throwsArgumentError);
            final queued = await Future.wait([
              task.video(frame.image, 0),
              task.video(frame.image, 33),
            ]);
            expect(queued.map((r) => r.timestamp), [0, 33]);
            queued.forEach(subject.check);
            await expectLater(task.video(frame.image, 33), throwsArgumentError);
            for (var i = 2; i < 12; i++) {
              final result = await task.video(frame.image, i * 33);
              subject.check(result);
              expect(result.timestamp, i * 33);
            }
            final empty = await task.video(blankImage(), 400);
            expect(empty.parts.values.every((p) => p.isEmpty), isTrue);
            subject.check(await task.video(frame.image, 433));
            _report(subject, 'video', {'frames': 13, 'blank_frames': 1});
          } finally {
            await task.dispose();
          }
        });
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  }
}

/// Image landmarks per named part: one subject's points, or empty.
typedef _Parts = Map<String, List<NormalizedLandmark>>;

typedef _Result = ({
  _Parts parts,
  int width,
  int? timestamp,
  Map<String, Object?> extra,
});

/// One open task behind a uniform face, whatever its own method names.
final class _Task {
  _Task(this.image, this.video, this.dispose);
  final Future<_Result> Function(VisionImage image, {int rotation}) image;
  final Future<_Result> Function(VisionImage image, int timestamp) video;
  final Future<void> Function() dispose;
}

final class _Subject {
  const _Subject({
    required this.name,
    required this.model,
    required this.sample,
    required this.registered,
    required this.capabilities,
    required this.open,
    required this.check,
    this.maskOf,
    this.statefulImages = false,
    this.gpuRotationMatchesCpu = true,
  });

  /// `pose`, `gesture` or `holistic`, as in the references and SDK_TASKS.
  final String name;
  final String model;
  final String sample;
  final bool Function() registered;

  /// The package's capability query, which withdraws a GPU Google's runtime
  /// cannot open on this platform.
  final Future<TaskCapabilities> Function() capabilities;
  final Future<_Task> Function(
    Uint8List model,
    Delegate delegate,
    RunningMode mode,
  )
  open;

  /// The sample's expected subject: every part present with finite points.
  final void Function(_Result result) check;

  /// A fresh CPU task's pose segmentation mask and pose landmarks for one
  /// image, or null for a task without masks. Holistic smooths masks across
  /// IMAGE calls and fails on a size change (upstream-issues.md), so every
  /// image gets its own task.
  final Future<({ConfidenceMask mask, List<NormalizedLandmark> pose})> Function(
    Uint8List model,
    VisionImage image,
    int rotation,
  )?
  maskOf;

  /// Whether an IMAGE task's result depends on the calls before it.
  final bool statefulImages;

  /// Whether Google's GPU path turns rotated input as its CPU path does.
  final bool gpuRotationMatchesCpu;
}

_Result _result(
  _Parts parts,
  int width,
  int? timestamp, [
  Map<String, Object?> extra = const {},
]) => (parts: parts, width: width, timestamp: timestamp, extra: extra);

List<NormalizedLandmark> _single(List<List<NormalizedLandmark>> subjects) =>
    subjects.isEmpty ? const [] : subjects.single;

void Function(_Result) _expectParts(Map<String, int> points) => (result) {
  expect(result.parts.keys.toSet(), points.keys.toSet());
  for (final MapEntry(key: part, value: count) in points.entries) {
    expect(result.parts[part], hasLength(count), reason: part);
    for (final point in result.parts[part]!) {
      expect(point.x.isFinite && point.y.isFinite && point.z.isFinite, isTrue);
    }
  }
};

final _subjects = <_Subject>[
  _Subject(
    name: 'pose',
    model: 'pose_landmarker_lite.task',
    sample: 'pose.jpg',
    registered: () => poseLandmarkerBackendFactory != null,
    capabilities: queryPoseLandmarkerCapabilities,
    open: (model, delegate, mode) async {
      final task = await PoseLandmarker.create(
        PoseLandmarkerOptions(
          modelBytes: model,
          delegate: delegate,
          runningMode: mode,
        ),
      );
      _Result map(PoseLandmarkerResult r) {
        expect(r.poseWorldLandmarks, hasLength(r.poseLandmarks.length));
        return _result(
          {'pose': _single(r.poseLandmarks)},
          r.imageWidth,
          r.timestampMilliseconds,
        );
      }

      return _Task(
        (image, {rotation = 0}) async =>
            map(await task.detect(image, rotationDegrees: rotation)),
        (image, timestamp) async => map(
          await task.detectForVideo(image, timestampMilliseconds: timestamp),
        ),
        task.dispose,
      );
    },
    check: _expectParts(const {'pose': 33}),
    gpuRotationMatchesCpu: false,
    maskOf: (model, image, rotation) async {
      final task = await PoseLandmarker.create(
        PoseLandmarkerOptions(modelBytes: model, outputSegmentationMasks: true),
      );
      try {
        final r = await task.detect(image, rotationDegrees: rotation);
        return (
          mask: r.segmentationMasks!.single,
          pose: r.poseLandmarks.single,
        );
      } finally {
        await task.dispose();
      }
    },
  ),
  _Subject(
    name: 'gesture',
    model: 'gesture_recognizer.task',
    sample: 'thumb_up.jpg',
    registered: () => gestureRecognizerBackendFactory != null,
    capabilities: queryGestureRecognizerCapabilities,
    open: (model, delegate, mode) async {
      final task = await GestureRecognizer.create(
        GestureRecognizerOptions(
          modelBytes: model,
          delegate: delegate,
          runningMode: mode,
          numHands: 2,
        ),
      );
      _Result map(GestureRecognizerResult r) {
        final hand = _single(r.handLandmarks);
        if (hand.isNotEmpty) {
          expect(r.handWorldLandmarks.single, hasLength(21));
          expect(r.handedness.single, isNotEmpty);
          // Canned and custom indices are merged, so the index is always -1.
          expect(r.gestures.single.every((g) => g.index == -1), isTrue);
        }
        return _result(
          {'hand': hand},
          r.imageWidth,
          r.timestampMilliseconds,
          {
            if (r.gestures.isNotEmpty)
              'gesture': r.gestures.single.first.categoryName,
          },
        );
      }

      return _Task(
        (image, {rotation = 0}) async =>
            map(await task.recognize(image, rotationDegrees: rotation)),
        (image, timestamp) async => map(
          await task.recognizeForVideo(image, timestampMilliseconds: timestamp),
        ),
        task.dispose,
      );
    },
    check: (result) {
      _expectParts(const {'hand': 21})(result);
      expect(result.extra['gesture'], 'Thumb_Up');
    },
  ),
  _Subject(
    name: 'holistic',
    model: 'holistic_landmarker.task',
    sample: 'pose.jpg',
    registered: () => holisticLandmarkerBackendFactory != null,
    capabilities: queryHolisticLandmarkerCapabilities,
    open: (model, delegate, mode) async {
      final task = await HolisticLandmarker.create(
        HolisticLandmarkerOptions(
          modelBytes: model,
          delegate: delegate,
          runningMode: mode,
        ),
      );
      _Result map(HolisticLandmarkerResult r) {
        expect(r.poseWorldLandmarks, hasLength(r.poseLandmarks.length));
        expect(r.leftHandWorldLandmarks, hasLength(r.leftHandLandmarks.length));
        expect(
          r.rightHandWorldLandmarks,
          hasLength(r.rightHandLandmarks.length),
        );
        return _result(
          {
            'pose': r.poseLandmarks,
            'left_hand': r.leftHandLandmarks,
            'right_hand': r.rightHandLandmarks,
          },
          r.imageWidth,
          r.timestampMilliseconds,
          {'face_points': r.faceLandmarks.length},
        );
      }

      return _Task(
        (image, {rotation = 0}) async =>
            map(await task.detect(image, rotationDegrees: rotation)),
        (image, timestamp) async => map(
          await task.detectForVideo(image, timestampMilliseconds: timestamp),
        ),
        task.dispose,
      );
    },
    check: _expectParts(const {'pose': 33, 'left_hand': 21, 'right_hand': 21}),
    statefulImages: true,
    maskOf: (model, image, rotation) async {
      final task = await HolisticLandmarker.create(
        HolisticLandmarkerOptions(
          modelBytes: model,
          outputPoseSegmentationMask: true,
        ),
      );
      try {
        final r = await task.detect(image, rotationDegrees: rotation);
        return (mask: r.poseSegmentationMask!, pose: r.poseLandmarks);
      } finally {
        await task.dispose();
      }
    },
  ),
];

/// The pose segmentation mask on CPU: Google's mean, the body under the
/// shoulder and hip landmarks, and a rotated input's mask turned back into
/// its frame, as Google does for pose masks (unlike Image Segmenter, UP-017).
Future<void> _checkMasks(
  _Subject subject,
  Future<({ConfidenceMask mask, List<NormalizedLandmark> pose})> Function(
    Uint8List,
    VisionImage,
    int,
  )
  maskOf,
  Uint8List model,
  SampleFrame frame,
  GalleryAssets assets,
) async {
  final file = await maskOf(
    model,
    VisionImage.fromFile(assets.path(subject.sample)),
    0,
  );
  expect((file.mask.width, file.mask.height), (frame.width, frame.height));
  final meanDelta = (_mean(file.mask) - officialPoseMaskMeans[subject.name]!)
      .abs();
  expect(meanDelta, lessThan(0.01));
  final upright = await maskOf(model, frame.image, 0);
  final body = <String, double>{};
  // Shoulders and hips.
  for (final index in [11, 12, 23, 24]) {
    final point = upright.pose[index];
    final x = (point.x * upright.mask.width).floor();
    final y = (point.y * upright.mask.height).floor();
    body['$index'] = upright.mask.confidence[y * upright.mask.width + x];
    expect(body['$index'], greaterThan(0.5), reason: 'landmark $index');
  }
  // As officialLandmarkReferences' rotated case: the upright pixels turned a
  // quarter turn counterclockwise, then rotation_degrees 90. That mask is 667
  // wide, so its rows are padded, which Google's Java Android SDK failed to
  // convert (upstream-issues.md UP-018); its C library does not.
  final turned = await maskOf(model, rotatedImage(frame, 270), 90);
  expect((turned.mask.width, turned.mask.height), (frame.height, frame.width));
  final turnedError = turnedConfidenceError(upright.mask, turned.mask, 270);
  expect(turnedError, lessThan(0.02));
  final turnedMeanDelta =
      (_mean(turned.mask) - officialPoseMaskMeans['${subject.name}@90']!).abs();
  expect(turnedMeanDelta, lessThan(0.01));
  _report(subject, 'mask', {
    'official_mean_delta': meanDelta,
    'official_rotated_mean_delta': turnedMeanDelta,
    'rotated_error': turnedError,
    'body': body,
  });
}

double _mean(ConfidenceMask mask) =>
    mask.confidence.fold(0.0, (sum, v) => sum + v) / mask.confidence.length;

/// Largest x or y difference from Google's reference over every part.
double _officialDelta(_Subject subject, _Parts parts, {String? key}) {
  var maximum = 0.0;
  for (final MapEntry(key: part, value: expected)
      in officialLandmarkReferences[key ?? subject.name]!.entries) {
    final actual = parts[part]!;
    expect(actual, hasLength(expected.length), reason: part);
    for (final (i, (x, y)) in expected.indexed) {
      maximum = math.max(
        maximum,
        math.max((actual[i].x - x).abs(), (actual[i].y - y).abs()),
      );
    }
  }
  return maximum;
}

double _delta(_Parts a, _Parts b) {
  var maximum = 0.0;
  for (final part in a.keys) {
    expect(b[part], hasLength(a[part]!.length), reason: part);
    for (final (i, p) in a[part]!.indexed) {
      final q = b[part]![i];
      maximum = math.max(
        maximum,
        math.max(
          (p.x - q.x).abs(),
          math.max((p.y - q.y).abs(), (p.z - q.z).abs()),
        ),
      );
    }
  }
  return maximum;
}

void _report(_Subject subject, String event, Map<String, Object?> data) =>
    logRecord('SDK_LANDMARK_TASK', {
      'task': subject.name,
      'event': event,
      ...data,
    });
