@Tags(['native-assets'])
library;

import 'dart:io';

import 'package:mediapipe_text/mediapipe_text.dart';
import 'package:test/test.dart';

// Closes one Language Detector, then keeps the process alive so an upload
// Google's library sends after the close can still be recorded. Only the
// usage-log capture workflow runs it (.github/workflows/telemetry-capture.yml):
// it waits 90 s.
void main() {
  test(
    'close a Language Detector, then wait for late uploads',
    () async {
      final task = await LanguageDetector.create(
        LanguageDetectorOptions(modelPath: 'models/language_detector.tflite'),
      );
      await task.detect('Bonjour tout le monde');
      final closing = DateTime.now();
      await task.dispose();
      print(
        'closed in ${DateTime.now().difference(closing).inMilliseconds} ms',
      );
      await Future<void>.delayed(const Duration(seconds: 90));
    },
    timeout: const Timeout(Duration(minutes: 3)),
    skip: Platform.environment.containsKey('MEDIAPIPE_UPLOAD_WAIT')
        ? false
        : 'Run by the usage-log capture workflow only',
  );
}
