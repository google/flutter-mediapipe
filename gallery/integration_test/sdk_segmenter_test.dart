import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';
import 'package:mediapipe_vision/platform_interface.dart';
import 'package:mediapipe_gallery/main.dart';

import 'support/mask_grids.dart';
import 'support/official_mask_references.dart';
import 'support/sdk_frames.dart';
import 'package:mediapipe_gallery/bundled_model_assets.dart';
import 'support/device_log.dart';

/// As in sdk_hand_landmarker_test.dart: `required` fails when the SDK refuses
/// the GPU, `optional` records a refusal at creation, `skip` runs CPU only.
const _gpu = String.fromEnvironment('SDK_GPU', defaultValue: 'optional');

/// Tasks a device run keeps on CPU.
const _gpuSkipped = String.fromEnvironment('SDK_GPU_SKIP_TASKS');

/// Another runtime build and JPEG decoder than the reference's: the masks
/// still agree except along the subject's outline.
const _categoryAgreement = 0.95;
const _shareError = 0.01;
const _confidenceMean = 0.02;

/// The same input through another path (rotation, pixel format, delegate).
const _turnedAgreement = 0.97;

// Image Segmenter through mediapipe_vision on Google's vision library, on iOS
// and Android.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'official SDK image_segmenter: reference, labels, pixels, rotation, masks',
    (tester) async {
      await tester.runAsync(() async {
        expect(Platform.isAndroid || Platform.isIOS, isTrue);
        expect(
          imageSegmenterBackendFactory,
          isNull,
          reason:
              "Android and iOS run Google's C library through FFI, not a plugin backend",
        );
        final assets = await GalleryAssets.unpack();
        final model = await loadBundledModel('deeplab_v3.tflite');
        final frame = await loadSample('portrait.jpg');
        final references = <Delegate, ImageSegmenterResult>{};
        var shiftedClasses = false;
        // On Android the package declares the GPU unsupported (UP-061,
        // UP-023) and refuses to create it; iPhones offer it, the simulator
        // does not. A phone that must run the GPU may lose it only to that
        // documented gap.
        final capabilities = await queryImageSegmenterCapabilities();
        final gpuDeclared = capabilities.supportedDelegates.contains(
          Delegate.gpu,
        );
        if (Platform.isAndroid) expect(gpuDeclared, isFalse);
        if (!gpuDeclared && _gpu == 'required') {
          expect(
            capabilities.unavailableReasons[Delegate.gpu],
            contains('UP-061'),
          );
          // Asked for anyway, the package refuses it before Google's task
          // exists, so the app lives on to run the CPU checks below.
          await expectLater(
            ImageSegmenter.create(
              ImageSegmenterOptions(
                modelBytes: model,
                delegate: Delegate.gpu,
                outputCategoryMask: true,
              ),
            ),
            throwsA(
              isA<RuntimeUnavailableException>().having(
                (error) => error.fix,
                'fix',
                contains('UP-061'),
              ),
            ),
          );
          _report('gpu_withdrawn', {'gpu': capabilities.platform.gpu});
        }
        for (final delegate in [
          Delegate.cpu,
          if (_gpu != 'skip' &&
              gpuDeclared &&
              !_gpuSkipped.split(',').contains('image_segmenter'))
            Delegate.gpu,
        ]) {
          final ImageSegmenter task;
          try {
            task = await ImageSegmenter.create(
              ImageSegmenterOptions(
                modelBytes: model,
                delegate: delegate,
                outputCategoryMask: true,
              ),
            );
          } on TaskException catch (error) {
            if (delegate == Delegate.cpu || _gpu == 'required') rethrow;
            _report('gpu_unavailable', {'error': error.message});
            continue;
          }
          try {
            final file = await task.segment(
              VisionImage.fromFile(assets.path('portrait.jpg')),
            );
            _expectShape(
              file,
              officialSegmenterReference.width,
              officialSegmenterReference.height,
            );
            // Google's GPU inference scores DeepLab's classes differently from
            // its CPU inference, so each delegate is held to the wheel's output
            // from the same delegate.
            final expected = delegate == Delegate.gpu
                ? officialGpuSegmenterReference
                : officialSegmenterReference;
            final match = compareMasks(file, expected);
            // Logged before the checks so a mismatch on a device still shows
            // what the mask held: the class shares and each class's cells.
            _report('file_match', {
              'delegate': delegate.name,
              ..._summary(match),
              'shares': {
                for (final MapEntry(:key, :value) in categoryShares(
                  file.categoryMask!,
                ).entries)
                  '$key': value,
              },
            });
            if (delegate == Delegate.gpu &&
                match.categoryAgreement <= _categoryAgreement &&
                _matchesShiftedUp(file, expected, match)) {
              // UP-024: the category mask is Google's, one class low; the
              // shifted mask and the confidence masks match its reference.
              shiftedClasses = true;
              _report('upstream', {'issue': 'UP-024'});
            } else {
              _expectMatch(match);
            }

            final reference = await task.segment(frame.image);
            references[delegate] = reference;
            _expectShape(reference, frame.width, frame.height);
            for (final format in VisionPixelFormat.values) {
              final padded = await task.segment(paddedImage(frame, format));
              expect(
                turnedCategoryAgreement(
                  reference.categoryMask!,
                  padded.categoryMask!,
                  0,
                ),
                greaterThan(0.999),
                reason: format.name,
              );
            }
            final turns = <String, double>{};
            for (final turn in [90, 180, 270]) {
              final input = (360 - turn) % 360;
              final result = await task.segment(
                rotatedImage(frame, input),
                rotationDegrees: turn,
              );
              // Masks have the input's dimensions but hold the upright mask
              // resized to them, as Google's own runtimes return (UP-017).
              final (width, height) = turn % 180 == 0
                  ? (frame.width, frame.height)
                  : (frame.height, frame.width);
              _expectShape(result, width, height);
              final agreement = stretchedCategoryAgreement(
                reference.categoryMask!,
                result.categoryMask!,
              );
              expect(agreement, greaterThan(_turnedAgreement), reason: '$turn');
              expect(
                stretchedConfidenceError(
                  reference.confidenceMasks![15],
                  result.confidenceMasks![15],
                ),
                lessThan(0.05),
                reason: '$turn',
              );
              turns['$turn'] = agreement;
            }
            _report('image', {
              'delegate': delegate.name,
              ..._summary(match),
              'rotated_agreement': turns,
            });
          } finally {
            await task.dispose();
          }
          await task.dispose();
          await expectLater(task.segment(frame.image), throwsStateError);
        }
        if (references.length == 2) {
          final gpuClasses = references[Delegate.gpu]!.categoryMask!;
          final agreement = turnedCategoryAgreement(
            references[Delegate.cpu]!.categoryMask!,
            shiftedClasses ? _shiftedUp(gpuClasses) : gpuClasses,
            0,
          );
          expect(agreement, greaterThan(_turnedAgreement));
          _report('cpu_gpu', {'category_agreement': agreement});
        }

        // Each mask selection returns exactly what it asked for.
        for (final (confidence, category) in [(true, false), (false, true)]) {
          final task = await ImageSegmenter.create(
            ImageSegmenterOptions(
              modelBytes: model,
              outputConfidenceMasks: confidence,
              outputCategoryMask: category,
            ),
          );
          try {
            final result = await task.segment(frame.image);
            expect(result.confidenceMasks != null, confidence);
            expect(result.categoryMask != null, category);
            expect(result.labels, hasLength(21));
          } finally {
            await task.dispose();
          }
        }
        await expectLater(
          ImageSegmenter.create(
            ImageSegmenterOptions(modelBytes: Uint8List.fromList([1, 2, 3])),
          ),
          throwsA(isA<Exception>()),
        );
      });
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );

  testWidgets(
    'official SDK image_segmenter VIDEO: queued frames and timestamps',
    (tester) async {
      await tester.runAsync(() async {
        final frame = await loadSample('portrait.jpg');
        final task = await ImageSegmenter.create(
          ImageSegmenterOptions(
            modelBytes: await loadBundledModel('deeplab_v3.tflite'),
            runningMode: RunningMode.video,
            outputConfidenceMasks: false,
            outputCategoryMask: true,
          ),
        );
        try {
          await expectLater(task.segment(frame.image), throwsStateError);
          await expectLater(
            task.segmentForVideo(frame.image, timestampMilliseconds: -1),
            throwsArgumentError,
          );
          final queued = await Future.wait([
            task.segmentForVideo(frame.image, timestampMilliseconds: 0),
            task.segmentForVideo(frame.image, timestampMilliseconds: 33),
          ]);
          expect(queued.map((r) => r.timestampMilliseconds), [0, 33]);
          for (var i = 2; i < 8; i++) {
            final result = await task.segmentForVideo(
              frame.image,
              timestampMilliseconds: i * 33,
            );
            expect(
              turnedCategoryAgreement(
                queued.first.categoryMask!,
                result.categoryMask!,
                0,
              ),
              greaterThan(0.999),
            );
          }
          _report('video', {'frames': 8});
        } finally {
          await task.dispose();
        }
      });
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

void _expectShape(ImageSegmenterResult result, int width, int height) {
  expect((result.imageWidth, result.imageHeight), (width, height));
  expect(result.labels, hasLength(21));
  expect(result.labels.first, 'background');
  expect(result.labels[15], 'person');
  if (result.confidenceMasks case final masks?) {
    expect(masks, hasLength(21));
    for (final mask in masks) {
      expect((mask.width, mask.height), (width, height));
    }
  }
  if (result.categoryMask case final mask?) {
    expect((mask.width, mask.height), (width, height));
  }
}

/// Each non-background class moved up one index.
CategoryMask _shiftedUp(CategoryMask mask) => CategoryMask(
  width: mask.width,
  height: mask.height,
  categories: Uint8List.fromList([
    for (final value in mask.categories) value == 0 ? 0 : value + 1,
  ]),
);

/// UP-024: on a Galaxy S24's Adreno GPU, Google's category mask reports each
/// non-background class one index low (person as 14, not 15) while its
/// confidence masks are right. Recognised only when shifting the classes back
/// makes the category grid and class shares match and the confidence masks
/// already match; any other mismatch still fails.
bool _matchesShiftedUp(
  ImageSegmenterResult result,
  OfficialMasks reference,
  MaskMatch match,
) {
  final mask = result.categoryMask;
  if (mask == null || match.confidence.isEmpty) return false;
  final shifted = _shiftedUp(mask);
  return categoryGridAgreement(shifted, reference.category) >
          _categoryAgreement &&
      shareError(categoryShares(shifted), reference.shares) < _shareError &&
      match.confidence.values.every((e) => e.mean < _confidenceMean);
}

void _expectMatch(MaskMatch match) {
  expect(match.categoryAgreement, greaterThan(_categoryAgreement));
  expect(match.shareError, lessThan(_shareError));
  expect(match.confidence.keys, unorderedEquals([0, 15]));
  for (final MapEntry(key: index, value: error) in match.confidence.entries) {
    expect(error.mean, lessThan(_confidenceMean), reason: '$index');
  }
}

Map<String, Object?> _summary(MaskMatch match) => {
  'category_agreement': match.categoryAgreement,
  'share_error': match.shareError,
  for (final MapEntry(key: index, value: error) in match.confidence.entries)
    'confidence_$index': {'mean': error.mean, 'max': error.max},
};

void _report(String event, Map<String, Object?> data) =>
    logRecord('SDK_SEGMENTER', {'event': event, ...data});
