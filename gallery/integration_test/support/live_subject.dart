import 'dart:typed_data';

import 'package:mediapipe_vision/mediapipe_vision.dart';
import 'package:mediapipe_gallery/live/live_subjects.dart';

/// The live demo a camera test drives, and what it should find.
///
/// Chosen with `--dart-define=GALLERY_LIVE_TASK=face|hand` (face by default),
/// so every camera test runs unchanged against each task.
final class LiveSubject {
  const LiveSubject._({
    required this.task,
    required this.tile,
    required this.model,
    required this.sample,
    required this.points,
    required this.probes,
    required this.detectImage,
  });

  /// `face` or `hand`, as in `GALLERY_LIVE_TASK`.
  final String task;

  /// The gallery tile that opens the demo.
  final String tile;

  /// The pinned model the demo runs.
  final DownloadAsset model;

  /// Bundled sample with exactly one subject, used for supplied frames.
  final String sample;

  /// Landmarks per subject.
  final int points;

  /// Landmarks the alignment oracle compares.
  final AlignmentProbes probes;

  /// Runs the official IMAGE task over RGBA pixels: each subject's landmarks.
  final Future<List<List<LivePoint>>> Function(
    Uint8List model,
    Uint8List rgba,
    int width,
    int height,
  )
  detectImage;

  static final face = LiveSubject._(
    task: 'face',
    tile: 'Face Landmarker',
    model: VisionModels.faceLandmarker,
    sample: 'portrait.jpg',
    points: 478,
    probes: AlignmentProbes.face,
    detectImage: (model, rgba, width, height) async {
      final task = await FaceLandmarker.create(
        FaceLandmarkerOptions(modelBytes: model, numFaces: 1),
      );
      try {
        return liveSubjects(await task.detect(_image(rgba, width, height)));
      } finally {
        await task.dispose();
      }
    },
  );

  static final hand = LiveSubject._(
    task: 'hand',
    tile: 'Hand Landmarker',
    model: VisionModels.handLandmarker,
    sample: 'thumb_up.jpg',
    points: 21,
    probes: AlignmentProbes.hand,
    detectImage: (model, rgba, width, height) async {
      final task = await HandLandmarker.create(
        HandLandmarkerOptions(modelBytes: model, numHands: 2),
      );
      try {
        return liveSubjects(await task.detect(_image(rgba, width, height)));
      } finally {
        await task.dispose();
      }
    },
  );

  /// The demo selected for this run.
  static final selected = switch (const String.fromEnvironment(
    'GALLERY_LIVE_TASK',
    defaultValue: 'face',
  )) {
    'face' => face,
    'hand' => hand,
    final other => throw ArgumentError.value(
      other,
      'GALLERY_LIVE_TASK',
      'Expected face or hand',
    ),
  };
}

VisionImage _image(Uint8List rgba, int width, int height) =>
    VisionImage.fromPixels(
      pixels: rgba,
      width: width,
      height: height,
      format: VisionPixelFormat.rgba,
    );
