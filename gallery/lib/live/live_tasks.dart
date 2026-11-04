import 'dart:typed_data';

import 'package:mediapipe_vision/mediapipe_vision.dart';

import 'live_task.dart';
import 'task_settings.dart';

/// The half of every live demo that does not depend on the task, on every
/// platform: each demo supplies only its name, its settings and how its task
/// is built.
abstract base class _VisionLiveTask<R> implements LiveTask<R> {
  VisionTask? _task;

  /// Creates a task in the requested running mode.
  Future<VisionTask> create(
    Delegate delegate,
    Uint8List model,
    RunningMode mode,
  );

  @override
  Future<void> open(
    Delegate delegate,
    Uint8List modelBytes, {
    RunningMode mode = RunningMode.liveStream,
  }) async {
    _task = await create(delegate, modelBytes, mode);
  }

  @override
  Future<R> detectImage(VisionImage image) =>
      switch (_task!) {
            final FaceLandmarker t => t.detect(image),
            final HandLandmarker t => t.detect(image),
            final PoseLandmarker t => t.detect(image),
            final GestureRecognizer t => t.recognize(image),
            final HolisticLandmarker t => t.detect(image),
            final FaceDetector t => t.detect(image),
            final ObjectDetector t => t.detect(image),
            final ImageClassifier t => t.classify(image),
            final ImageSegmenter t => t.segment(image),
            final task => throw UnsupportedError('$task has no still images.'),
          }
          as Future<R>;

  @override
  Future<R> detectFrame(
    VisionImage frame,
    int timestamp, {
    required int rotationDegrees,
  }) =>
      switch (_task!) {
            final FaceLandmarker t => t.detectForVideo(
              frame,
              timestampMilliseconds: timestamp,
              rotationDegrees: rotationDegrees,
            ),
            final HandLandmarker t => t.detectForVideo(
              frame,
              timestampMilliseconds: timestamp,
              rotationDegrees: rotationDegrees,
            ),
            final PoseLandmarker t => t.detectForVideo(
              frame,
              timestampMilliseconds: timestamp,
              rotationDegrees: rotationDegrees,
            ),
            final GestureRecognizer t => t.recognizeForVideo(
              frame,
              timestampMilliseconds: timestamp,
              rotationDegrees: rotationDegrees,
            ),
            final HolisticLandmarker t => t.detectForVideo(
              frame,
              timestampMilliseconds: timestamp,
              rotationDegrees: rotationDegrees,
            ),
            final FaceDetector t => t.detectForVideo(
              frame,
              timestampMilliseconds: timestamp,
              rotationDegrees: rotationDegrees,
            ),
            final ObjectDetector t => t.detectForVideo(
              frame,
              timestampMilliseconds: timestamp,
              rotationDegrees: rotationDegrees,
            ),
            final ImageClassifier t => t.classifyForVideo(
              frame,
              timestampMilliseconds: timestamp,
              rotationDegrees: rotationDegrees,
            ),
            final ImageSegmenter t => t.segmentForVideo(
              frame,
              timestampMilliseconds: timestamp,
              rotationDegrees: rotationDegrees,
            ),
            final task => throw UnsupportedError('$task has no video mode.'),
          }
          as Future<R>;

  @override
  void submit(
    VisionImage frame,
    int timestamp, {
    required int rotationDegrees,
  }) => switch (_task!) {
    final FaceLandmarker t => t.detectAsync(
      frame,
      timestampMilliseconds: timestamp,
      rotationDegrees: rotationDegrees,
    ),
    final HandLandmarker t => t.detectAsync(
      frame,
      timestampMilliseconds: timestamp,
      rotationDegrees: rotationDegrees,
    ),
    final PoseLandmarker t => t.detectAsync(
      frame,
      timestampMilliseconds: timestamp,
      rotationDegrees: rotationDegrees,
    ),
    final GestureRecognizer t => t.recognizeAsync(
      frame,
      timestampMilliseconds: timestamp,
      rotationDegrees: rotationDegrees,
    ),
    final HolisticLandmarker t => t.detectAsync(
      frame,
      timestampMilliseconds: timestamp,
      rotationDegrees: rotationDegrees,
    ),
    final FaceDetector t => t.detectAsync(
      frame,
      timestampMilliseconds: timestamp,
      rotationDegrees: rotationDegrees,
    ),
    final ObjectDetector t => t.detectAsync(
      frame,
      timestampMilliseconds: timestamp,
      rotationDegrees: rotationDegrees,
    ),
    final ImageClassifier t => t.classifyAsync(
      frame,
      timestampMilliseconds: timestamp,
      rotationDegrees: rotationDegrees,
    ),
    final ImageSegmenter t => t.segmentAsync(
      frame,
      timestampMilliseconds: timestamp,
      rotationDegrees: rotationDegrees,
    ),
    final task => throw UnsupportedError('$task has no live stream mode.'),
  };

  @override
  Stream<LiveResult<R>> get results {
    LiveResult<R> timed(int? timestamp, Object result) =>
        (timestamp: timestamp!, result: result as R);
    return switch (_task!) {
      final FaceLandmarker t => t.results.map(
        (r) => timed(r.timestampMilliseconds, r),
      ),
      final HandLandmarker t => t.results.map(
        (r) => timed(r.timestampMilliseconds, r),
      ),
      final PoseLandmarker t => t.results.map(
        (r) => timed(r.timestampMilliseconds, r),
      ),
      final GestureRecognizer t => t.results.map(
        (r) => timed(r.timestampMilliseconds, r),
      ),
      final HolisticLandmarker t => t.results.map(
        (r) => timed(r.timestampMilliseconds, r),
      ),
      final FaceDetector t => t.results.map(
        (r) => timed(r.timestampMilliseconds, r),
      ),
      final ObjectDetector t => t.results.map(
        (r) => timed(r.timestampMilliseconds, r),
      ),
      final ImageClassifier t => t.results.map(
        (r) => timed(r.timestampMilliseconds, r),
      ),
      final ImageSegmenter t => t.results.map(
        (r) => timed(r.timestampMilliseconds, r),
      ),
      final task => throw UnsupportedError('$task has no live stream mode.'),
    };
  }

  @override
  int get droppedFrames => switch (_task) {
    final FaceLandmarker t => t.droppedFrames,
    final HandLandmarker t => t.droppedFrames,
    final PoseLandmarker t => t.droppedFrames,
    final GestureRecognizer t => t.droppedFrames,
    final HolisticLandmarker t => t.droppedFrames,
    final FaceDetector t => t.droppedFrames,
    final ObjectDetector t => t.droppedFrames,
    final ImageClassifier t => t.droppedFrames,
    final ImageSegmenter t => t.droppedFrames,
    _ => 0,
  };

  @override
  Future<void> close() async {
    final task = _task;
    _task = null;
    await task?.dispose();
  }
}

/// Draws results in a browser worker where the browser can; only the web
/// camera controller attaches one.
base mixin _BrowserOverlay<R> on _VisionLiveTask<R>
    implements BrowserOverlayLiveTask {
  BrowserOverlay? _overlay;

  @override
  Future<void> attachOverlay(Object canvas) async {
    _overlay = await BrowserOverlay.attach(_task!, canvas);
  }

  @override
  void setOverlayOptions({
    required bool connections,
    required bool points,
    required bool mirrored,
    required double scale,
  }) => _overlay?.configure(
    connections: connections,
    points: points,
    mirrored: mirrored,
    scale: scale,
  );

  @override
  bool get overlayActive => _overlay?.active ?? false;

  @override
  Future<void> close() {
    _overlay = null;
    return super.close();
  }
}

final class FaceLandmarkerLiveTask extends _VisionLiveTask<FaceLandmarkerResult>
    with _BrowserOverlay {
  @override
  final settings = TaskSettingValues('face_landmarker');

  @override
  String get name => 'Face Landmarker';

  @override
  Future<FaceLandmarker> create(
    Delegate delegate,
    Uint8List model,
    RunningMode mode,
  ) => FaceLandmarker.create(
    FaceLandmarkerOptions(
      modelBytes: model,
      runningMode: mode,
      delegate: delegate,
      numFaces: settings.count('numFaces'),
      minFaceDetectionConfidence: settings.share('minFaceDetectionConfidence'),
      minFacePresenceConfidence: settings.share('minFacePresenceConfidence'),
      minTrackingConfidence: settings.share('minTrackingConfidence'),
      // Scored in the Output card, as Google's demo lists them.
      outputFaceBlendshapes: true,
    ),
  );
}

final class HandLandmarkerLiveTask extends _VisionLiveTask<HandLandmarkerResult>
    with _BrowserOverlay {
  @override
  final settings = TaskSettingValues('hand_landmarker');

  @override
  String get name => 'Hand Landmarker';

  @override
  Future<HandLandmarker> create(
    Delegate delegate,
    Uint8List model,
    RunningMode mode,
  ) => HandLandmarker.create(
    HandLandmarkerOptions(
      modelBytes: model,
      runningMode: mode,
      delegate: delegate,
      numHands: settings.count('numHands'),
      minHandDetectionConfidence: settings.share('minHandDetectionConfidence'),
      minHandPresenceConfidence: settings.share('minHandPresenceConfidence'),
      minTrackingConfidence: settings.share('minTrackingConfidence'),
    ),
  );
}

final class PoseLandmarkerLiveTask extends _VisionLiveTask<PoseLandmarkerResult>
    with _BrowserOverlay {
  @override
  final settings = TaskSettingValues('pose_landmarker');

  @override
  String get name => 'Pose Landmarker';

  @override
  Future<PoseLandmarker> create(
    Delegate delegate,
    Uint8List model,
    RunningMode mode,
  ) => PoseLandmarker.create(
    PoseLandmarkerOptions(
      modelBytes: model,
      runningMode: mode,
      delegate: delegate,
      numPoses: settings.count('numPoses'),
      minPoseDetectionConfidence: settings.share('minPoseDetectionConfidence'),
      minPosePresenceConfidence: settings.share('minPosePresenceConfidence'),
      minTrackingConfidence: settings.share('minTrackingConfidence'),
      outputSegmentationMasks: settings.on('outputSegmentationMasks'),
    ),
  );
}

final class GestureRecognizerLiveTask
    extends _VisionLiveTask<GestureRecognizerResult>
    with _BrowserOverlay {
  @override
  final settings = TaskSettingValues('gesture_recognizer');

  @override
  String get name => 'Gesture Recognizer';

  @override
  Future<GestureRecognizer> create(
    Delegate delegate,
    Uint8List model,
    RunningMode mode,
  ) => GestureRecognizer.create(
    GestureRecognizerOptions(
      modelBytes: model,
      runningMode: mode,
      delegate: delegate,
      numHands: settings.count('numHands'),
      minHandDetectionConfidence: settings.share('minHandDetectionConfidence'),
      minHandPresenceConfidence: settings.share('minHandPresenceConfidence'),
      minTrackingConfidence: settings.share('minTrackingConfidence'),
      cannedGesturesClassifierOptions: ClassifierOptions(
        maxResults: settings.count('maxResults'),
        scoreThreshold: settings.share('scoreThreshold'),
      ),
    ),
  );
}

final class HolisticLandmarkerLiveTask
    extends _VisionLiveTask<HolisticLandmarkerResult>
    with _BrowserOverlay
    implements FixedFrameSizeLiveTask {
  @override
  final settings = TaskSettingValues('holistic_landmarker');

  @override
  String get name => 'Holistic Landmarker';

  @override
  Future<HolisticLandmarker> create(
    Delegate delegate,
    Uint8List model,
    RunningMode mode,
  ) => HolisticLandmarker.create(
    HolisticLandmarkerOptions(
      modelBytes: model,
      runningMode: mode,
      delegate: delegate,
      minFaceDetectionConfidence: settings.share('minFaceDetectionConfidence'),
      minFaceSuppressionThreshold: settings.share(
        'minFaceSuppressionThreshold',
      ),
      minFacePresenceConfidence: settings.share('minFacePresenceConfidence'),
      minPoseDetectionConfidence: settings.share('minPoseDetectionConfidence'),
      minPoseSuppressionThreshold: settings.share(
        'minPoseSuppressionThreshold',
      ),
      minPosePresenceConfidence: settings.share('minPosePresenceConfidence'),
      minHandLandmarksConfidence: settings.share('minHandLandmarksConfidence'),
      outputPoseSegmentationMask: settings.on('outputPoseSegmentationMask'),
    ),
  );
}

final class FaceDetectorLiveTask extends _VisionLiveTask<FaceDetectorResult>
    with _BrowserOverlay {
  @override
  final settings = TaskSettingValues('face_detector');

  @override
  String get name => 'Face Detector';

  @override
  Future<FaceDetector> create(
    Delegate delegate,
    Uint8List model,
    RunningMode mode,
  ) => FaceDetector.create(
    FaceDetectorOptions(
      modelBytes: model,
      runningMode: mode,
      delegate: delegate,
      minDetectionConfidence: settings.share('minDetectionConfidence'),
      minSuppressionThreshold: settings.share('minSuppressionThreshold'),
    ),
  );
}

final class ObjectDetectorLiveTask extends _VisionLiveTask<ObjectDetectorResult>
    with _BrowserOverlay {
  @override
  final settings = TaskSettingValues('object_detector');

  @override
  String get name => 'Object Detector';

  @override
  Future<ObjectDetector> create(
    Delegate delegate,
    Uint8List model,
    RunningMode mode,
  ) => ObjectDetector.create(
    ObjectDetectorOptions(
      modelBytes: model,
      runningMode: mode,
      delegate: delegate,
      maxResults: settings.count('maxResults'),
      scoreThreshold: settings.share('scoreThreshold'),
    ),
  );
}

final class ImageClassifierLiveTask
    extends _VisionLiveTask<ImageClassifierResult>
    with _BrowserOverlay {
  @override
  final settings = TaskSettingValues('image_classifier');

  @override
  String get name => 'Image Classifier';

  @override
  Future<ImageClassifier> create(
    Delegate delegate,
    Uint8List model,
    RunningMode mode,
  ) => ImageClassifier.create(
    ImageClassifierOptions(
      modelBytes: model,
      runningMode: mode,
      delegate: delegate,
      maxResults: settings.count('maxResults'),
      scoreThreshold: settings.share('scoreThreshold'),
    ),
  );
}

/// Returns the category mask and, for Output Type Confidence Mask, the
/// confidence masks.
final class ImageSegmenterLiveTask
    extends _VisionLiveTask<ImageSegmenterResult> {
  @override
  final settings = TaskSettingValues('image_segmenter');

  @override
  String get name => 'Image Segmenter';

  @override
  Future<ImageSegmenter> create(
    Delegate delegate,
    Uint8List model,
    RunningMode mode,
  ) => ImageSegmenter.create(
    ImageSegmenterOptions(
      modelBytes: model,
      runningMode: mode,
      delegate: delegate,
      outputConfidenceMasks: settings.choice('outputConfidenceMasks') == 1,
      outputCategoryMask: true,
    ),
  );
}
