# Video and live stream samples for vision tasks

The vision README's
[samples for every task](../../../packages/mediapipe-task-vision/README.md#samples-for-every-task)
run on still images. Here are the ten camera-capable tasks in their two other
running modes. In `RunningMode.video` each call completes with its frame's
result, so every frame of a decoded video file is processed in order. In
`RunningMode.liveStream` each call returns at once and results arrive on the
task's `results` stream; a task slower than the camera drops frames instead of
falling behind. The README's [Video files](../../../packages/mediapipe-task-vision/README.md#video-files)
and [Live cameras](../../../packages/mediapipe-task-vision/README.md#live-cameras)
sections cover the details: strictly increasing timestamps, dropped frames,
rotation, `VisionImage.deferred` and browser frames.

Each sample takes a `Stream` of `Frame` records: RGBA bytes, the size, and a
timestamp in milliseconds (the presentation time of a video frame, or the
time a camera frame arrived). Timestamps must strictly increase, and a
repeated one throws. Camera frames that arrive in a burst can share a
millisecond, so a pipeline that stamps frames as they arrive moves the later
one a millisecond on, as the README's live camera sample does. The package
does not decode video or open a camera, so your decoder or camera pipeline
supplies them. Each sample creates
its task with Google's pinned model, bundled as the README's
[quick start](../../../packages/mediapipe-task-vision/README.md#quick-start-detect-face-landmarks)
describes, runs until the stream ends and disposes the task. In an app, create
a task once and keep it for the whole video or camera session.

The Interactive Segmenter works on one image with editing strokes and has no
video or live stream mode.

[Face Detector](#face-detector) ·
[Face Landmarker](#face-landmarker) ·
[Hand Landmarker](#hand-landmarker) ·
[Gesture Recognizer](#gesture-recognizer) ·
[Pose Landmarker](#pose-landmarker) ·
[Holistic Landmarker](#holistic-landmarker) ·
[Object Detector](#object-detector) ·
[Image Classifier](#image-classifier) ·
[Image Embedder](#image-embedder) ·
[Image Segmenter](#image-segmenter)

## Face Detector

A box in pixels and a score per face, in every frame.

### Video

```dart
import 'dart:typed_data';

import 'package:mediapipe_vision/mediapipe_vision.dart';

typedef Frame = ({Uint8List rgba, int width, int height, int milliseconds});

Future<void> findFacesInVideo(Stream<Frame> frames) async {
  final detector = await FaceDetector.create(
    FaceDetectorOptions(
      model: VisionModels.faceDetector,
      runningMode: RunningMode.video,
    ),
  );
  try {
    await for (final frame in frames) {
      final result = await detector.detectForVideo(
        VisionImage.fromPixels(
          pixels: frame.rgba,
          width: frame.width,
          height: frame.height,
          format: VisionPixelFormat.rgba,
        ),
        timestampMilliseconds: frame.milliseconds,
      );
      final ms = result.timestampMilliseconds;
      for (final face in result.detections) {
        final box = face.boundingBox;
        final score = face.categories.first.score.toStringAsFixed(2);
        print('$ms ms: face at ${box.left},${box.top}, confidence $score');
      }
    }
  } finally {
    await detector.dispose();
  }
}
```

### Live stream

```dart
import 'dart:typed_data';

import 'package:mediapipe_vision/mediapipe_vision.dart';

typedef Frame = ({Uint8List rgba, int width, int height, int milliseconds});

Future<void> findFacesLive(Stream<Frame> frames) async {
  final detector = await FaceDetector.create(
    FaceDetectorOptions(
      model: VisionModels.faceDetector,
      runningMode: RunningMode.liveStream,
    ),
  );
  // Listen before the first frame, as Google requires a result listener.
  final results = detector.results.listen((result) {
    final ms = result.timestampMilliseconds;
    for (final face in result.detections) {
      final box = face.boundingBox;
      final score = face.categories.first.score.toStringAsFixed(2);
      print('$ms ms: face at ${box.left},${box.top}, confidence $score');
    }
  });
  try {
    await for (final frame in frames) {
      detector.detectAsync(
        VisionImage.fromPixels(
          pixels: frame.rgba,
          width: frame.width,
          height: frame.height,
          format: VisionPixelFormat.rgba,
        ),
        timestampMilliseconds: frame.milliseconds,
      );
    }
  } finally {
    // Runs the frame in flight and the waiting one, then closes results.
    await detector.dispose();
    await results.cancel();
    print('${detector.droppedFrames} frames dropped');
  }
}
```

## Face Landmarker

478 landmarks per face, with the strongest of the 52 expression blendshapes.

### Video

```dart
import 'dart:typed_data';

import 'package:mediapipe_vision/mediapipe_vision.dart';

typedef Frame = ({Uint8List rgba, int width, int height, int milliseconds});

Future<void> readExpressionsInVideo(Stream<Frame> frames) async {
  final landmarker = await FaceLandmarker.create(
    FaceLandmarkerOptions(
      model: VisionModels.faceLandmarker,
      runningMode: RunningMode.video,
      outputFaceBlendshapes: true,
    ),
  );
  try {
    await for (final frame in frames) {
      final result = await landmarker.detectForVideo(
        VisionImage.fromPixels(
          pixels: frame.rgba,
          width: frame.width,
          height: frame.height,
          format: VisionPixelFormat.rgba,
        ),
        timestampMilliseconds: frame.milliseconds,
      );
      final ms = result.timestampMilliseconds;
      for (final shapes in result.faceBlendshapes) {
        final top = shapes.reduce((a, b) => a.score >= b.score ? a : b);
        print('$ms ms: ${top.categoryName} ${top.score.toStringAsFixed(2)}');
      }
    }
  } finally {
    await landmarker.dispose();
  }
}
```

### Live stream

```dart
import 'dart:typed_data';

import 'package:mediapipe_vision/mediapipe_vision.dart';

typedef Frame = ({Uint8List rgba, int width, int height, int milliseconds});

Future<void> readExpressionsLive(Stream<Frame> frames) async {
  final landmarker = await FaceLandmarker.create(
    FaceLandmarkerOptions(
      model: VisionModels.faceLandmarker,
      runningMode: RunningMode.liveStream,
      outputFaceBlendshapes: true,
    ),
  );
  // Listen before the first frame, as Google requires a result listener.
  final results = landmarker.results.listen((result) {
    final ms = result.timestampMilliseconds;
    for (final shapes in result.faceBlendshapes) {
      final top = shapes.reduce((a, b) => a.score >= b.score ? a : b);
      print('$ms ms: ${top.categoryName} ${top.score.toStringAsFixed(2)}');
    }
  });
  try {
    await for (final frame in frames) {
      landmarker.detectAsync(
        VisionImage.fromPixels(
          pixels: frame.rgba,
          width: frame.width,
          height: frame.height,
          format: VisionPixelFormat.rgba,
        ),
        timestampMilliseconds: frame.milliseconds,
      );
    }
  } finally {
    // Runs the frame in flight and the waiting one, then closes results.
    await landmarker.dispose();
    await results.cancel();
    print('${landmarker.droppedFrames} frames dropped');
  }
}
```

## Hand Landmarker

21 landmarks per hand, with which hand it is.

### Video

```dart
import 'dart:typed_data';

import 'package:mediapipe_vision/mediapipe_vision.dart';

typedef Frame = ({Uint8List rgba, int width, int height, int milliseconds});

Future<void> findHandsInVideo(Stream<Frame> frames) async {
  final landmarker = await HandLandmarker.create(
    HandLandmarkerOptions(
      model: VisionModels.handLandmarker,
      runningMode: RunningMode.video,
      numHands: 2,
    ),
  );
  try {
    await for (final frame in frames) {
      final result = await landmarker.detectForVideo(
        VisionImage.fromPixels(
          pixels: frame.rgba,
          width: frame.width,
          height: frame.height,
          format: VisionPixelFormat.rgba,
        ),
        timestampMilliseconds: frame.milliseconds,
      );
      final ms = result.timestampMilliseconds;
      for (var i = 0; i < result.handLandmarks.length; i++) {
        final side = result.handedness[i].first.categoryName;
        final wrist = result.handLandmarks[i].first;
        print('$ms ms: $side hand, wrist at ${wrist.x}, ${wrist.y}');
      }
    }
  } finally {
    await landmarker.dispose();
  }
}
```

### Live stream

```dart
import 'dart:typed_data';

import 'package:mediapipe_vision/mediapipe_vision.dart';

typedef Frame = ({Uint8List rgba, int width, int height, int milliseconds});

Future<void> findHandsLive(Stream<Frame> frames) async {
  final landmarker = await HandLandmarker.create(
    HandLandmarkerOptions(
      model: VisionModels.handLandmarker,
      runningMode: RunningMode.liveStream,
      numHands: 2,
    ),
  );
  // Listen before the first frame, as Google requires a result listener.
  final results = landmarker.results.listen((result) {
    final ms = result.timestampMilliseconds;
    for (var i = 0; i < result.handLandmarks.length; i++) {
      final side = result.handedness[i].first.categoryName;
      final wrist = result.handLandmarks[i].first;
      print('$ms ms: $side hand, wrist at ${wrist.x}, ${wrist.y}');
    }
  });
  try {
    await for (final frame in frames) {
      landmarker.detectAsync(
        VisionImage.fromPixels(
          pixels: frame.rgba,
          width: frame.width,
          height: frame.height,
          format: VisionPixelFormat.rgba,
        ),
        timestampMilliseconds: frame.milliseconds,
      );
    }
  } finally {
    // Runs the frame in flight and the waiting one, then closes results.
    await landmarker.dispose();
    await results.cancel();
    print('${landmarker.droppedFrames} frames dropped');
  }
}
```

## Gesture Recognizer

Google's canned gesture for each hand in the frame.

### Video

```dart
import 'dart:typed_data';

import 'package:mediapipe_vision/mediapipe_vision.dart';

typedef Frame = ({Uint8List rgba, int width, int height, int milliseconds});

Future<void> recognizeGesturesInVideo(Stream<Frame> frames) async {
  final recognizer = await GestureRecognizer.create(
    GestureRecognizerOptions(
      model: VisionModels.gestureRecognizer,
      runningMode: RunningMode.video,
      numHands: 2,
    ),
  );
  try {
    await for (final frame in frames) {
      final result = await recognizer.recognizeForVideo(
        VisionImage.fromPixels(
          pixels: frame.rgba,
          width: frame.width,
          height: frame.height,
          format: VisionPixelFormat.rgba,
        ),
        timestampMilliseconds: frame.milliseconds,
      );
      final ms = result.timestampMilliseconds;
      for (final gestures in result.gestures) {
        final top = gestures.first;
        print('$ms ms: ${top.categoryName} (${top.score.toStringAsFixed(2)})');
      }
    }
  } finally {
    await recognizer.dispose();
  }
}
```

### Live stream

```dart
import 'dart:typed_data';

import 'package:mediapipe_vision/mediapipe_vision.dart';

typedef Frame = ({Uint8List rgba, int width, int height, int milliseconds});

Future<void> recognizeGesturesLive(Stream<Frame> frames) async {
  final recognizer = await GestureRecognizer.create(
    GestureRecognizerOptions(
      model: VisionModels.gestureRecognizer,
      runningMode: RunningMode.liveStream,
      numHands: 2,
    ),
  );
  // Listen before the first frame, as Google requires a result listener.
  final results = recognizer.results.listen((result) {
    final ms = result.timestampMilliseconds;
    for (final gestures in result.gestures) {
      final top = gestures.first;
      print('$ms ms: ${top.categoryName} (${top.score.toStringAsFixed(2)})');
    }
  });
  try {
    await for (final frame in frames) {
      recognizer.recognizeAsync(
        VisionImage.fromPixels(
          pixels: frame.rgba,
          width: frame.width,
          height: frame.height,
          format: VisionPixelFormat.rgba,
        ),
        timestampMilliseconds: frame.milliseconds,
      );
    }
  } finally {
    // Runs the frame in flight and the waiting one, then closes results.
    await recognizer.dispose();
    await results.cancel();
    print('${recognizer.droppedFrames} frames dropped');
  }
}
```

## Pose Landmarker

33 body landmarks per pose; here, the nose.

### Video

```dart
import 'dart:typed_data';

import 'package:mediapipe_vision/mediapipe_vision.dart';

typedef Frame = ({Uint8List rgba, int width, int height, int milliseconds});

Future<void> findPosesInVideo(Stream<Frame> frames) async {
  final landmarker = await PoseLandmarker.create(
    PoseLandmarkerOptions(
      model: VisionModels.poseLandmarker,
      runningMode: RunningMode.video,
    ),
  );
  try {
    await for (final frame in frames) {
      final result = await landmarker.detectForVideo(
        VisionImage.fromPixels(
          pixels: frame.rgba,
          width: frame.width,
          height: frame.height,
          format: VisionPixelFormat.rgba,
        ),
        timestampMilliseconds: frame.milliseconds,
      );
      final ms = result.timestampMilliseconds;
      for (final pose in result.poseLandmarks) {
        final nose = pose.first;
        print('$ms ms: nose at ${nose.x}, ${nose.y}');
      }
    }
  } finally {
    await landmarker.dispose();
  }
}
```

### Live stream

```dart
import 'dart:typed_data';

import 'package:mediapipe_vision/mediapipe_vision.dart';

typedef Frame = ({Uint8List rgba, int width, int height, int milliseconds});

Future<void> findPosesLive(Stream<Frame> frames) async {
  final landmarker = await PoseLandmarker.create(
    PoseLandmarkerOptions(
      model: VisionModels.poseLandmarker,
      runningMode: RunningMode.liveStream,
    ),
  );
  // Listen before the first frame, as Google requires a result listener.
  final results = landmarker.results.listen((result) {
    final ms = result.timestampMilliseconds;
    for (final pose in result.poseLandmarks) {
      final nose = pose.first;
      print('$ms ms: nose at ${nose.x}, ${nose.y}');
    }
  });
  try {
    await for (final frame in frames) {
      landmarker.detectAsync(
        VisionImage.fromPixels(
          pixels: frame.rgba,
          width: frame.width,
          height: frame.height,
          format: VisionPixelFormat.rgba,
        ),
        timestampMilliseconds: frame.milliseconds,
      );
    }
  } finally {
    // Runs the frame in flight and the waiting one, then closes results.
    await landmarker.dispose();
    await results.cancel();
    print('${landmarker.droppedFrames} frames dropped');
  }
}
```

## Holistic Landmarker

Face, pose and both hands of one person, from one pass over each frame.

### Video

```dart
import 'dart:typed_data';

import 'package:mediapipe_vision/mediapipe_vision.dart';

typedef Frame = ({Uint8List rgba, int width, int height, int milliseconds});

Future<void> trackPersonInVideo(Stream<Frame> frames) async {
  final landmarker = await HolisticLandmarker.create(
    HolisticLandmarkerOptions(
      model: VisionModels.holisticLandmarker,
      runningMode: RunningMode.video,
    ),
  );
  try {
    await for (final frame in frames) {
      final result = await landmarker.detectForVideo(
        VisionImage.fromPixels(
          pixels: frame.rgba,
          width: frame.width,
          height: frame.height,
          format: VisionPixelFormat.rgba,
        ),
        timestampMilliseconds: frame.milliseconds,
      );
      final ms = result.timestampMilliseconds;
      print(
        '$ms ms: ${result.faceLandmarks.length} face, '
        '${result.poseLandmarks.length} pose, '
        '${result.leftHandLandmarks.length} left hand and '
        '${result.rightHandLandmarks.length} right hand landmarks',
      );
    }
  } finally {
    await landmarker.dispose();
  }
}
```

### Live stream

```dart
import 'dart:typed_data';

import 'package:mediapipe_vision/mediapipe_vision.dart';

typedef Frame = ({Uint8List rgba, int width, int height, int milliseconds});

Future<void> trackPersonLive(Stream<Frame> frames) async {
  final landmarker = await HolisticLandmarker.create(
    HolisticLandmarkerOptions(
      model: VisionModels.holisticLandmarker,
      runningMode: RunningMode.liveStream,
    ),
  );
  // Listen before the first frame, as Google requires a result listener.
  final results = landmarker.results.listen((result) {
    final ms = result.timestampMilliseconds;
    print(
      '$ms ms: ${result.faceLandmarks.length} face, '
      '${result.poseLandmarks.length} pose, '
      '${result.leftHandLandmarks.length} left hand and '
      '${result.rightHandLandmarks.length} right hand landmarks',
    );
  });
  try {
    await for (final frame in frames) {
      landmarker.detectAsync(
        VisionImage.fromPixels(
          pixels: frame.rgba,
          width: frame.width,
          height: frame.height,
          format: VisionPixelFormat.rgba,
        ),
        timestampMilliseconds: frame.milliseconds,
      );
    }
  } finally {
    // Runs the frame in flight and the waiting one, then closes results.
    await landmarker.dispose();
    await results.cancel();
    print('${landmarker.droppedFrames} frames dropped');
  }
}
```

## Object Detector

Labeled boxes in pixels, at most five a frame, with a score of at least 0.4.

### Video

```dart
import 'dart:typed_data';

import 'package:mediapipe_vision/mediapipe_vision.dart';

typedef Frame = ({Uint8List rgba, int width, int height, int milliseconds});

Future<void> detectObjectsInVideo(Stream<Frame> frames) async {
  final detector = await ObjectDetector.create(
    ObjectDetectorOptions(
      model: VisionModels.objectDetector,
      runningMode: RunningMode.video,
      maxResults: 5,
      scoreThreshold: 0.4,
    ),
  );
  try {
    await for (final frame in frames) {
      final result = await detector.detectForVideo(
        VisionImage.fromPixels(
          pixels: frame.rgba,
          width: frame.width,
          height: frame.height,
          format: VisionPixelFormat.rgba,
        ),
        timestampMilliseconds: frame.milliseconds,
      );
      final ms = result.timestampMilliseconds;
      for (final detection in result.detections) {
        final label = detection.categories.first;
        final box = detection.boundingBox;
        print('$ms ms: ${label.categoryName} at ${box.left},${box.top}');
      }
    }
  } finally {
    await detector.dispose();
  }
}
```

### Live stream

```dart
import 'dart:typed_data';

import 'package:mediapipe_vision/mediapipe_vision.dart';

typedef Frame = ({Uint8List rgba, int width, int height, int milliseconds});

Future<void> detectObjectsLive(Stream<Frame> frames) async {
  final detector = await ObjectDetector.create(
    ObjectDetectorOptions(
      model: VisionModels.objectDetector,
      runningMode: RunningMode.liveStream,
      maxResults: 5,
      scoreThreshold: 0.4,
    ),
  );
  // Listen before the first frame, as Google requires a result listener.
  final results = detector.results.listen((result) {
    final ms = result.timestampMilliseconds;
    for (final detection in result.detections) {
      final label = detection.categories.first;
      final box = detection.boundingBox;
      print('$ms ms: ${label.categoryName} at ${box.left},${box.top}');
    }
  });
  try {
    await for (final frame in frames) {
      detector.detectAsync(
        VisionImage.fromPixels(
          pixels: frame.rgba,
          width: frame.width,
          height: frame.height,
          format: VisionPixelFormat.rgba,
        ),
        timestampMilliseconds: frame.milliseconds,
      );
    }
  } finally {
    // Runs the frame in flight and the waiting one, then closes results.
    await detector.dispose();
    await results.cancel();
    print('${detector.droppedFrames} frames dropped');
  }
}
```

## Image Classifier

The three most likely categories for each whole frame.

### Video

```dart
import 'dart:typed_data';

import 'package:mediapipe_vision/mediapipe_vision.dart';

typedef Frame = ({Uint8List rgba, int width, int height, int milliseconds});

Future<void> classifyFramesInVideo(Stream<Frame> frames) async {
  final classifier = await ImageClassifier.create(
    ImageClassifierOptions(
      model: VisionModels.imageClassifier,
      runningMode: RunningMode.video,
      maxResults: 3,
    ),
  );
  try {
    await for (final frame in frames) {
      final result = await classifier.classifyForVideo(
        VisionImage.fromPixels(
          pixels: frame.rgba,
          width: frame.width,
          height: frame.height,
          format: VisionPixelFormat.rgba,
        ),
        timestampMilliseconds: frame.milliseconds,
      );
      final ms = result.timestampMilliseconds;
      final top = result.classifications.first.categories.map(
        (category) =>
            '${category.categoryName} ${category.score.toStringAsFixed(2)}',
      );
      print('$ms ms: ${top.join(', ')}');
    }
  } finally {
    await classifier.dispose();
  }
}
```

### Live stream

```dart
import 'dart:typed_data';

import 'package:mediapipe_vision/mediapipe_vision.dart';

typedef Frame = ({Uint8List rgba, int width, int height, int milliseconds});

Future<void> classifyFramesLive(Stream<Frame> frames) async {
  final classifier = await ImageClassifier.create(
    ImageClassifierOptions(
      model: VisionModels.imageClassifier,
      runningMode: RunningMode.liveStream,
      maxResults: 3,
    ),
  );
  // Listen before the first frame, as Google requires a result listener.
  final results = classifier.results.listen((result) {
    final ms = result.timestampMilliseconds;
    final top = result.classifications.first.categories.map(
      (category) =>
          '${category.categoryName} ${category.score.toStringAsFixed(2)}',
    );
    print('$ms ms: ${top.join(', ')}');
  });
  try {
    await for (final frame in frames) {
      classifier.classifyAsync(
        VisionImage.fromPixels(
          pixels: frame.rgba,
          width: frame.width,
          height: frame.height,
          format: VisionPixelFormat.rgba,
        ),
        timestampMilliseconds: frame.milliseconds,
      );
    }
  } finally {
    // Runs the frame in flight and the waiting one, then closes results.
    await classifier.dispose();
    await results.cancel();
    print('${classifier.droppedFrames} frames dropped');
  }
}
```

## Image Embedder

A feature vector per frame. Comparing each with the one before finds scene
changes: values near 1 mean similar content.

### Video

```dart
import 'dart:typed_data';

import 'package:mediapipe_vision/mediapipe_vision.dart';

typedef Frame = ({Uint8List rgba, int width, int height, int milliseconds});

Future<void> compareFramesInVideo(Stream<Frame> frames) async {
  final embedder = await ImageEmbedder.create(
    ImageEmbedderOptions(
      model: VisionModels.imageEmbedder,
      runningMode: RunningMode.video,
      l2Normalize: true,
    ),
  );
  Embedding? previous;
  try {
    await for (final frame in frames) {
      final result = await embedder.embedForVideo(
        VisionImage.fromPixels(
          pixels: frame.rgba,
          width: frame.width,
          height: frame.height,
          format: VisionPixelFormat.rgba,
        ),
        timestampMilliseconds: frame.milliseconds,
      );
      final ms = result.timestampMilliseconds;
      final embedding = result.embeddings.first;
      if (previous case final last?) {
        final similarity = ImageEmbedder.cosineSimilarity(last, embedding);
        print('$ms ms: ${similarity.toStringAsFixed(3)} like the frame before');
      }
      previous = embedding;
    }
  } finally {
    await embedder.dispose();
  }
}
```

### Live stream

```dart
import 'dart:typed_data';

import 'package:mediapipe_vision/mediapipe_vision.dart';

typedef Frame = ({Uint8List rgba, int width, int height, int milliseconds});

Future<void> compareFramesLive(Stream<Frame> frames) async {
  final embedder = await ImageEmbedder.create(
    ImageEmbedderOptions(
      model: VisionModels.imageEmbedder,
      runningMode: RunningMode.liveStream,
      l2Normalize: true,
    ),
  );
  Embedding? previous;
  // Listen before the first frame, as Google requires a result listener.
  final results = embedder.results.listen((result) {
    final ms = result.timestampMilliseconds;
    final embedding = result.embeddings.first;
    if (previous case final last?) {
      final similarity = ImageEmbedder.cosineSimilarity(last, embedding);
      print('$ms ms: ${similarity.toStringAsFixed(3)} like the frame before');
    }
    previous = embedding;
  });
  try {
    await for (final frame in frames) {
      embedder.embedAsync(
        VisionImage.fromPixels(
          pixels: frame.rgba,
          width: frame.width,
          height: frame.height,
          format: VisionPixelFormat.rgba,
        ),
        timestampMilliseconds: frame.milliseconds,
      );
    }
  } finally {
    // Runs the frame in flight and the waiting one, then closes results.
    await embedder.dispose();
    await results.cancel();
    print('${embedder.droppedFrames} frames dropped');
  }
}
```

## Image Segmenter

A category for every pixel; here, the one at the center of each frame.

### Video

```dart
import 'dart:typed_data';

import 'package:mediapipe_vision/mediapipe_vision.dart';

typedef Frame = ({Uint8List rgba, int width, int height, int milliseconds});

Future<void> segmentSceneInVideo(Stream<Frame> frames) async {
  final segmenter = await ImageSegmenter.create(
    ImageSegmenterOptions(
      model: VisionModels.imageSegmenter,
      runningMode: RunningMode.video,
      outputCategoryMask: true,
      outputConfidenceMasks: false,
    ),
  );
  try {
    await for (final frame in frames) {
      final result = await segmenter.segmentForVideo(
        VisionImage.fromPixels(
          pixels: frame.rgba,
          width: frame.width,
          height: frame.height,
          format: VisionPixelFormat.rgba,
        ),
        timestampMilliseconds: frame.milliseconds,
      );
      final ms = result.timestampMilliseconds;
      final mask = result.categoryMask!;
      final center =
          mask.categories[mask.height ~/ 2 * mask.width + mask.width ~/ 2];
      // Labels come from the model's metadata, which may have none.
      final label = center < result.labels.length
          ? result.labels[center]
          : 'category $center';
      print('$ms ms: the center pixel is $label');
    }
  } finally {
    await segmenter.dispose();
  }
}
```

### Live stream

```dart
import 'dart:typed_data';

import 'package:mediapipe_vision/mediapipe_vision.dart';

typedef Frame = ({Uint8List rgba, int width, int height, int milliseconds});

Future<void> segmentSceneLive(Stream<Frame> frames) async {
  final segmenter = await ImageSegmenter.create(
    ImageSegmenterOptions(
      model: VisionModels.imageSegmenter,
      runningMode: RunningMode.liveStream,
      outputCategoryMask: true,
      outputConfidenceMasks: false,
    ),
  );
  // Listen before the first frame, as Google requires a result listener.
  final results = segmenter.results.listen((result) {
    final ms = result.timestampMilliseconds;
    final mask = result.categoryMask!;
    final center =
        mask.categories[mask.height ~/ 2 * mask.width + mask.width ~/ 2];
    // Labels come from the model's metadata, which may have none.
    final label = center < result.labels.length
        ? result.labels[center]
        : 'category $center';
    print('$ms ms: the center pixel is $label');
  });
  try {
    await for (final frame in frames) {
      segmenter.segmentAsync(
        VisionImage.fromPixels(
          pixels: frame.rgba,
          width: frame.width,
          height: frame.height,
          format: VisionPixelFormat.rgba,
        ),
        timestampMilliseconds: frame.milliseconds,
      );
    }
  } finally {
    // Runs the frame in flight and the waiting one, then closes results.
    await segmenter.dispose();
    await results.cancel();
    print('${segmenter.droppedFrames} frames dropped');
  }
}
```
