// Reads the process's resident memory, which other test files running in
// the same process would inflate; `make test_vision` runs it alone.
@Tags(['isolated'])
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:mediapipe_vision/mediapipe_vision.dart';
import 'package:test/test.dart';

import 'support/face_reference.dart' show macosGpuWithdrawn;

void main() {
  test(
    'macOS GPU video releases the frames MediaPipe keeps, without its model '
    'file (UP-032)',
    () async {
      // The gallery loads both the shared engine and Face Detector's own
      // library. Exercise that combination in this regression as well.
      final classifier = await ImageClassifier.create(
        ImageClassifierOptions(
          modelPath: 'models/mobilenet_v3_small.tflite',
          delegate: Delegate.gpu,
        ),
      );
      await classifier.dispose();

      final rgb = File(
        'test/fixtures/face_detection/portrait-301x209.rgb',
      ).readAsBytesSync();
      final pixels = Uint8List(640 * 480 * 4);
      for (var y = 0; y < 480; y++) {
        for (var x = 0; x < 640; x++) {
          final source = ((y * 209 ~/ 480) * 301 + x * 301 ~/ 640) * 3;
          final target = (y * 640 + x) * 4;
          pixels[target] = rgb[source + 2];
          pixels[target + 1] = rgb[source + 1];
          pixels[target + 2] = rgb[source];
          pixels[target + 3] = 255;
        }
      }

      // MediaPipe has read the model once the task exists, so an app may
      // delete the file. The reopens below must not need it.
      final folder = Directory.systemTemp.createTempSync('face-gpu-model-');
      final model = File(
        'models/blaze_face_short_range.tflite',
      ).copySync('${folder.path}/model.tflite');
      final detector = await FaceDetector.create(
        FaceDetectorOptions(
          modelPath: model.path,
          delegate: Delegate.gpu,
          runningMode: RunningMode.video,
        ),
      );
      model.deleteSync();
      try {
        int? warmedRss;
        var peakGrowth = 0;
        // 2,000 frames are 2.4 GB of input, so the task reopens four times.
        for (var frame = 0; frame < 2000; frame++) {
          final result = await detector.detectForVideo(
            VisionImage.fromPixels(
              pixels: pixels,
              width: 640,
              height: 480,
              format: VisionPixelFormat.bgra,
            ),
            timestampMilliseconds: frame * 33,
          );
          expect(result.detections, hasLength(1));
          expect(result.timestampMilliseconds, frame * 33);
          if (frame == 200) warmedRss = ProcessInfo.currentRss;
          if (frame > 200 && frame % 100 == 0) {
            final growth = ProcessInfo.currentRss - warmedRss!;
            if (growth > peakGrowth) peakGrowth = growth;
            // Each checkpoint is logged, so a failure shows the whole curve.
            print('FACE_GPU_MEMORY frame=$frame growth_bytes=$growth');
          }
        }
        print('FACE_GPU_MEMORY frames=2000 peak_growth_bytes=$peakGrowth');
        // Without the reopen this grows by about 1.2 MB a frame, past 2 GB by
        // the end, and twice that where LiteRT keeps a second copy of each
        // frame (GitHub's virtual Mac). Reopening after 512 MiB of frames
        // holds it under this limit there too; the margin covers allocator
        // and Dart GC variation.
        expect(peakGrowth, lessThan(1280 * 1024 * 1024));
      } finally {
        await detector.dispose();
        folder.deleteSync(recursive: true);
      }
    },
    skip: Platform.isMacOS ? macosGpuWithdrawn : 'macOS only',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
