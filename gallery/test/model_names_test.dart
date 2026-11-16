import 'package:flutter_test/flutter_test.dart';
import 'package:mediapipe_gallery/live/task_models.dart';

/// The models each task's guide lists, by the names it gives them, under
/// `https://developers.google.com/edge/mediapipe/solutions/<family>/<task>`.
const _guide = <String, List<String>>{
  'decision_fish_game': _decisionModels,
  'decision_maker': _decisionModels,
  'face_detector': [
    'BlazeFace (short-range)',
    'BlazeFace (full-range)',
    'BlazeFace Sparse (full-range)',
  ],
  'image_classifier': [
    'EfficientNet-Lite0 (int8)',
    'EfficientNet-Lite0 (float 32)',
    'EfficientNet-Lite2 (int8)',
    'EfficientNet-Lite2 (float 32)',
  ],
  'image_embedder': ['MobileNet-V3 (small)', 'MobileNet-V3 (large)'],
  'image_segmenter': [
    'SelfieSegmenter (square)',
    'SelfieSegmenter (landscape)',
    'HairSegmenter',
    'SelfieMulticlass (256 x 256)',
    'DeepLab-V3',
  ],
  'object_detector': [
    'EfficientDet-Lite0 (int8)',
    'EfficientDet-Lite0 (float 16)',
    'EfficientDet-Lite0 (float 32)',
    'EfficientDet-Lite2 (int8)',
    'EfficientDet-Lite2 (float 16)',
    'EfficientDet-Lite2 (float 32)',
    'SSDMobileNet-V2 (float 16)',
    'SSDMobileNet-V2 (float 32)',
  ],
  'pose_landmarker': [
    'Pose Landmarker (lite)',
    'Pose Landmarker (full)',
    'Pose Landmarker (heavy)',
  ],
  'text_classifier': ['BERT-classifier', 'Average word embedding'],
  'text_embedder': ['EmbeddingGemma 300M', 'Universal Sentence Encoder'],
};

const _decisionModels = [
  'EmbeddingGemma 2 Text (270M)',
  'EmbeddingGemma 2 Text / Vision (440M)',
  'EmbeddingGemma 2 Text / Vision / Audio (740M)',
  'EmbeddingGemma 300M',
  'Gemma 4 E2B',
  'Gemma 4 E4B',
  'Laya (256-token)',
  'Laya (512-token)',
  'GLiNER2.5-Decide (256-token)',
  'GLiNER2.5-Decide (512-token)',
];

void main() {
  test('every model menu names its models as the guide does', () {
    for (final MapEntry(key: task, value: models) in taskModels.entries) {
      final guide = _guide[task];
      expect(guide, isNotNull, reason: task);
      for (final model in models) {
        expect(guide, contains(model.name), reason: task);
      }
    }
  });

  test('the bundled model is named, as the guide names it, beside the '
      'others', () {
    for (final task in taskModels.keys) {
      // Decision Maker and Hungry Fish name theirs on their pages.
      if (task.startsWith('decision_')) continue;
      expect(_guide[task], contains(standardModelNames[task]), reason: task);
    }
    for (final MapEntry(key: task, value: name) in standardModelNames.entries) {
      expect(_guide[task], contains(name), reason: task);
    }
  });
}
