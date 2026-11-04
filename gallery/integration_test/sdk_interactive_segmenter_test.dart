import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';
import 'package:mediapipe_vision/platform_interface.dart';
import 'package:mediapipe_gallery/main.dart';

import 'support/official_mask_references.dart';
import 'support/sdk_frames.dart';
import 'package:mediapipe_gallery/bundled_model_assets.dart';
import 'support/device_log.dart';
import 'support/mask_grids.dart';

// Google's stateful MagicTouch Interactive Segmenter through Google's C
// library on iOS and Android. The reference is CPU. On Android the suite also
// records what the GPU delegate does, which is not declared: the package
// refuses it before Google's task exists, and earlier, through Google's
// Android SDK, PowerVR refused its stroke shader and Mali's mask agreed with
// CPU on 94% of pixels (tool/coverage/matrix.json). Whatever SDK_GPU says, a
// GPU refusal or disagreement is recorded, never failed; `skip` runs CPU only.
const _gpu = String.fromEnvironment('SDK_GPU', defaultValue: 'optional');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'official SDK interactive_segmenter: reference, strokes, undo, images',
    (tester) async {
      await tester.runAsync(() async {
        expect(Platform.isAndroid || Platform.isIOS, isTrue);
        expect(
          interactiveSegmenterBackendFactory,
          isNull,
          reason:
              "Android and iOS run Google's C library through FFI, not a plugin backend",
        );
        final assets = await GalleryAssets.unpack();
        final bytes = await rootBundle.load(
          bundledModelFile('interactive_segmentation.task'),
        );
        final task = await InteractiveSegmenter.create(
          InteractiveSegmenterOptions(
            modelBytes: bytes.buffer.asUint8List(
              bytes.offsetInBytes,
              bytes.lengthInBytes,
            ),
          ),
        );
        Stroke stroke(BrushMode mode, List<(double, double)> points) => Stroke(
          brushMode: mode,
          points: [for (final (x, y) in points) NormalizedKeypoint(x: x, y: y)],
        );
        final (x, y) = officialInteractiveReference.point;
        final cat = stroke(BrushMode.positive, [(x, y)]);
        final dog = stroke(BrushMode.positive, [(0.66, 0.55)]);
        try {
          await task.setImage(VisionImage.fromFile(assets.path('animals.jpg')));
          final file = await task.segment([cat]);
          expect(
            (file.width, file.height),
            (
              officialInteractiveReference.width,
              officialInteractiveReference.height,
            ),
          );
          final gridError = confidenceGridError(
            file,
            officialInteractiveReference.grid,
          ).mean;
          final meanDelta = (_mean(file) - officialInteractiveReference.mean)
              .abs();
          final foregroundDelta =
              (_foreground(file) - officialInteractiveReference.foreground)
                  .abs();
          expect(gridError, lessThan(0.02));
          expect(meanDelta, lessThan(0.01));
          expect(foregroundDelta, lessThan(0.01));

          // Exclude and Lasso on the same photo, against Google's summaries
          // of the same histories, with Include's tolerances.
          final summaries = <String, ConfidenceMask>{};
          for (final MapEntry(key: name, value: summary)
              in officialInteractiveSummaries.entries) {
            final mask = await task.segment([
              for (final (mode, points) in summary.strokes)
                stroke(BrushMode.values.byName(mode), points),
            ]);
            summaries[name] = mask;
            final error = confidenceGridError(mask, summary.grid).mean;
            final mean = (_mean(mask) - summary.mean).abs();
            final share = (_foreground(mask) - summary.foreground).abs();
            _report(name, {
              'grid_error': error,
              'mean_delta': mean,
              'foreground_delta': share,
            });
            expect(error, lessThan(0.02), reason: name);
            expect(mean, lessThan(0.01), reason: name);
            expect(share, lessThan(0.01), reason: name);
          }
          // Google reads a lasso as the box around its points: the outline
          // and its two opposite corners select the same pixels.
          expect(
            _agreement(
              summaries['file-lasso']!,
              summaries['file-lasso-corners']!,
            ),
            greaterThan(0.999),
          );

          // The same image as decoded pixels: the same selection.
          final frame = await loadSample('animals.jpg');
          await task.setImage(frame.image);
          final pixels = await task.segment([cat]);
          final agreement = _agreement(file, pixels);
          expect(agreement, greaterThan(0.99));

          // Strokes add, as in Google's references.
          final dogOnly = await task.segment([dog]);
          final both = await task.segment([dog, cat]);
          expect(_foreground(both), greaterThan(_foreground(dogOnly)));
          // Undo is a shorter history: the earlier mask again.
          final undone = await task.segment([dog]);
          expect(_agreement(dogOnly, undone), greaterThan(0.999));
          expect(() => task.segment(const []), throwsArgumentError);
          _report('image', {
            'grid_error': gridError,
            'mean_delta': meanDelta,
            'foreground_delta': foregroundDelta,
            'file_pixels_agreement': agreement,
            'foreground': {
              'dog': _foreground(dogOnly),
              'dog_cat': _foreground(both),
            },
          });
        } finally {
          await task.dispose();
        }
        await expectLater(() => task.setImage(blankImage()), throwsStateError);
      });
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );

  testWidgets(
    'official SDK interactive_segmenter GPU: recorded against CPU',
    (tester) async {
      await tester.runAsync(() async {
        final assets = await GalleryAssets.unpack();
        final bytes = await rootBundle.load(
          bundledModelFile('interactive_segmentation.task'),
        );
        final model = bytes.buffer.asUint8List(
          bytes.offsetInBytes,
          bytes.lengthInBytes,
        );
        final (x, y) = officialInteractiveReference.point;
        final history = [
          Stroke(
            brushMode: BrushMode.positive,
            points: [NormalizedKeypoint(x: x, y: y)],
          ),
        ];
        final masks = <Delegate, ConfidenceMask>{};
        for (final delegate in Delegate.values) {
          // PowerVR accepts the GPU task, then refuses its first segment.
          try {
            final task = await InteractiveSegmenter.create(
              InteractiveSegmenterOptions(
                modelBytes: model,
                delegate: delegate,
              ),
            );
            try {
              await task.setImage(
                VisionImage.fromFile(assets.path('animals.jpg')),
              );
              masks[delegate] = await task.segment(history);
            } finally {
              await task.dispose();
            }
          } on MediaPipeException catch (error) {
            // The package's own refusal (RuntimeUnavailableException) or
            // Google's (TaskException).
            if (delegate == Delegate.cpu) rethrow;
            _report('gpu_unavailable', {
              'type': '${error.runtimeType}',
              'error': error.message,
            });
            return;
          }
        }
        final cpu = masks[Delegate.cpu]!, gpu = masks[Delegate.gpu]!;
        _report('cpu_gpu', {
          'agreement': _agreement(cpu, gpu),
          'gpu_grid_error': confidenceGridError(
            gpu,
            officialInteractiveReference.grid,
          ).mean,
        });
      });
    },
    skip: !Platform.isAndroid || _gpu == 'skip',
    timeout: const Timeout(Duration(minutes: 4)),
  );
}

double _mean(ConfidenceMask mask) =>
    mask.confidence.fold(0.0, (sum, v) => sum + v) / mask.confidence.length;

/// The share of pixels above 0.5.
double _foreground(ConfidenceMask mask) =>
    mask.confidence.where((v) => v > 0.5).length / mask.confidence.length;

/// The share of pixels on the same side of 0.5 in two same-sized masks.
double _agreement(ConfidenceMask a, ConfidenceMask b) {
  expect((a.width, a.height), (b.width, b.height));
  var same = 0;
  for (var i = 0; i < a.confidence.length; i++) {
    if ((a.confidence[i] > 0.5) == (b.confidence[i] > 0.5)) same++;
  }
  return same / a.confidence.length;
}

void _report(String event, Map<String, Object?> data) =>
    logRecord('SDK_INTERACTIVE', {'event': event, ...data});
