import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';
import 'package:web/web.dart' as web;
import 'package:mediapipe_gallery/bundled_model_assets.dart';

@JS('mediapipeApiTestReport')
external set _report(JSObject value);

void require(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<void> rejects(Future<Object?> Function() action, Type type) async {
  try {
    await action();
  } catch (error) {
    require(
      error.runtimeType == type || type == Object,
      'Expected $type, got $error',
    );
    return;
  }
  throw StateError('Expected $type');
}

Map<String, Object?> copied(FaceLandmarkerResult result) => {
  'width': result.imageWidth,
  'height': result.imageHeight,
  'landmarks': [
    for (final p in result.faceLandmarks.single) [p.x, p.y, p.z],
  ],
  'blendshapes': [for (final c in result.faceBlendshapes.single) c.score],
  'matrix': result.facialTransformationMatrixes.single.data,
};

Future<Map<String, Object?>> checkApi() async {
  final delegate = Uri.base.queryParameters['delegate'] == 'gpu'
      ? Delegate.gpu
      : Delegate.cpu;
  final data = await rootBundle.load(bundledModelFile('face_landmarker.task'));
  final sourceModel = Uint8List.fromList(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
  );
  final options = FaceLandmarkerOptions(
    delegate: delegate,
    modelBytes: sourceModel,
    outputFaceBlendshapes: true,
    outputFacialTransformationMatrixes: true,
  );
  final modelFirstByte = sourceModel.first;
  sourceModel.fillRange(0, sourceModel.length, 0);
  require(
    options.modelBytes!.first == modelFirstByte,
    'Model input was not copied',
  );
  final portrait = Uri.base
      .resolve('assets/assets/samples/portrait.jpg')
      .toString();
  final image = VisionImage.fromFile(portrait);
  final task = await FaceLandmarker.create(options);
  final checks = <String>[];
  late FaceLandmarkerResult original;
  try {
    require(
      options.modelBytes!.first == modelFirstByte,
      'Model buffer detached',
    );
    original = await task.detect(image);
    require(
      original.faceLandmarks.single.length == 478,
      'Expected 478 landmarks',
    );
    require(
      original.faceBlendshapes.single.length == 52,
      'Expected 52 blendshapes',
    );
    require(
      original.facialTransformationMatrixes.single.data.length == 16,
      'Expected 4x4 matrix',
    );
    checks.add('official-image-landmarks-blendshapes-matrix');
    final response = await web.window.fetch(portrait.toJS).toDart;
    final bitmap = await web.window
        .createImageBitmap(await response.blob().toDart)
        .toDart;
    final canvas = web.OffscreenCanvas(bitmap.width, bitmap.height);
    final context =
        canvas.getContext('2d')! as web.OffscreenCanvasRenderingContext2D;
    context.drawImage(bitmap, 0, 0);
    bitmap.close();
    final rgba = context
        .getImageData(0, 0, canvas.width, canvas.height)
        .data
        .toDart;
    for (final format in VisionPixelFormat.values) {
      final stride = canvas.width * format.channels + 16;
      final pixels = Uint8List(stride * canvas.height);
      for (var y = 0; y < canvas.height; y++) {
        for (var x = 0; x < canvas.width; x++) {
          final from = (y * canvas.width + x) * 4;
          final to = y * stride + x * format.channels;
          pixels[to] = rgba[from + (format == VisionPixelFormat.bgra ? 2 : 0)];
          pixels[to + 1] = rgba[from + 1];
          pixels[to + 2] =
              rgba[from + (format == VisionPixelFormat.bgra ? 0 : 2)];
          if (format.channels == 4) pixels[to + 3] = 255;
        }
      }
      final frame = VisionImage.fromPixels(
        pixels: pixels,
        width: canvas.width,
        height: canvas.height,
        format: format,
        bytesPerRow: stride,
      );
      pixels.fillRange(0, pixels.length, 0);
      final result = await task.detect(frame);
      require(
        result.faceLandmarks.single.length == 478,
        'Pixel inference failed',
      );
      for (var i = 0; i < 478; i++) {
        require(
          (result.faceLandmarks.single[i].x -
                      original.faceLandmarks.single[i].x)
                  .abs() <
              1e-5,
          'Padded ${format.name} changed x coordinate',
        );
        require(
          (result.faceLandmarks.single[i].y -
                      original.faceLandmarks.single[i].y)
                  .abs() <
              1e-5,
          'Padded ${format.name} changed y coordinate',
        );
      }
    }
    checks.add('copied-padded-rgb-rgba-bgra');
    for (final rotation in [0, 90, 180, 270, -90, 360, -360, 450]) {
      final result = await task.detect(image, rotationDegrees: rotation);
      require(
        result.imageWidth == original.imageWidth &&
            result.imageHeight == original.imageHeight,
        'Rotation changed input coordinate dimensions',
      );
      require(
        result.faceLandmarks
            .expand((f) => f)
            .every((p) => p.x.isFinite && p.y.isFinite && p.z.isFinite),
        'Invalid rotation result',
      );
    }
    checks.add('all-four-rotations');
    await rejects(() => task.detect(image, rotationDegrees: 45), ArgumentError);
    await rejects(
      () => task.detectForVideo(image, timestampMilliseconds: 1),
      StateError,
    );
  } finally {
    await task.dispose();
  }
  await task.dispose();
  await rejects(() => task.detect(image), StateError);
  require(
    original.faceLandmarks.single.length == 478,
    'Results invalid after disposal',
  );
  checks.add('owned-results-mode-validation-idempotent-disposal');
  final video = await FaceLandmarker.create(
    FaceLandmarkerOptions(
      delegate: delegate,
      modelBytes: options.modelBytes,
      runningMode: RunningMode.video,
    ),
  );
  try {
    final frames = await Future.wait([
      for (final t in [1, 2, 3])
        video.detectForVideo(image, timestampMilliseconds: t),
    ]);
    require(
      frames.every((r) => r.faceLandmarks.single.length == 478),
      'Queued VIDEO failed',
    );
    require(
      frames[0].timestampMilliseconds == 1 &&
          frames[2].timestampMilliseconds == 3,
      'Wrong timestamps',
    );
    await rejects(
      () => video.detectForVideo(image, timestampMilliseconds: 3),
      ArgumentError,
    );
    await rejects(
      () => video.detectForVideo(
        VisionImage.fromFile('missing.jpg'),
        timestampMilliseconds: 4,
      ),
      TaskException,
    );
    await rejects(
      () => video.detectForVideo(image, timestampMilliseconds: 4),
      ArgumentError,
    );
    final recovery = video.detectForVideo(image, timestampMilliseconds: 5);
    await video.dispose();
    require(
      (await recovery).faceLandmarks.single.length == 478,
      'Dispose lost pending result',
    );
    checks.add('video-queue-timestamps-failed-frame-recovery-disposal');
  } finally {
    await video.dispose();
  }
  await checkLiveStream(delegate, options.modelBytes!, portrait);
  checks.add('live-stream-equals-video-drops-and-closes-bitmaps');
  await rejects(
    () => FaceLandmarker.create(
      FaceLandmarkerOptions(modelBytes: Uint8List.fromList([1])),
    ),
    TaskException,
  );
  checks.add('invalid-model-explicit-error');
  final hand = await checkHandApi(delegate, checks);
  final landmarkTasks = await checkLandmarkTasksApi(delegate, checks);
  final detectionTasks = await checkDetectionTasksApi(delegate, checks);
  return {
    'status': 'passed',
    'checks': checks,
    'image': copied(original),
    'hand': hand,
    'landmark_tasks': landmarkTasks,
    'detection_tasks': detectionTasks,
  };
}

/// Live stream mode in the browser, where Google has none: the package runs
/// Google's flow limiter in front of the VIDEO graph. The same frames give
/// VIDEO's results; a frame that arrives while another waits replaces it, and
/// the package closes the replaced frame's bitmap.
Future<void> checkLiveStream(
  Delegate delegate,
  Uint8List model,
  String portrait,
) async {
  Future<FaceLandmarker> open(RunningMode mode) => FaceLandmarker.create(
    FaceLandmarkerOptions(
      delegate: delegate,
      modelBytes: model,
      runningMode: mode,
    ),
  );
  List<double> points(FaceLandmarkerResult result) => [
    for (final face in result.faceLandmarks)
      for (final p in face) ...[p.x, p.y, p.z],
  ];
  final image = VisionImage.fromFile(portrait);
  final frames = [(0, 0), (33, 90), (66, 0)];
  final video = await open(RunningMode.video);
  final expected = <List<double>>[];
  try {
    for (final (timestamp, rotation) in frames) {
      expected.add(
        points(
          await video.detectForVideo(
            image,
            timestampMilliseconds: timestamp,
            rotationDegrees: rotation,
          ),
        ),
      );
    }
  } finally {
    await video.dispose();
  }
  final live = await open(RunningMode.liveStream);
  try {
    try {
      live.detectAsync(image, timestampMilliseconds: 0);
      throw StateError('A frame without a listener was accepted');
    } on StateError catch (error) {
      require(
        error.message.contains('Listen to'),
        'Unexpected error: ${error.message}',
      );
    }
    final results = <FaceLandmarkerResult>[];
    var arrived = Completer<void>();
    final subscription = live.results.listen((result) {
      results.add(result);
      if (!arrived.isCompleted) arrived.complete();
    });
    for (final (timestamp, rotation) in frames) {
      live.detectAsync(
        image,
        timestampMilliseconds: timestamp,
        rotationDegrees: rotation,
      );
      await arrived.future;
      arrived = Completer<void>();
    }
    for (var i = 0; i < frames.length; i++) {
      final actual = points(results[i]);
      require(
        actual.length == expected[i].length && actual.isNotEmpty,
        'Live frame $i found other faces than VIDEO',
      );
      for (var j = 0; j < actual.length; j++) {
        require(
          (actual[j] - expected[i][j]).abs() < 1e-5,
          'Live frame $i differs from VIDEO',
        );
      }
    }
    final response = await web.window.fetch(portrait.toJS).toDart;
    final blob = await response.blob().toDart;
    final bitmaps = [
      for (var i = 0; i < 3; i++)
        await web.window.createImageBitmap(blob).toDart,
    ];
    for (var i = 0; i < 3; i++) {
      live.detectAsync(
        VisionImage.fromBrowserFrame(
          bitmaps[i],
          width: bitmaps[i].width,
          height: bitmaps[i].height,
        ),
        timestampMilliseconds: 100 + i,
      );
    }
    require(live.droppedFrames == 1, 'Expected one dropped frame');
    require(bitmaps[1].width == 0, 'The dropped bitmap stayed open');
    await live.dispose();
    await subscription.cancel();
    require(
      [for (final r in results.skip(frames.length)) r.timestampMilliseconds]
              .join(',') ==
          '100,102',
      'Disposal did not deliver the running and the waiting frame',
    );
  } finally {
    await live.dispose();
  }
}

/// The same public contract for Hand Landmarker on the official web runtime.
Future<Map<String, Object?>> checkHandApi(
  Delegate delegate,
  List<String> checks,
) async {
  final data = await rootBundle.load(bundledModelFile('hand_landmarker.task'));
  final model = Uint8List.fromList(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
  );
  final image = VisionImage.fromFile(
    Uri.base.resolve('assets/assets/samples/hands.jpg').toString(),
  );
  final task = await HandLandmarker.create(
    HandLandmarkerOptions(delegate: delegate, modelBytes: model, numHands: 2),
  );
  late HandLandmarkerResult result;
  try {
    result = await task.detect(image);
    require(result.handLandmarks.isNotEmpty, 'Expected a hand');
    require(
      result.handLandmarks.every((hand) => hand.length == 21) &&
          result.handWorldLandmarks.every((hand) => hand.length == 21) &&
          result.handedness.length == result.handLandmarks.length,
      'Expected 21 image and world landmarks and handedness per hand',
    );
    for (final rotation in [90, 180, 270, -90]) {
      final rotated = await task.detect(image, rotationDegrees: rotation);
      require(
        rotated.imageWidth == result.imageWidth &&
            rotated.imageHeight == result.imageHeight,
        'Rotation changed hand input dimensions',
      );
    }
    await rejects(
      () => task.detectForVideo(image, timestampMilliseconds: 1),
      StateError,
    );
  } finally {
    await task.dispose();
  }
  await rejects(() => task.detect(image), StateError);
  checks.add('hand-image-world-landmarks-handedness-rotation-disposal');
  final video = await HandLandmarker.create(
    HandLandmarkerOptions(
      delegate: delegate,
      modelBytes: model,
      numHands: 2,
      runningMode: RunningMode.video,
    ),
  );
  try {
    final frames = await Future.wait([
      for (final t in [1, 2, 3])
        video.detectForVideo(image, timestampMilliseconds: t),
    ]);
    require(
      frames.every((r) => r.handLandmarks.isNotEmpty) &&
          frames.last.timestampMilliseconds == 3,
      'Queued hand VIDEO failed',
    );
    await rejects(
      () => video.detectForVideo(
        VisionImage.fromFile('missing.jpg'),
        timestampMilliseconds: 4,
      ),
      TaskException,
    );
    final recovery = video.detectForVideo(image, timestampMilliseconds: 5);
    await video.dispose();
    require(
      (await recovery).handLandmarks.isNotEmpty,
      'Dispose lost a pending hand result',
    );
  } finally {
    await video.dispose();
  }
  await rejects(
    () => HandLandmarker.create(
      HandLandmarkerOptions(modelBytes: Uint8List.fromList([1])),
    ),
    TaskException,
  );
  checks.add('hand-video-queue-failed-frame-recovery-invalid-model');
  return {
    'width': result.imageWidth,
    'height': result.imageHeight,
    'landmarks': [
      for (final hand in result.handLandmarks)
        for (final p in hand) [p.x, p.y, p.z],
    ],
    'world': [
      for (final hand in result.handWorldLandmarks)
        for (final p in hand) [p.x, p.y, p.z],
    ],
    'handedness': [for (final hand in result.handedness) hand.first.score],
  };
}

/// Pose, Gesture and Holistic through the public API on the official web
/// runtime. Each runs a fresh task once on its sample, as the browser suite
/// does with Google's JavaScript: Holistic's IMAGE mode keeps state between
/// calls, so only a first call is comparable.
Future<Map<String, Object?>> checkLandmarkTasksApi(
  Delegate delegate,
  List<String> checks,
) async {
  Future<Uint8List> model(String name) async {
    final data = await rootBundle.load(bundledModelFile(name));
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  VisionImage sample(String name) => VisionImage.fromFile(
    Uri.base.resolve('assets/assets/samples/$name').toString(),
  );

  /// Image or world landmarks, which share their fields.
  List<List<double>> points(List<Object> landmarks) => [
    for (final dynamic p in landmarks) <double>[p.x, p.y, p.z],
  ];
  final report = <String, Object?>{};

  final pose = await PoseLandmarker.create(
    PoseLandmarkerOptions(
      delegate: delegate,
      modelBytes: await model('pose_landmarker_lite.task'),
    ),
  );
  try {
    final result = await pose.detect(sample('pose.jpg'));
    require(
      result.poseLandmarks.length == 1 &&
          result.poseLandmarks.single.length == 33 &&
          result.poseWorldLandmarks.single.length == 33,
      'Expected one pose with 33 image and world landmarks',
    );
    report['pose'] = {
      'width': result.imageWidth,
      'height': result.imageHeight,
      'parts': {
        'landmarks': points(result.poseLandmarks.single),
        'world': points(result.poseWorldLandmarks.single),
      },
    };
  } finally {
    await pose.dispose();
  }

  final gesture = await GestureRecognizer.create(
    GestureRecognizerOptions(
      delegate: delegate,
      modelBytes: await model('gesture_recognizer.task'),
      numHands: 2,
    ),
  );
  try {
    final result = await gesture.recognize(sample('thumb_up.jpg'));
    require(
      result.gestures.length == 1 &&
          result.gestures.single.first.categoryName == 'Thumb_Up' &&
          result.gestures.single.every((g) => g.index == -1),
      'Expected one Thumb_Up gesture with index -1',
    );
    report['gesture'] = {
      'width': result.imageWidth,
      'height': result.imageHeight,
      'gesture': result.gestures.single.first.categoryName,
      'parts': {
        'landmarks': points(result.handLandmarks.single),
        'world': points(result.handWorldLandmarks.single),
        'gesture_score': [
          [result.gestures.single.first.score],
        ],
      },
    };
  } finally {
    await gesture.dispose();
  }

  final holistic = await HolisticLandmarker.create(
    HolisticLandmarkerOptions(
      delegate: delegate,
      modelBytes: await model('holistic_landmarker.task'),
    ),
  );
  try {
    final result = await holistic.detect(sample('pose.jpg'));
    require(
      result.poseLandmarks.length == 33 &&
          result.leftHandLandmarks.length == 21 &&
          result.rightHandLandmarks.length == 21,
      'Expected a holistic pose and both hands',
    );
    report['holistic'] = {
      'width': result.imageWidth,
      'height': result.imageHeight,
      'parts': {
        'pose': points(result.poseLandmarks),
        'pose_world': points(result.poseWorldLandmarks),
        'left_hand': points(result.leftHandLandmarks),
        'right_hand': points(result.rightHandLandmarks),
        'face': points(result.faceLandmarks),
      },
    };
  } finally {
    await holistic.dispose();
  }

  // VIDEO ordering through the shared adapter.
  final video = await PoseLandmarker.create(
    PoseLandmarkerOptions(
      delegate: delegate,
      modelBytes: await model('pose_landmarker_lite.task'),
      runningMode: RunningMode.video,
    ),
  );
  try {
    final frames = await Future.wait([
      for (var i = 0; i < 3; i++)
        video.detectForVideo(sample('pose.jpg'), timestampMilliseconds: i),
    ]);
    require(
      frames.map((r) => r.timestampMilliseconds).join(',') == '0,1,2' &&
          frames.every((r) => r.poseLandmarks.isNotEmpty),
      'Queued pose VIDEO failed',
    );
  } finally {
    await video.dispose();
  }
  await rejects(
    () => PoseLandmarker.create(
      PoseLandmarkerOptions(
        modelBytes: Uint8List.fromList([1]),
        delegate: delegate,
      ),
    ),
    TaskException,
  );
  checks.add('pose-gesture-holistic-image-video-invalid-model');
  return report;
}

/// Face Detector, Object Detector and Image Classifier through the public API
/// on the official web runtime, each on the portrait sample as the browser
/// suite runs Google's JavaScript. Boxes are reported as the Dart API holds
/// them: whole pixels.
Future<Map<String, Object?>> checkDetectionTasksApi(
  Delegate delegate,
  List<String> checks,
) async {
  Future<Uint8List> model(String name) async {
    final data = await rootBundle.load(bundledModelFile(name));
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  final portrait = VisionImage.fromFile(
    Uri.base.resolve('assets/assets/samples/portrait.jpg').toString(),
  );
  final report = <String, Object?>{};

  final faces = await FaceDetector.create(
    FaceDetectorOptions(
      delegate: delegate,
      modelBytes: await model('blaze_face_short_range.tflite'),
    ),
  );
  try {
    final result = await faces.detect(portrait);
    require(
      result.detections.length == 1 &&
          result.detections.single.keypoints.length == 6,
      'Expected one face with six keypoints',
    );
    report['face_detector'] = [
      for (final d in result.detections)
        {
          'box': [
            d.boundingBox.left,
            d.boundingBox.top,
            d.boundingBox.right,
            d.boundingBox.bottom,
          ],
          'score': d.categories.first.score,
          'name': d.categories.first.categoryName,
          'keypoints': [
            for (final k in d.keypoints) [k.x, k.y],
          ],
        },
    ];
  } finally {
    await faces.dispose();
  }

  final objects = await ObjectDetector.create(
    ObjectDetectorOptions(
      delegate: delegate,
      modelBytes: await model('efficientdet_lite0.tflite'),
      maxResults: 5,
      scoreThreshold: 0.3,
    ),
  );
  try {
    final result = await objects.detect(portrait);
    require(
      result.detections.isNotEmpty &&
          result.detections.first.categories.first.categoryName == 'person',
      'Expected a person first',
    );
    report['object_detector'] = [
      for (final d in result.detections)
        {
          'box': [
            d.boundingBox.left,
            d.boundingBox.top,
            d.boundingBox.right,
            d.boundingBox.bottom,
          ],
          'score': d.categories.first.score,
          'name': d.categories.first.categoryName,
        },
    ];
  } finally {
    await objects.dispose();
  }

  final classifier = await ImageClassifier.create(
    ImageClassifierOptions(
      delegate: delegate,
      modelBytes: await model('efficientnet_lite0.tflite'),
      maxResults: 3,
    ),
  );
  try {
    final result = await classifier.classify(portrait);
    final region = await classifier.classify(
      portrait,
      regionOfInterest: VisionRegionOfInterest(
        left: 0.25,
        top: 0.1,
        right: 0.75,
        bottom: 0.9,
      ),
    );
    require(
      result.classifications.single.categories.length == 3,
      'Expected the top three classes',
    );
    List<Map<String, Object?>> top(ImageClassifierResult r) => [
      for (final c in r.classifications.single.categories)
        {'score': c.score, 'name': c.categoryName},
    ];
    report['image_classifier'] = top(result);
    report['image_classifier_region'] = top(region);
  } finally {
    await classifier.dispose();
  }
  for (final quantize in [false, true]) {
    final embedder = await ImageEmbedder.create(
      ImageEmbedderOptions(
        delegate: delegate,
        modelBytes: await model('mobilenet_v3_small.tflite'),
        l2Normalize: quantize,
        quantize: quantize,
      ),
    );
    try {
      final embedding = (await embedder.embed(portrait)).embeddings.single;
      require(
        (embedding.floatEmbedding?.length ??
                embedding.quantizedEmbedding!.length) ==
            1024,
        'Expected a 1024-value embedding',
      );
      report[quantize ? 'image_embedder_quantized' : 'image_embedder'] = [
        {
          'values':
              embedding.floatEmbedding ??
              embedding.quantizedEmbedding!.toList(),
        },
      ];
    } finally {
      await embedder.dispose();
    }
  }
  final segmenter = await ImageSegmenter.create(
    ImageSegmenterOptions(
      delegate: delegate,
      modelBytes: await model('deeplab_v3.tflite'),
      outputCategoryMask: true,
    ),
  );
  try {
    final result = await segmenter.segment(portrait);
    require(
      result.labels.length == 21 &&
          result.labels.first == 'background' &&
          result.labels[15] == 'person',
      'Expected the DeepLab-v3 labels',
    );
    // The category and the person confidence at the centres of a 16 x 12
    // grid, as the official JavaScript side samples them.
    final category = result.categoryMask!;
    final person = result.confidenceMasks![15];
    final values = <num>[];
    for (var r = 0; r < 12; r++) {
      for (var c = 0; c < 16; c++) {
        final x = (2 * c + 1) * category.width ~/ 32;
        final y = (2 * r + 1) * category.height ~/ 24;
        values
          ..add(category.categories[y * category.width + x])
          ..add(person.confidence[y * category.width + x]);
      }
    }
    report['image_segmenter'] = [
      {'values': values},
    ];
  } finally {
    await segmenter.dispose();
  }
  // Stateful MagicTouch: Include, then Exclude with it, a lasso as an
  // outline and as its two opposite corners, and an unfinished stroke.
  // Multi-point strokes throughout, since Google's WebGL graph draws
  // nothing for a single point; the official JavaScript side sends the same.
  final magic = await InteractiveSegmenter.create(
    InteractiveSegmenterOptions(
      delegate: delegate,
      modelBytes: await model('interactive_segmentation.task'),
    ),
  );
  try {
    Stroke stroke(
      BrushMode mode,
      List<(double, double)> points, {
      bool done = true,
    }) => Stroke(
      brushMode: mode,
      points: [for (final (x, y) in points) NormalizedKeypoint(x: x, y: y)],
      isCompleted: done,
    );
    Future<Map<String, Object?>> sampled(List<Stroke> history) async {
      final mask = await magic.segment(history);
      return {
        'values': [
          for (var r = 0; r < 12; r++)
            for (var c = 0; c < 16; c++)
              mask.confidence[(2 * r + 1) * mask.height ~/ 24 * mask.width +
                  (2 * c + 1) * mask.width ~/ 32],
        ],
      };
    }

    await magic.setImage(portrait);
    final include = stroke(BrushMode.positive, [(0.5, 0.4), (0.5, 0.45)]);
    report['interactive_segmenter'] = [
      await sampled([include]),
      await sampled([
        include,
        stroke(BrushMode.negative, [(0.45, 0.8), (0.55, 0.8)]),
      ]),
      await sampled([
        stroke(BrushMode.lasso, [
          (0.25, 0.1),
          (0.75, 0.1),
          (0.75, 0.9),
          (0.25, 0.9),
        ]),
      ]),
      await sampled([
        stroke(BrushMode.lasso, [(0.25, 0.1), (0.75, 0.9)]),
      ]),
      await sampled([
        stroke(BrushMode.positive, [(0.5, 0.4), (0.5, 0.45)], done: false),
      ]),
    ];
  } finally {
    await magic.dispose();
  }
  // Pose segmentation masks from pose.jpg, sampled on the same grid.
  List<double> sampled(ConfidenceMask mask) => [
    for (var r = 0; r < 12; r++)
      for (var c = 0; c < 16; c++)
        mask.confidence[(2 * r + 1) * mask.height ~/ 24 * mask.width +
            (2 * c + 1) * mask.width ~/ 32],
  ];
  final figure = VisionImage.fromFile(
    Uri.base.resolve('assets/assets/samples/pose.jpg').toString(),
  );
  final pose = await PoseLandmarker.create(
    PoseLandmarkerOptions(
      delegate: delegate,
      modelBytes: await model('pose_landmarker_lite.task'),
      outputSegmentationMasks: true,
    ),
  );
  try {
    final masks = (await pose.detect(figure)).segmentationMasks!;
    report['pose_mask'] = [
      {'values': sampled(masks.single)},
    ];
  } finally {
    await pose.dispose();
  }
  // A fresh task: Holistic's IMAGE results depend on earlier calls (UP-013).
  final holistic = await HolisticLandmarker.create(
    HolisticLandmarkerOptions(
      delegate: delegate,
      modelBytes: await model('holistic_landmarker.task'),
      outputPoseSegmentationMask: true,
    ),
  );
  try {
    final mask = (await holistic.detect(figure)).poseSegmentationMask!;
    report['holistic_mask'] = [
      {'values': sampled(mask)},
    ];
  } finally {
    await holistic.dispose();
  }
  checks.add(
    'face-object-detector-image-classifier-region-embedder-segmenter-pose-masks',
  );
  return report;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Map<String, Object?> report;
  try {
    report = await checkApi();
  } catch (error, stack) {
    report = {'status': 'failed', 'error': '$error', 'stack': '$stack'};
  }
  _report = report.jsify()! as JSObject;
  runApp(
    MaterialApp(
      home: Scaffold(
        body: Center(child: Text('API checks: ${report['status']}')),
      ),
    ),
  );
}
