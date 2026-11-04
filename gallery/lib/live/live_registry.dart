import 'package:flutter/material.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';

import 'camera_geometry.dart';
import 'detection_overlay.dart';
import 'face_overlay.dart';
import 'landmark_overlay.dart';
import 'live_camera_controller.dart';
import 'live_tasks.dart';

/// The two things a live tile contributes beyond the shared controller.
///
/// The painter is handed the [PreviewTransform] rather than computing its own,
/// so no demo can disagree with the preview about where a landmark belongs.
typedef LiveDemo = ({
  LiveTask<Object?> Function() task,
  CustomPainter Function(
    Object? result,
    PreviewTransform transform,
    bool edges,
    bool points,
  )
  overlay,
});

/// Keyed by catalog tile id.
final _demos = <String, LiveDemo>{
  'face_landmarker_live': (
    task: FaceLandmarkerLiveTask.new,
    overlay: _faceOverlay,
  ),
  'hand_landmarker_live': (
    task: HandLandmarkerLiveTask.new,
    overlay: _landmarkOverlay,
  ),
  'pose_landmarker_live': (
    task: PoseLandmarkerLiveTask.new,
    overlay: _landmarkOverlay,
  ),
  'gesture_recognizer_live': (
    task: GestureRecognizerLiveTask.new,
    overlay: _landmarkOverlay,
  ),
  'holistic_landmarker_live': (
    task: HolisticLandmarkerLiveTask.new,
    overlay: _landmarkOverlay,
  ),
  'face_detector_live': (
    task: FaceDetectorLiveTask.new,
    overlay: _landmarkOverlay,
  ),
  'object_detector_live': (
    task: ObjectDetectorLiveTask.new,
    overlay: _landmarkOverlay,
  ),
  'image_classifier_live': (
    task: ImageClassifierLiveTask.new,
    overlay: _landmarkOverlay,
  ),
  'image_segmenter_live': (
    task: ImageSegmenterLiveTask.new,
    overlay: _landmarkOverlay,
  ),
};

LiveDemo? liveDemoFor(String id) => _demos[id];

// Face landmarks have their own painter: 478 points with connections, contours and
// irises, rather than one skeleton of official edges.
CustomPainter _faceOverlay(
  Object? result,
  PreviewTransform transform,
  bool edges,
  bool points,
) => FaceOverlay(
  result as FaceLandmarkerResult?,
  transform: transform,
  showConnections: edges,
  showPoints: points,
);

// Detectors and classifiers draw boxes and labels; every other task draws its
// landmarks. The edges switch shows or hides boxes. The Image Segmenter's mask
// is drawn by the page, which builds its image as results arrive.
CustomPainter _landmarkOverlay(
  Object? result,
  PreviewTransform transform,
  bool edges,
  bool points,
) =>
    detectionOverlayFor(result, transform, boxes: edges, points: points) ??
    LandmarkOverlay(
      figuresFor(result),
      transform: transform,
      showEdges: edges,
      showPoints: points,
    );
