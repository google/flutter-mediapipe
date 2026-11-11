import 'dart:async';
import 'dart:js_interop';

import 'package:mediapipe_vision/mediapipe_vision.dart';
import 'package:web/web.dart' as web;

/// Draws the faces in [video] into [canvas], from the task's worker, until
/// [stop] completes.
Future<void> drawFacesLive(
  web.HTMLVideoElement video,
  web.HTMLCanvasElement canvas, {
  required Future<void> stop,
}) async {
  final task = await FaceLandmarker.create(
    FaceLandmarkerOptions(
      model: VisionModels.faceLandmarker,
      runningMode: RunningMode.liveStream,
    ),
  );
  final BrowserOverlay overlay;
  try {
    // The canvas belongs to the worker from now on.
    overlay = await BrowserOverlay.attach(task, canvas);
  } catch (_) {
    await task.dispose();
    rethrow;
  }
  overlay.configure(connections: true, points: false);
  // Listen before the first frame, as Google requires a result listener.
  final results = task.results.listen((result) {
    final faces = result.faceLandmarks.length;
    final drawn = overlay.active ? 'drawn' : 'not drawn';
    print('${result.timestampMilliseconds}: $faces faces, $drawn');
  });
  var stopped = false;
  unawaited(stop.then((_) => stopped = true));
  var last = -1;
  try {
    while (!stopped) {
      final bitmap = await web.window.createImageBitmap(video).toDart;
      final now = web.window.performance.now().floor();
      last = now > last ? now : last + 1;
      // The task closes the bitmap once it has run or dropped the frame.
      task.detectAsync(
        VisionImage.fromBrowserFrame(
          bitmap,
          width: bitmap.width,
          height: bitmap.height,
        ),
        timestampMilliseconds: last,
      );
      final painted = Completer<void>();
      web.window.requestAnimationFrame(((num _) => painted.complete()).toJS);
      await painted.future;
    }
  } finally {
    // Runs the frame in flight and the waiting one, still drawn, then
    // closes results and ends the drawing.
    await task.dispose();
    await results.cancel();
  }
}
