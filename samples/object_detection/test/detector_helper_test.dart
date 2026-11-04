import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';
import 'package:object_detection/detector_helper.dart';

// Runs Google's detector on the host, with the model bundle_models wrote.
const _dog = '../../gallery/samples/dog.jpg';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The bundled model is copied to the app support directory, which
  // path_provider has no plugin for in host tests.
  final support = Directory.systemTemp.createTempSync('object_detection');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => support.path,
      );
  tearDownAll(() => support.deleteSync(recursive: true));

  test('image mode finds the dog', () async {
    final helper = ObjectDetectorHelper(
      runningMode: RunningMode.image,
      settings: const DetectorSettings(),
    );
    await helper.setupObjectDetector();
    final bundle = await helper.detectImage(VisionImage.fromFile(_dog));
    await helper.close();
    final names = [
      for (final detection in bundle.result.detections)
        detection.categories.first.categoryName,
    ];
    expect(names, contains('dog'));
    expect(bundle.result.detections.length, lessThanOrEqualTo(3));
  });

  test('live stream mode delivers results by timestamp', () async {
    final helper = ObjectDetectorHelper(
      runningMode: RunningMode.liveStream,
      settings: const DetectorSettings(maxResults: 1),
    );
    final results = helper.liveResults.take(1).toList();
    await helper.setupObjectDetector();
    final timestamp = helper.detectLivestreamFrame(VisionImage.fromFile(_dog));
    final [bundle] = await results;
    await helper.close();
    expect(bundle.result.timestampMilliseconds, timestamp);
    expect(bundle.result.detections, hasLength(1));
  });

  test('video mode takes increasing timestamps', () async {
    final helper = ObjectDetectorHelper(
      runningMode: RunningMode.video,
      settings: const DetectorSettings(),
    );
    await helper.setupObjectDetector();
    for (final timestamp in [0, 33, 66]) {
      final bundle = await helper.detectVideoFrame(
        VisionImage.fromFile(_dog),
        timestampMilliseconds: timestamp,
      );
      expect(bundle.result.timestampMilliseconds, timestamp);
    }
    await helper.close();
  });

  test('a refused GPU falls back to the CPU and says so', () async {
    final errors = <String>[];
    final helper = ObjectDetectorHelper(
      runningMode: RunningMode.image,
      settings: const DetectorSettings(delegate: Delegate.gpu),
      onError: (message, {gpuError = false}) {
        if (gpuError) errors.add(message);
      },
    );
    await helper.setupObjectDetector();
    final bundle = await helper.detectImage(VisionImage.fromFile(_dog));
    await helper.close();
    expect(bundle.result.detections, isNotEmpty);
    // Either the GPU ran, or the helper reported it and moved to the CPU.
    expect(
      helper.settings.delegate,
      errors.isEmpty ? Delegate.gpu : Delegate.cpu,
    );
  });
}
