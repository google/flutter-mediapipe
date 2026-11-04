import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';
import 'package:mediapipe_vision/src/io/native_face_detector.dart';
import 'package:mediapipe_vision/src/io/native_gesture_recognizer.dart';
import 'package:mediapipe_vision/src/io/native_hand_landmarker.dart';
import 'package:mediapipe_vision/src/io/native_holistic_landmarker.dart';
import 'package:mediapipe_vision/src/third_party/mediapipe/vision_bindings.dart'
    as mp;
import 'package:test/test.dart';

// Every option, set to a value of its own, reaches its field of Google's C
// options: a forgotten or swapped field fails here instead of silently
// running the default. Google's struct holds floats, hence the tolerance.
final _model = Uint8List.fromList([1, 2, 3]);

Matcher _float(double value) => closeTo(value, 1e-6);

List<String> _strings(Pointer<Pointer<Char>> list, int count) => [
  for (var i = 0; i < count; i++) list[i].cast<Utf8>().toDartString(),
];

void _expectClassifier(
  mp.MpClassifierOptions native, {
  required int maxResults,
  required double scoreThreshold,
  required String locale,
  required List<String> allowlist,
  required List<String> denylist,
}) {
  expect(native.max_results, maxResults);
  expect(native.score_threshold, _float(scoreThreshold));
  expect(native.display_names_locale.cast<Utf8>().toDartString(), locale);
  expect(
    _strings(native.category_allowlist, native.category_allowlist_count),
    allowlist,
  );
  expect(
    _strings(native.category_denylist, native.category_denylist_count),
    denylist,
  );
}

void main() {
  test('Face Detector passes every option', () {
    using((arena) {
      final native = arena<mp.MpFaceDetectorOptions>();
      fillFaceDetectorOptions(
        arena,
        native.ref,
        FaceDetectorOptions(
          modelBytes: _model,
          runningMode: RunningMode.video,
          minDetectionConfidence: .11,
          minSuppressionThreshold: .12,
        ),
      );
      expect(native.ref.running_mode, mp.MpRunningMode.MP_RUNNING_MODE_VIDEO);
      expect(native.ref.min_detection_confidence, _float(.11));
      expect(native.ref.min_suppression_threshold, _float(.12));
    });
  });

  test('Hand Landmarker passes every option', () {
    using((arena) {
      final native = arena<mp.MpHandLandmarkerOptions>();
      fillHandLandmarkerOptions(
        arena,
        native.ref,
        HandLandmarkerOptions(
          modelBytes: _model,
          runningMode: RunningMode.video,
          numHands: 3,
          minHandDetectionConfidence: .21,
          minHandPresenceConfidence: .22,
          minTrackingConfidence: .23,
        ),
      );
      expect(native.ref.running_mode, mp.MpRunningMode.MP_RUNNING_MODE_VIDEO);
      expect(native.ref.num_hands, 3);
      expect(native.ref.min_hand_detection_confidence, _float(.21));
      expect(native.ref.min_hand_presence_confidence, _float(.22));
      expect(native.ref.min_tracking_confidence, _float(.23));
    });
  });

  test('Gesture Recognizer passes every option, both classifiers too', () {
    using((arena) {
      final native = arena<mp.MpGestureRecognizerOptions>();
      fillGestureRecognizerOptions(
        arena,
        native.ref,
        GestureRecognizerOptions(
          modelBytes: _model,
          runningMode: RunningMode.video,
          numHands: 4,
          minHandDetectionConfidence: .31,
          minHandPresenceConfidence: .32,
          minTrackingConfidence: .33,
          cannedGesturesClassifierOptions: ClassifierOptions(
            maxResults: 2,
            scoreThreshold: .34,
            displayNamesLocale: 'en',
            categoryAllowlist: ['Thumb_Up', 'Victory'],
          ),
          customGesturesClassifierOptions: ClassifierOptions(
            maxResults: 5,
            scoreThreshold: .35,
            displayNamesLocale: 'fr',
            categoryDenylist: ['None'],
          ),
        ),
      );
      expect(native.ref.running_mode, mp.MpRunningMode.MP_RUNNING_MODE_VIDEO);
      expect(native.ref.num_hands, 4);
      expect(native.ref.min_hand_detection_confidence, _float(.31));
      expect(native.ref.min_hand_presence_confidence, _float(.32));
      expect(native.ref.min_tracking_confidence, _float(.33));
      _expectClassifier(
        native.ref.canned_gestures_classifier_options,
        maxResults: 2,
        scoreThreshold: .34,
        locale: 'en',
        allowlist: ['Thumb_Up', 'Victory'],
        denylist: [],
      );
      _expectClassifier(
        native.ref.custom_gestures_classifier_options,
        maxResults: 5,
        scoreThreshold: .35,
        locale: 'fr',
        allowlist: [],
        denylist: ['None'],
      );
    });
  });

  test('Holistic Landmarker passes every option', () {
    using((arena) {
      final native = arena<mp.MpHolisticLandmarkerOptions>();
      fillHolisticLandmarkerOptions(
        arena,
        native.ref,
        HolisticLandmarkerOptions(
          modelBytes: _model,
          runningMode: RunningMode.video,
          minFaceDetectionConfidence: .41,
          minFaceSuppressionThreshold: .42,
          minFacePresenceConfidence: .43,
          minHandLandmarksConfidence: .44,
          minPoseDetectionConfidence: .45,
          minPoseSuppressionThreshold: .46,
          minPosePresenceConfidence: .47,
          outputFaceBlendshapes: true,
          outputPoseSegmentationMask: true,
        ),
      );
      final options = native.ref;
      expect(options.running_mode, mp.MpRunningMode.MP_RUNNING_MODE_VIDEO);
      expect(options.min_face_detection_confidence, _float(.41));
      expect(options.min_face_suppression_threshold, _float(.42));
      expect(options.min_face_presence_confidence, _float(.43));
      expect(options.min_hand_landmarks_confidence, _float(.44));
      expect(options.min_pose_detection_confidence, _float(.45));
      expect(options.min_pose_suppression_threshold, _float(.46));
      expect(options.min_pose_presence_confidence, _float(.47));
      expect(options.output_face_blendshapes, isTrue);
      expect(options.output_pose_segmentation_masks, isTrue);
    });
  });
}
