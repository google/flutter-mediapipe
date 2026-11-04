import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:mediapipe_vision/mediapipe_vision.dart';
import 'package:test/test.dart';

/// LIVE_STREAM runs on Google's VIDEO graph with the flow limiter in Dart, so
/// on Google's runtime the same frames must give the same results in both
/// modes, tracking included: the emulation's defining property. Each frame is
/// submitted after the previous result, so none waits or is dropped.
void main() {
  final portrait = _raw('face_detection/portrait-301x209.rgb', 301, 209);
  final hand = _raw('landmark_tasks/thumb_up.rgb', 382, 406);
  final pose = _raw('landmark_tasks/pose.rgb', 1000, 667);

  test('Face Detector', () async {
    await _same<FaceDetector, FaceDetectorResult>(
      portrait,
      (mode) => FaceDetector.create(
        FaceDetectorOptions(
          modelPath: 'models/blaze_face_short_range.tflite',
          runningMode: mode,
        ),
      ),
      (t, i, ms, r) =>
          t.detectForVideo(i, timestampMilliseconds: ms, rotationDegrees: r),
      (t, i, ms, r) =>
          t.detectAsync(i, timestampMilliseconds: ms, rotationDegrees: r),
      (t) => t.results,
      (r) => [r.detections, r.timestampMilliseconds],
    );
  });

  test('Face Landmarker', () async {
    await _same<FaceLandmarker, FaceLandmarkerResult>(
      portrait,
      (mode) => FaceLandmarker.create(
        FaceLandmarkerOptions(
          modelPath: 'models/face_landmarker.task',
          runningMode: mode,
          outputFaceBlendshapes: true,
          outputFacialTransformationMatrixes: true,
        ),
      ),
      (t, i, ms, r) =>
          t.detectForVideo(i, timestampMilliseconds: ms, rotationDegrees: r),
      (t, i, ms, r) =>
          t.detectAsync(i, timestampMilliseconds: ms, rotationDegrees: r),
      (t) => t.results,
      (r) => [
        r.faceLandmarks,
        r.faceBlendshapes,
        r.facialTransformationMatrixes,
        r.timestampMilliseconds,
      ],
    );
  });

  test('Hand Landmarker', () async {
    await _same<HandLandmarker, HandLandmarkerResult>(
      hand,
      (mode) => HandLandmarker.create(
        HandLandmarkerOptions(
          modelPath: 'models/hand_landmarker.task',
          runningMode: mode,
        ),
      ),
      (t, i, ms, r) =>
          t.detectForVideo(i, timestampMilliseconds: ms, rotationDegrees: r),
      (t, i, ms, r) =>
          t.detectAsync(i, timestampMilliseconds: ms, rotationDegrees: r),
      (t) => t.results,
      (r) => [
        r.handedness,
        r.handLandmarks,
        r.handWorldLandmarks,
        r.timestampMilliseconds,
      ],
    );
  });

  test('Gesture Recognizer', () async {
    await _same<GestureRecognizer, GestureRecognizerResult>(
      hand,
      (mode) => GestureRecognizer.create(
        GestureRecognizerOptions(
          modelPath: 'models/gesture_recognizer.task',
          runningMode: mode,
        ),
      ),
      (t, i, ms, r) =>
          t.recognizeForVideo(i, timestampMilliseconds: ms, rotationDegrees: r),
      (t, i, ms, r) =>
          t.recognizeAsync(i, timestampMilliseconds: ms, rotationDegrees: r),
      (t) => t.results,
      (r) => [
        r.gestures,
        r.handedness,
        r.handLandmarks,
        r.handWorldLandmarks,
        r.timestampMilliseconds,
      ],
    );
  });

  test('Pose Landmarker', () async {
    await _same<PoseLandmarker, PoseLandmarkerResult>(
      pose,
      (mode) => PoseLandmarker.create(
        PoseLandmarkerOptions(
          modelPath: 'models/pose_landmarker_lite.task',
          runningMode: mode,
          outputSegmentationMasks: true,
        ),
      ),
      (t, i, ms, r) =>
          t.detectForVideo(i, timestampMilliseconds: ms, rotationDegrees: r),
      (t, i, ms, r) =>
          t.detectAsync(i, timestampMilliseconds: ms, rotationDegrees: r),
      (t) => t.results,
      (r) => [
        r.poseLandmarks,
        r.poseWorldLandmarks,
        r.segmentationMasks,
        r.timestampMilliseconds,
      ],
    );
  });

  test('Holistic Landmarker', () async {
    await _same<HolisticLandmarker, HolisticLandmarkerResult>(
      pose,
      (mode) => HolisticLandmarker.create(
        HolisticLandmarkerOptions(
          modelPath: 'models/holistic_landmarker.task',
          runningMode: mode,
          outputFaceBlendshapes: true,
        ),
      ),
      (t, i, ms, r) =>
          t.detectForVideo(i, timestampMilliseconds: ms, rotationDegrees: r),
      (t, i, ms, r) =>
          t.detectAsync(i, timestampMilliseconds: ms, rotationDegrees: r),
      (t) => t.results,
      (r) => [
        r.faceLandmarks,
        r.poseLandmarks,
        r.poseWorldLandmarks,
        r.leftHandLandmarks,
        r.rightHandLandmarks,
        r.leftHandWorldLandmarks,
        r.rightHandWorldLandmarks,
        r.faceBlendshapes,
        r.timestampMilliseconds,
      ],
      // Holistic's VIDEO graph needs one frame size, so no quarter turn.
      turn: 0,
    );
  });

  test('Object Detector', () async {
    await _same<ObjectDetector, ObjectDetectorResult>(
      portrait,
      (mode) => ObjectDetector.create(
        ObjectDetectorOptions(
          modelPath: 'models/efficientdet_lite0.tflite',
          runningMode: mode,
        ),
      ),
      (t, i, ms, r) =>
          t.detectForVideo(i, timestampMilliseconds: ms, rotationDegrees: r),
      (t, i, ms, r) =>
          t.detectAsync(i, timestampMilliseconds: ms, rotationDegrees: r),
      (t) => t.results,
      (r) => [r.detections, r.timestampMilliseconds],
    );
  });

  final region = VisionRegionOfInterest(
    left: 0.2,
    top: 0.1,
    right: 0.9,
    bottom: 0.8,
  );

  test('Image Classifier, with a region of interest', () async {
    await _same<ImageClassifier, ImageClassifierResult>(
      portrait,
      (mode) => ImageClassifier.create(
        ImageClassifierOptions(
          modelPath: 'models/efficientnet_lite0.tflite',
          runningMode: mode,
          maxResults: 5,
        ),
      ),
      (t, i, ms, r) => t.classifyForVideo(
        i,
        timestampMilliseconds: ms,
        rotationDegrees: r,
        regionOfInterest: region,
      ),
      (t, i, ms, r) => t.classifyAsync(
        i,
        timestampMilliseconds: ms,
        rotationDegrees: r,
        regionOfInterest: region,
      ),
      (t) => t.results,
      (r) => [r.classifications, r.timestampMilliseconds],
    );
  });

  test('Image Embedder, with a region of interest', () async {
    await _same<ImageEmbedder, ImageEmbedderResult>(
      portrait,
      (mode) => ImageEmbedder.create(
        ImageEmbedderOptions(
          modelPath: 'models/mobilenet_v3_small.tflite',
          runningMode: mode,
        ),
      ),
      (t, i, ms, r) => t.embedForVideo(
        i,
        timestampMilliseconds: ms,
        rotationDegrees: r,
        regionOfInterest: region,
      ),
      (t, i, ms, r) => t.embedAsync(
        i,
        timestampMilliseconds: ms,
        rotationDegrees: r,
        regionOfInterest: region,
      ),
      (t) => t.results,
      (r) => [r.embeddings, r.timestampMilliseconds],
    );
  });

  test('Image Segmenter', () async {
    await _same<ImageSegmenter, ImageSegmenterResult>(
      portrait,
      (mode) => ImageSegmenter.create(
        ImageSegmenterOptions(
          modelPath: 'models/deeplab_v3.tflite',
          runningMode: mode,
          outputConfidenceMasks: true,
          outputCategoryMask: true,
        ),
      ),
      (t, i, ms, r) =>
          t.segmentForVideo(i, timestampMilliseconds: ms, rotationDegrees: r),
      (t, i, ms, r) =>
          t.segmentAsync(i, timestampMilliseconds: ms, rotationDegrees: r),
      (t) => t.results,
      (r) => [
        r.confidenceMasks,
        r.categoryMask,
        r.qualityScores,
        r.labels,
        r.timestampMilliseconds,
      ],
    );
  });
}

typedef _Raw = ({Uint8List pixels, int width, int height});

_Raw _raw(String path, int width, int height) => (
  pixels: File('test/fixtures/$path').readAsBytesSync(),
  width: width,
  height: height,
);

VisionImage _image(_Raw raw, {bool blank = false}) => VisionImage.fromPixels(
  pixels: blank ? Uint8List(raw.pixels.length) : raw.pixels,
  width: raw.width,
  height: raw.height,
  format: VisionPixelFormat.rgb,
);

/// Runs [frame]'s sequence (the subject, a quarter [turn] of it, an empty
/// frame that ends tracking, the subject twice more) through a VIDEO task and
/// a LIVE_STREAM task from [open], and requires every [values] to match.
Future<void> _same<T extends VisionTask, R>(
  _Raw frame,
  Future<T> Function(RunningMode mode) open,
  Future<R> Function(T task, VisionImage image, int ms, int turn) video,
  void Function(T task, VisionImage image, int ms, int turn) live,
  Stream<R> Function(T task) results,
  List<Object?> Function(R result) values, {
  int turn = 90,
}) async {
  final frames = [
    (_image(frame), 0, 0),
    (_image(frame), 33, turn),
    (_image(frame, blank: true), 66, 0),
    (_image(frame), 100, 0),
    (_image(frame), 133, 0),
  ];
  final videoTask = await open(RunningMode.video);
  final expected = <Object?>[];
  try {
    for (final (image, ms, turn) in frames) {
      expected.add(_plain(values(await video(videoTask, image, ms, turn))));
    }
  } finally {
    await videoTask.dispose();
  }

  final liveTask = await open(RunningMode.liveStream);
  final actual = <Object?>[];
  var arrived = Completer<void>();
  final subscription = results(liveTask).listen((result) {
    actual.add(_plain(values(result)));
    arrived.complete();
  });
  try {
    for (final (image, ms, turn) in frames) {
      live(liveTask, image, ms, turn);
      await arrived.future;
      arrived = Completer<void>();
    }
  } finally {
    await liveTask.dispose();
    await subscription.cancel();
  }
  _expectSame(actual, expected);
  // The subject's output differs from the empty frame's, timestamps aside,
  // so the comparison covers real output.
  List<Object?> untimed(Object? values) {
    final list = values! as List<Object?>;
    return list.sublist(0, list.length - 1);
  }

  expect(untimed(expected[0]), isNot(untimed(expected[2])));
}

final _number = RegExp(r'-?\d+(\.\d+)?(e[+-]?\d+)?');

/// Requires [actual] and [expected] to hold the same values, structure and
/// text exactly and every number within 1e-5, and prints the largest
/// difference: zero where Google's runtime repeats itself bit for bit.
void _expectSame(Object actual, Object expected) {
  final a = '$actual', e = '$expected';
  expect(a.replaceAll(_number, '#'), e.replaceAll(_number, '#'));
  final numbers = [
    for (final text in [a, e])
      [for (final m in _number.allMatches(text)) double.parse(m[0]!)],
  ];
  var largest = 0.0;
  for (var i = 0; i < numbers[0].length; i++) {
    final difference = (numbers[0][i] - numbers[1][i]).abs();
    if (difference > largest) largest = difference;
  }
  // ignore: avoid_print
  print('LIVE_STREAM_VIDEO_DELTA ${numbers[0].length} values, max $largest');
  expect(largest, lessThanOrEqualTo(1e-5));
}

/// Every value a result holds, as exact text, so results compare in full:
/// value types print their doubles exactly; masks and embeddings print only
/// their size, so their values are listed.
Object? _plain(Object? value) => switch (value) {
  ConfidenceMask(:final width, :final height, :final confidence) => [
    width,
    height,
    _plain(confidence),
  ],
  CategoryMask(:final width, :final height, :final categories) => [
    width,
    height,
    _plain(categories),
  ],
  Embedding(:final floatEmbedding, :final quantizedEmbedding) => [
    '$value',
    _plain(floatEmbedding),
    _plain(quantizedEmbedding),
  ],
  final List<Object?> list => [for (final item in list) _plain(item)],
  _ => value?.toString(),
};
