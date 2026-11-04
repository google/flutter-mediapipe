@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';
import 'package:mediapipe_vision/platform_interface.dart';
import 'package:web/web.dart' as web;

/// Google's browser runtime as the test drives it: frames finish when the
/// test says so, and the bitmaps it receives stay open, since releasing the
/// frames it runs is the backend's job.
final class _Backend implements VisionTaskBackend<FaceDetectorResult> {
  final received = <web.ImageBitmap>[];
  final pending = <Completer<FaceDetectorResult>>[];

  @override
  Future<FaceDetectorResult> detect(
    VisionImage image,
    int rotationDegrees,
    int? timestampMilliseconds, {
    VisionRegionOfInterest? regionOfInterest,
  }) {
    received.add(image.browserFrame! as web.ImageBitmap);
    final done = Completer<FaceDetectorResult>();
    pending.add(done);
    return done.future;
  }

  @override
  Future<void> dispose() async {}
}

FaceDetectorResult _result(int timestamp) => FaceDetectorResult(
  imageWidth: 4,
  imageHeight: 4,
  detections: const [],
  timestampMilliseconds: timestamp,
);

/// A closed bitmap reports a size of zero.
bool _closed(web.ImageBitmap bitmap) => bitmap.width == 0;

void main() {
  test('the package closes the bitmap of every frame it drops', () async {
    final backend = _Backend();
    faceDetectorBackendFactory = (_) async => backend;
    addTearDown(() => faceDetectorBackendFactory = null);
    final task = await FaceDetector.create(
      FaceDetectorOptions(
        modelBytes: Uint8List.fromList([1]),
        runningMode: RunningMode.liveStream,
      ),
    );
    final results = <int?>[];
    task.results.listen((r) => results.add(r.timestampMilliseconds));
    final bitmaps = [
      for (var i = 0; i < 4; i++)
        await web.window.createImageBitmap(web.ImageData(4.toJS, 4)).toDart,
    ];
    for (var i = 0; i < 4; i++) {
      task.detectAsync(
        VisionImage.fromBrowserFrame(bitmaps[i], width: 4, height: 4),
        timestampMilliseconds: i,
      );
    }
    await pumpEventQueue();
    expect(task.droppedFrames, 2);
    expect(bitmaps.map(_closed), [false, true, true, false]);
    backend.pending[0].complete(_result(0));
    await pumpEventQueue();
    expect(backend.received, [bitmaps[0], bitmaps[3]]);
    backend.pending[1].complete(_result(3));
    await task.dispose();
    expect(results, [0, 3]);
    for (final bitmap in bitmaps) {
      bitmap.close();
    }
  });
}
