# Options and extra outputs for vision tasks

The vision README's
[samples for every task](../../../packages/mediapipe-task-vision/README.md#samples-for-every-task)
use each task's defaults. Here are the options that add to a result or
change its shape, the region of interest, RGB input and the capability query
of every task, with a table of the options that only tune a result at the
end. Each sample creates its task with Google's pinned model, bundled as the
README's
[quick start](../../../packages/mediapipe-task-vision/README.md#quick-start-detect-face-landmarks)
describes, and disposes it when done. The samples run on still images; every
option here works the same in video and live stream mode.

[Capabilities](#capabilities) ·
[Region of interest](#region-of-interest) ·
[RGB pixels](#rgb-pixels) ·
[Facial transformation matrices](#facial-transformation-matrices) ·
[Segmentation masks](#segmentation-masks) ·
[Confidence masks](#confidence-masks) ·
[Quantized embeddings](#quantized-embeddings) ·
[Tuning options](#tuning-options)

## Capabilities

Every task has a query that says which delegates this package offers on the
current platform, and why the others are unavailable. It describes declared
support; it does not load a model.

```dart
import 'package:mediapipe_vision/mediapipe_vision.dart';

Future<void> reportVisionSupport() async {
  final queries = <String, Future<TaskCapabilities> Function()>{
    'Face Detector': queryFaceDetectorCapabilities,
    'Face Landmarker': queryFaceLandmarkerCapabilities,
    'Hand Landmarker': queryHandLandmarkerCapabilities,
    'Gesture Recognizer': queryGestureRecognizerCapabilities,
    'Pose Landmarker': queryPoseLandmarkerCapabilities,
    'Holistic Landmarker': queryHolisticLandmarkerCapabilities,
    'Object Detector': queryObjectDetectorCapabilities,
    'Image Classifier': queryImageClassifierCapabilities,
    'Image Embedder': queryImageEmbedderCapabilities,
    'Image Segmenter': queryImageSegmenterCapabilities,
    'Interactive Segmenter': queryInteractiveSegmenterCapabilities,
  };
  for (final MapEntry(key: task, value: query) in queries.entries) {
    final support = await query();
    final delegates = support.supportedDelegates.map((d) => d.name);
    print('$task: ${delegates.isEmpty ? 'unavailable' : delegates.join(', ')}');
    for (final MapEntry(key: delegate, value: reason)
        in support.unavailableReasons.entries) {
      print('  no ${delegate.name}: $reason');
    }
  }
}
```

## Region of interest

The Image Classifier and the Image Embedder can look at part of an image. A
`VisionRegionOfInterest` gives its edges in coordinates normalized to the
image, and `classify`, `embed` and their video and live stream forms all take
one.

```dart
import 'package:mediapipe_vision/mediapipe_vision.dart';

Future<void> classifyHalves(VisionImage image) async {
  final classifier = await ImageClassifier.create(
    ImageClassifierOptions(model: VisionModels.imageClassifier, maxResults: 1),
  );
  try {
    final halves = {
      'Left': VisionRegionOfInterest(left: 0, top: 0, right: 0.5, bottom: 1),
      'Right': VisionRegionOfInterest(left: 0.5, top: 0, right: 1, bottom: 1),
    };
    for (final MapEntry(key: side, value: region) in halves.entries) {
      final result = await classifier.classify(image, regionOfInterest: region);
      final top = result.classifications.first.categories.first;
      final score = top.score.toStringAsFixed(2);
      print('$side half: ${top.categoryName} ($score)');
    }
  } finally {
    await classifier.dispose();
  }
}
```

## RGB pixels

`VisionImage.fromPixels` takes `VisionPixelFormat.rgb` (three bytes a pixel,
as many image decoders return them), `rgba` (four) or `bgra` (four, in the
order Apple cameras supply). Rows default to the width times the channel
count; pass `bytesPerRow` when a camera pads them.

```dart
import 'dart:typed_data';

import 'package:mediapipe_vision/mediapipe_vision.dart';

Future<void> findFacesInRgb(Uint8List rgb, int width, int height) async {
  final detector = await FaceDetector.create(
    FaceDetectorOptions(model: VisionModels.faceDetector),
  );
  try {
    final result = await detector.detect(
      VisionImage.fromPixels(
        pixels: rgb,
        width: width,
        height: height,
        format: VisionPixelFormat.rgb,
      ),
    );
    for (final face in result.detections) {
      final box = face.boundingBox;
      print('Face at ${box.left},${box.top}, ${box.width}x${box.height}');
    }
  } finally {
    await detector.dispose();
  }
}
```

## Facial transformation matrices

With `outputFacialTransformationMatrixes`, the Face Landmarker also returns,
for each face, the transform from Google's canonical face model to the face
it found: a 4 by 4 `Matrix`. `at(row, column)` reads one element, and `data`
holds the values column by column.

```dart
import 'package:mediapipe_vision/mediapipe_vision.dart';

Future<void> printHeadTransforms(VisionImage image) async {
  final landmarker = await FaceLandmarker.create(
    FaceLandmarkerOptions(
      model: VisionModels.faceLandmarker,
      outputFacialTransformationMatrixes: true,
    ),
  );
  try {
    final result = await landmarker.detect(image);
    for (final matrix in result.facialTransformationMatrixes) {
      for (var row = 0; row < matrix.rows; row++) {
        final values = [
          for (var column = 0; column < matrix.columns; column++)
            matrix.at(row, column).toStringAsFixed(2),
        ];
        print(values.join(' '));
      }
    }
  } finally {
    await landmarker.dispose();
  }
}
```

## Segmentation masks

With `outputSegmentationMasks`, the Pose Landmarker also returns one
foreground mask for each pose it found, in `segmentationMasks`. Each
`ConfidenceMask` holds one confidence in `[0, 1]` per pixel, indexed
`y * width + x`.

```dart
import 'package:mediapipe_vision/mediapipe_vision.dart';

Future<void> measurePeople(VisionImage image) async {
  final landmarker = await PoseLandmarker.create(
    PoseLandmarkerOptions(
      model: VisionModels.poseLandmarker,
      numPoses: 2,
      outputSegmentationMasks: true,
    ),
  );
  try {
    final result = await landmarker.detect(image);
    for (final (index, mask) in result.segmentationMasks!.indexed) {
      final covered = mask.confidence.where((c) => c > 0.5).length;
      final share = 100 * covered / (mask.width * mask.height);
      print('Person $index covers ${share.toStringAsFixed(1)}% of the image');
    }
  } finally {
    await landmarker.dispose();
  }
}
```

The Holistic Landmarker finds one person. `outputPoseSegmentationMask` adds
that person's mask, and `outputFaceBlendshapes` the 52 expression scores of
their face. Either is null when the part it comes from was not found.

```dart
import 'package:mediapipe_vision/mediapipe_vision.dart';

Future<void> describePerson(VisionImage image) async {
  final landmarker = await HolisticLandmarker.create(
    HolisticLandmarkerOptions(
      model: VisionModels.holisticLandmarker,
      outputPoseSegmentationMask: true,
      outputFaceBlendshapes: true,
    ),
  );
  try {
    final result = await landmarker.detect(image);
    if (result.poseSegmentationMask case final mask?) {
      final covered = mask.confidence.where((c) => c > 0.5).length;
      final share = 100 * covered / (mask.width * mask.height);
      print('The person covers ${share.toStringAsFixed(1)}% of the image');
    }
    if (result.faceBlendshapes case final blendshapes?) {
      final strongest = blendshapes.reduce((a, b) => a.score > b.score ? a : b);
      print('Strongest expression: ${strongest.categoryName}');
    }
  } finally {
    await landmarker.dispose();
  }
}
```

## Confidence masks

The Image Segmenter returns confidence masks by default: one per category,
in the order of `labels`. Request `outputCategoryMask` as well, or instead, as
the README's sample does, for the winning category per pixel.

```dart
import 'package:mediapipe_vision/mediapipe_vision.dart';

Future<void> measureCategories(VisionImage image) async {
  final segmenter = await ImageSegmenter.create(
    ImageSegmenterOptions(model: VisionModels.imageSegmenter),
  );
  try {
    final result = await segmenter.segment(image);
    for (final (index, mask) in result.confidenceMasks!.indexed) {
      final covered = mask.confidence.where((c) => c > 0.5).length;
      if (covered == 0) continue;
      final share = 100 * covered / (mask.width * mask.height);
      // Labels come from the model's metadata, which may have none.
      final label = index < result.labels.length
          ? result.labels[index]
          : 'category $index';
      print('$label: ${share.toStringAsFixed(1)}% of the image');
    }
  } finally {
    await segmenter.dispose();
  }
}
```

## Quantized embeddings

With `quantize`, the Image Embedder returns each vector as bytes in
`quantizedEmbedding`, one signed 8-bit value per dimension, instead of floats
in `floatEmbedding`. `ImageEmbedder.cosineSimilarity` compares two of the
same kind.

```dart
import 'package:mediapipe_vision/mediapipe_vision.dart';

Future<void> compareCompact(VisionImage first, VisionImage second) async {
  final embedder = await ImageEmbedder.create(
    ImageEmbedderOptions(model: VisionModels.imageEmbedder, quantize: true),
  );
  try {
    final a = (await embedder.embed(first)).embeddings.first;
    final b = (await embedder.embed(second)).embeddings.first;
    print('${a.quantizedEmbedding!.length} bytes each');
    final similarity = ImageEmbedder.cosineSimilarity(a, b);
    print('Similarity: ${similarity.toStringAsFixed(2)}');
  } finally {
    await embedder.dispose();
  }
}
```

## Tuning options

These options keep a result's shape and change what goes into it. Defaults
match Google's. The Object Detector's are in its
[guide](object_detector.md).

| Option | Tasks | What it does | Default |
| --- | --- | --- | --- |
| `numFaces`, `numHands`, `numPoses` | Face Landmarker; Hand Landmarker and Gesture Recognizer; Pose Landmarker | The most faces, hands or poses to return. Google's video smoothing of faces applies only at 1. | 1 |
| `minDetectionConfidence`, `minSuppressionThreshold` | Face Detector | The lowest score a face is returned with, and the overlap at which Google's non-maximum suppression merges two. | 0.5, 0.3 |
| `minFaceDetectionConfidence`, `minFacePresenceConfidence` | Face Landmarker, Holistic Landmarker | The lowest face detection and face presence confidence. | 0.5 |
| `minHandDetectionConfidence`, `minHandPresenceConfidence` | Hand Landmarker, Gesture Recognizer | The lowest palm detection confidence, and the lowest hand presence confidence from the landmark model. | 0.5 |
| `minPoseDetectionConfidence`, `minPosePresenceConfidence` | Pose Landmarker, Holistic Landmarker | The lowest person detection and pose presence confidence. | 0.5 |
| `minTrackingConfidence` | Face, Hand and Pose Landmarker, Gesture Recognizer | The lowest tracking confidence in video and live stream mode. | 0.5 |
| `minFaceSuppressionThreshold`, `minPoseSuppressionThreshold`, `minHandLandmarksConfidence` | Holistic Landmarker | Google's non-maximum suppression thresholds for faces and poses, and the lowest hand landmark confidence. | 0.5 |
| `maxResults`, `scoreThreshold` | Image Classifier, `ClassifierOptions` | The most categories to return (negative for all) and the lowest score kept. | -1, 0 |
| `categoryAllowlist`, `categoryDenylist` | Image Classifier, `ClassifierOptions` | Category names to keep, or to drop; set one or the other. | none |
| `displayNamesLocale` | Image Classifier, Image Segmenter, `ClassifierOptions` | The locale of the display names in the model's metadata. | null |
| `cannedGesturesClassifierOptions`, `customGesturesClassifierOptions` | Gesture Recognizer | `ClassifierOptions` for the model's built-in gestures, and for custom ones when the task bundle has them. | every gesture |
| `l2Normalize` | Image Embedder | Normalizes vectors with the L2 norm when the model does not already. | false |
