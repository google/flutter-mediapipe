@TestOn('browser')
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mediapipe_vision/platform_interface.dart';

void main() {
  test(
    'copies optional landmark fields, categories and column-major matrix',
    () {
      final values = List<num>.generate(16, (i) => i);
      final data = <String, dynamic>{
        'width': 640,
        'height': 480,
        'timestamp': 123,
        'result': {
          'faceLandmarks': [
            [
              {'x': -0.1, 'y': 1.2, 'z': 0, 'visibility': 0.7},
            ],
          ],
          'faceBlendshapes': [
            {
              'categories': [
                {
                  'index': 2,
                  'score': 0.5,
                  'categoryName': 'jawOpen',
                  'displayName': '',
                },
              ],
            },
          ],
          'facialTransformationMatrixes': [
            {'rows': 4, 'columns': 4, 'data': values},
          ],
        },
      };
      final result = decodeFaceLandmarkerResult(_data(data));
      values[4] = 99;
      expect(result.imageWidth, 640);
      expect(result.timestampMilliseconds, 123);
      expect(result.faceLandmarks.single.single.x, -0.1);
      expect(result.faceLandmarks.single.single.presence, isNull);
      expect(result.faceBlendshapes.single.single.categoryName, 'jawOpen');
      expect(result.facialTransformationMatrixes.single.at(0, 1), 4);
      expect(() => result.faceLandmarks.clear(), throwsUnsupportedError);
    },
  );

  test('reads packed landmarks per face, NaN as absent', () {
    final result = decodeFaceLandmarkerResult(
      _data(
        {
          'width': 640,
          'height': 480,
          'timestamp': 7,
          'counts': [1, 2],
          'result': {
            'faceLandmarks': <Object?>[],
            'faceBlendshapes': <Object?>[],
            'facialTransformationMatrixes': <Object?>[],
          },
        },
        landmarks: Float64List.fromList([
          0.1, 0.2, 0.3, double.nan, double.nan, //
          0.4, 0.5, -0.6, 0.9, 0.8, //
          0.7, 0.8, 0.9, 0, double.nan,
        ]),
      ),
    );
    expect(result.faceLandmarks.map((face) => face.length), [1, 2]);
    final first = result.faceLandmarks.first.single;
    expect([first.x, first.y, first.z], [0.1, 0.2, 0.3]);
    expect(first.visibility, isNull);
    expect(first.presence, isNull);
    final second = result.faceLandmarks.last.first;
    expect([second.z, second.visibility, second.presence], [-0.6, 0.9, 0.8]);
    expect(result.faceLandmarks.last.last.visibility, 0);
  });

  test('reads hand landmarks packed, world landmarks and handedness', () {
    final result = decodeHandLandmarkerResult(
      _data(
        {
          'width': 320,
          'height': 240,
          'timestamp': 9,
          'counts': [2],
          'result': {
            'landmarks': <Object?>[],
            'worldLandmarks': [
              [
                {'x': 0.01, 'y': -0.02, 'z': 0.03},
                {'x': 0.04, 'y': 0.05, 'z': -0.06, 'visibility': 0.5},
              ],
            ],
            'handedness': [
              [
                {
                  'index': 1,
                  'score': 0.97,
                  'categoryName': 'Right',
                  'displayName': 'Right',
                },
              ],
            ],
          },
        },
        landmarks: Float64List.fromList([
          0.1, 0.2, 0.3, double.nan, double.nan, //
          0.4, 0.5, -0.6, 0, 0.8,
        ]),
      ),
    );
    expect(result.imageWidth, 320);
    expect(result.timestampMilliseconds, 9);
    expect(result.handLandmarks.single.map((p) => p.x), [0.1, 0.4]);
    expect(result.handLandmarks.single.first.visibility, isNull);
    expect(result.handLandmarks.single.last.visibility, 0);
    expect(result.handWorldLandmarks.single.last.z, -0.06);
    expect(result.handWorldLandmarks.single.last.visibility, 0.5);
    expect(result.handWorldLandmarks.single.first.presence, isNull);
    final side = result.handedness.single.single;
    expect([side.index, side.score, side.categoryName], [1, 0.97, 'Right']);
  });

  test(
    'reads hand landmarks from JSON when the worker could not pack them',
    () {
      final result = decodeHandLandmarkerResult(
        _data({
          'width': 1,
          'height': 1,
          'timestamp': null,
          'result': {
            'landmarks': [
              [
                {'x': 0.5, 'y': 0.25, 'z': 0, 'name': 'wrist'},
              ],
            ],
            'worldLandmarks': [<Object?>[]],
            'handedness': [<Object?>[]],
          },
        }),
      );
      expect(result.timestampMilliseconds, isNull);
      expect(result.handLandmarks.single.single.name, 'wrist');
      expect(result.handLandmarks.single.single.y, 0.25);
      expect(() => result.handLandmarks.clear(), throwsUnsupportedError);
    },
  );

  test('reads pose landmarks packed and world landmarks from JSON', () {
    final result = decodePoseLandmarkerResult(
      _data({
        'width': 64,
        'height': 48,
        'timestamp': 3,
        'counts': [1],
        'result': {
          'landmarks': <Object?>[],
          'worldLandmarks': [
            [
              {'x': -0.1, 'y': 0.2, 'z': 0.3, 'visibility': 0.9},
            ],
          ],
        },
      }, landmarks: Float64List.fromList([0.5, 0.6, -0.1, 0.99, 0.98])),
    );
    expect(result.imageHeight, 48);
    expect(result.timestampMilliseconds, 3);
    final point = result.poseLandmarks.single.single;
    expect([point.x, point.visibility, point.presence], [0.5, 0.99, 0.98]);
    expect(result.poseWorldLandmarks.single.single.visibility, 0.9);
    expect(result.segmentationMasks, isNull);
  });

  test('reads gestures with index -1, handedness and hand landmarks', () {
    final result = decodeGestureRecognizerResult(
      _data(
        {
          'width': 10,
          'height': 20,
          'timestamp': null,
          'counts': [1],
          'result': {
            'landmarks': <Object?>[],
            'worldLandmarks': [
              [
                {'x': 0, 'y': 0, 'z': 0},
              ],
            ],
            'handedness': [
              [
                {'index': 0, 'score': 0.9, 'categoryName': 'Left'},
              ],
            ],
            'gestures': [
              [
                {'index': 5, 'score': 0.74, 'categoryName': 'Thumb_Up'},
                {'index': 0, 'score': 0.1, 'categoryName': 'None'},
              ],
            ],
          },
        },
        landmarks: Float64List.fromList([
          0.1,
          0.2,
          0.3,
          double.nan,
          double.nan,
        ]),
      ),
    );
    expect(result.handLandmarks.single.single.y, 0.2);
    expect(result.handedness.single.single.categoryName, 'Left');
    expect(result.gestures.single.map((g) => g.categoryName), [
      'Thumb_Up',
      'None',
    ]);
    // Canned and custom indices are merged, as in the native bindings.
    expect(result.gestures.single.map((g) => g.index), [-1, -1]);
  });

  test('reads one holistic subject per part, empty where absent', () {
    Map<String, Object?> point(double x) => {'x': x, 'y': x, 'z': 0};
    final result = decodeHolisticLandmarkerResult(
      _data({
        'width': 8,
        'height': 6,
        'timestamp': 12,
        'result': {
          'faceLandmarks': <Object?>[],
          'faceBlendshapes': [
            {
              'categories': [
                {'index': 1, 'score': 0.25, 'categoryName': 'blink'},
              ],
            },
          ],
          'poseLandmarks': [
            [point(0.1), point(0.2)],
          ],
          'poseWorldLandmarks': [
            [point(1)],
          ],
          'leftHandLandmarks': [
            [point(0.3)],
          ],
          'leftHandWorldLandmarks': [
            [point(2)],
          ],
          'rightHandLandmarks': <Object?>[],
          'rightHandWorldLandmarks': <Object?>[],
        },
      }),
    );
    expect(result.timestampMilliseconds, 12);
    expect(result.faceLandmarks, isEmpty);
    expect(result.poseLandmarks.map((p) => p.x), [0.1, 0.2]);
    expect(result.poseWorldLandmarks.single.x, 1);
    expect(result.leftHandLandmarks.single.x, 0.3);
    expect(result.leftHandWorldLandmarks.single.x, 2);
    expect(result.rightHandLandmarks, isEmpty);
    expect(result.faceBlendshapes!.single.categoryName, 'blink');
    expect(result.poseSegmentationMask, isNull);
  });

  test('reads packed holistic parts as the JSON ones', () {
    // The worker's packParts: every part in one buffer, in `parts` order.
    List<double> point(double x) => [x, x, 0, double.nan, 0.5];
    final result = decodeHolisticLandmarkerResult(
      _data(
        {
          'width': 8,
          'height': 6,
          'timestamp': 12,
          'parts': [
            ['faceLandmarks', <Object?>[]],
            [
              'poseLandmarks',
              [2],
            ],
            [
              'poseWorldLandmarks',
              [1],
            ],
            [
              'leftHandLandmarks',
              [1],
            ],
            [
              'leftHandWorldLandmarks',
              [1],
            ],
            ['rightHandLandmarks', <Object?>[]],
            ['rightHandWorldLandmarks', <Object?>[]],
          ],
          'result': {
            for (final part in [
              'faceLandmarks',
              'poseLandmarks',
              'poseWorldLandmarks',
              'leftHandLandmarks',
              'leftHandWorldLandmarks',
              'rightHandLandmarks',
              'rightHandWorldLandmarks',
            ])
              part: <Object?>[],
            'faceBlendshapes': <Object?>[],
          },
        },
        landmarks: Float64List.fromList([
          ...point(0.1),
          ...point(0.2),
          ...point(1),
          ...point(0.3),
          ...point(2),
        ]),
      ),
    );
    expect(result.faceLandmarks, isEmpty);
    expect(result.poseLandmarks.map((p) => p.x), [0.1, 0.2]);
    expect(result.poseLandmarks.first.visibility, isNull);
    expect(result.poseLandmarks.first.presence, 0.5);
    expect(result.poseWorldLandmarks.single.x, 1);
    expect(result.leftHandLandmarks.single.x, 0.3);
    expect(result.leftHandWorldLandmarks.single.x, 2);
    expect(result.rightHandLandmarks, isEmpty);
    expect(result.rightHandWorldLandmarks, isEmpty);
    expect(result.faceBlendshapes, isNull);
  });

  test('reads face detections: truncated boxes, keypoints, absent labels', () {
    final result = decodeFaceDetectorResult(
      _data({
        'width': 100,
        'height': 80,
        'timestamp': null,
        'result': {
          'detections': [
            {
              'categories': [
                {
                  'index': 0,
                  'score': 0.8,
                  'categoryName': '',
                  'displayName': '',
                },
              ],
              'boundingBox': {
                'originX': 10.9,
                'originY': 5.2,
                'width': 20.5,
                'height': 30.0,
                'angle': 0,
              },
              'keypoints': [
                {'x': 0.25, 'y': 0.5, 'score': 0.9},
              ],
            },
          ],
        },
      }),
    );
    final face = result.detections.single;
    final box = face.boundingBox;
    expect([box.left, box.top, box.right, box.bottom], [10, 5, 31, 35]);
    expect(face.categories.single.categoryName, isNull);
    expect(face.categories.single.displayName, isNull);
    expect([face.keypoints.single.x, face.keypoints.single.score], [0.25, 0.9]);
    expect(face.keypoints.single.label, isNull);
  });

  test('reads object detections, an absent index as -1', () {
    final result = decodeObjectDetectorResult(
      _data({
        'width': 10,
        'height': 10,
        'timestamp': 7,
        'result': {
          'detections': [
            {
              'categories': [
                {'score': 0.6, 'categoryName': 'person'},
              ],
              'boundingBox': {
                'originX': 1,
                'originY': 2,
                'width': 3,
                'height': 4,
                'angle': 0,
              },
              'keypoints': <Object?>[],
            },
          ],
        },
      }),
    );
    expect(result.timestampMilliseconds, 7);
    final category = result.detections.single.categories.single;
    expect([category.index, category.categoryName], [-1, 'person']);
    expect(result.detections.single.boundingBox.bottom, 6);
  });

  test('reads classification heads with their index and name', () {
    final result = decodeImageClassifierResult(
      _data({
        'width': 4,
        'height': 3,
        'timestamp': null,
        'result': {
          'classifications': [
            {
              'categories': [
                {'index': 490, 'score': 0.3, 'categoryName': 'chain mail'},
              ],
              'headIndex': 0,
              'headName': 'probability',
            },
          ],
        },
      }),
    );
    final head = result.classifications.single;
    expect([head.headIndex, head.headName], [0, 'probability']);
    expect(head.categories.single.index, 490);
  });

  test('reads float and quantized embeddings per head', () {
    final floats = decodeImageEmbedderResult(
      _data({
        'width': 2,
        'height': 2,
        'timestamp': 5,
        'result': {
          'embeddings': [
            {
              'floatEmbedding': [0.5, -0.25],
              'headIndex': 0,
              'headName': '',
            },
          ],
        },
      }),
    );
    final head = floats.embeddings.single;
    expect(head.floatEmbedding, [0.5, -0.25]);
    expect(head.quantizedEmbedding, isNull);
    expect(head.headName, isNull);
    final bytes = decodeImageEmbedderResult(
      _data({
        'width': 2,
        'height': 2,
        'timestamp': null,
        'result': {
          'embeddings': [
            {
              'quantizedEmbedding': [255, 1],
              'headIndex': 1,
              'headName': 'features',
            },
          ],
        },
      }),
    );
    expect(bytes.embeddings.single.quantizedEmbedding, [255, 1]);
    expect(bytes.embeddings.single.headName, 'features');
  });

  test('reads transferred masks, labels and quality scores', () {
    final result = <String, dynamic>{
      'confidenceMasks': [
        [2, 1, 4, 0],
      ],
      'categoryMask': [2, 1, 1, 1],
      'qualityScores': [1],
      'labels': ['background', 'person'],
    };
    attachMaskBuffers(result, [
      Float32List.fromList([0.25, 0.75]).buffer,
      Uint8List.fromList([0, 1]).buffer,
    ]);
    final decoded = decodeImageSegmenterResult(
      _data({'width': 2, 'height': 1, 'timestamp': 7, 'result': result}),
    );
    expect(decoded.confidenceMasks!.single.confidence, [0.25, 0.75]);
    expect(decoded.categoryMask!.categories, [0, 1]);
    expect(decoded.qualityScores, [1]);
    expect(decoded.labels, ['background', 'person']);
    expect(decoded.timestampMilliseconds, 7);
    expect(
      () => attachMaskBuffers(
        {
          'categoryMask': [3, 1, 1, 0],
        },
        [Uint8List(2).buffer],
      ),
      throwsStateError,
    );
  });

  test('rejects packed landmarks that do not match their counts', () {
    expect(
      () => decodeHandLandmarkerResult(
        _data({
          'width': 1,
          'height': 1,
          'counts': [2],
          'result': {
            'landmarks': <Object?>[],
            'worldLandmarks': <Object?>[],
            'handedness': <Object?>[],
          },
        }, landmarks: Float64List(5)),
      ),
      throwsFormatException,
    );
  });
}

/// The worker's reply as the browser adapter hands it to the decoder.
VisionResultData _data(Map<String, dynamic> data, {Float64List? landmarks}) =>
    VisionResultData.fromBrowser(data, landmarks: landmarks);
