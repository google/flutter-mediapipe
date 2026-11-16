import 'package:flutter_test/flutter_test.dart';
import 'package:mediapipe_gallery/catalog.dart';
import 'package:mediapipe_gallery/main.dart' show compareTasks;
import 'package:mediapipe_vision/mediapipe_vision.dart';

const _macos = TaskPlatform(
  operatingSystem: 'macos',
  architecture: 'arm64',
  version: '15.0',
);

/// Google's MediaPipe Solutions guide,
/// https://developers.google.com/edge/mediapipe/solutions, as it lists its
/// categories and their tasks.
const _guide = {
  'Audio': ['Audio Classifier', 'Audio Transcriber', 'Text-to-Speech'],
  'Decision': ['Decision Maker'],
  'Retrieval': ['Semantic Retriever', 'Universal Embedder'],
  'Text': [
    'Language Detector',
    'Text Classifier',
    'Text Embedder',
    'Text Proofreader',
    'Text Summarizer',
  ],
  'Vision': [
    'Face Detector',
    'Face Landmarker',
    'Gesture Recognizer',
    'Hand Landmarker',
    'Holistic Landmarker',
    'Image Classifier',
    'Image Embedder',
    'Image Segmenter',
    'Interactive Segmenter',
    'Object Detector',
    'Pose Landmarker',
  ],
};

/// The gallery's own demos, which the guide does not list.
const _galleryOnly = {'Hungry Fish'};

void main() {
  test('the sections follow the guide', () {
    expect(GalleryCategory.values.map((c) => c.title), _guide.keys);
  });

  test('each section lists its tasks as the guide does', () {
    final bundled = {
      for (final task in plannedTasks) task.runtimeId,
      for (final title in _guide['Vision']!)
        title.toLowerCase().replaceAll(' ', '_'),
    };
    final tasks = supportedTasks(_macos, bundled)
      ..sort(
        (a, b) => compareTasks(
          (runtimeId: a.runtimeId, title: a.title),
          (runtimeId: b.runtimeId, title: b.title),
        ),
      );
    for (final category in GalleryCategory.values) {
      expect(
        [
          for (final task in tasks)
            if (task.hasOwnPage &&
                task.category == category &&
                !_galleryOnly.contains(task.title))
              task.title,
        ],
        _guide[category.title],
        reason: category.title,
      );
    }
  });
}
