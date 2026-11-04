import 'dart:typed_data';

import 'package:mediapipe_vision/mediapipe_vision.dart';

import 'task_settings.dart';

/// A camera frame's result, with the timestamp the frame was submitted with.
typedef LiveResult<T> = ({int timestamp, T result});

/// The task-specific half of a live demo: how to build it, and how to hand it
/// a frame. Everything else about live capture is identical between tasks and
/// lives in `LiveCameraController`.
abstract interface class LiveTask<T> {
  /// Human-readable name, used in errors.
  String get name;

  /// The values [open] builds the task with; the page edits them and reopens.
  TaskSettingValues get settings;

  /// Creates the task in the requested running mode: live stream for the
  /// camera, image for a still image, video for a video file.
  Future<void> open(
    Delegate delegate,
    Uint8List modelBytes, {
    RunningMode mode = RunningMode.liveStream,
  });

  /// Processes a still image with a task opened in image mode.
  Future<T> detectImage(VisionImage image);

  /// Processes one frame of a video file with a task opened in video mode:
  /// every frame runs, in order, so tracking follows the whole file.
  Future<T> detectFrame(
    VisionImage frame,
    int timestampMilliseconds, {
    required int rotationDegrees,
  });

  /// Hands one camera frame to a task opened in live stream mode and returns
  /// at once. The task runs it, holds it while another frame runs, or drops
  /// it for a newer one, as Google's live stream does.
  ///
  /// [rotationDegrees] is the clockwise rotation that stands the frame upright;
  /// MediaPipe applies it and still reports coordinates in the frame's own
  /// space, which is what `PreviewTransform` expects.
  void submit(
    VisionImage frame,
    int timestampMilliseconds, {
    required int rotationDegrees,
  });

  /// The result of every submitted frame the task ran, in order. Listen once
  /// per [open], before the first frame.
  Stream<LiveResult<T>> get results;

  /// Frames the task dropped since [open].
  int get droppedFrames;

  /// Releases native resources after the frames already submitted run.
  /// Safe to call when never opened.
  Future<void> close();
}

/// A task that learns from the frames it sees, such as a reference that later
/// frames are compared with. The controller warms each task up on a sample
/// before processing camera frames, then calls [forgetFrames] so the camera's
/// first frame finds the task as freshly opened.
abstract interface class StatefulLiveTask {
  void forgetFrames();
}

/// Tasks whose tracking state requires every frame to have the same
/// dimensions. A differently sized sample must not seed their state.
abstract interface class FixedFrameSizeLiveTask {}

/// Optional worker-rendered browser overlay. The regular Flutter painter stays
/// available when the browser cannot transfer a canvas or drawing fails.
abstract interface class BrowserOverlayLiveTask {
  Future<void> attachOverlay(Object canvas);
  void setOverlayOptions({
    required bool connections,
    required bool points,
    required bool mirrored,
    required double scale,
  });
  bool get overlayActive;
}
