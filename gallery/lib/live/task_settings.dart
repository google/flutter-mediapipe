/// The settings a live demo exposes, as MediaPipe Studio shows them for the
/// same task. Each key is the option's name in the task's Dart options class,
/// and each default is the value the gallery used before settings existed.
sealed class TaskSetting {
  const TaskSetting(this.key, this.label, {this.display = false});

  /// The options field this setting sets, or a name of the gallery's own
  /// for a [display] setting.
  final String key;

  /// The label Studio uses for it.
  final String label;

  /// Whether the setting only changes how results are drawn, so changing it
  /// redraws the overlay without rebuilding the task.
  final bool display;

  Object get initial;
}

/// A whole number within [min] and [max], such as Num Faces.
final class CountSetting extends TaskSetting {
  const CountSetting(
    super.key,
    super.label, {
    required this.initial,
    this.min = 1,
    this.max = 10,
  });

  @override
  final int initial;
  final int min;
  final int max;
}

/// A value between 0 and 1, such as a confidence or a score threshold.
final class ShareSetting extends TaskSetting {
  const ShareSetting(
    super.key,
    super.label, {
    this.initial = 0.5,
    super.display,
  });

  @override
  final double initial;
}

/// An on/off option, such as Output Segmentation Masks.
final class SwitchSetting extends TaskSetting {
  const SwitchSetting(super.key, super.label, {this.initial = false});

  @override
  final bool initial;
}

/// One of a fixed list of [options], stored as the chosen index, such as
/// Image Segmenter's Output Type.
final class ChoiceSetting extends TaskSetting {
  const ChoiceSetting(
    super.key,
    super.label, {
    required this.options,
    this.initial = 0,
  });

  final List<String> options;

  @override
  final int initial;
}

/// One of the running model's labels, stored as its index, shown only while
/// the setting [whenKey] has the value [whenValue]. Always a display setting.
final class LabelSetting extends TaskSetting {
  const LabelSetting(
    super.key,
    super.label, {
    required this.whenKey,
    required this.whenValue,
  }) : super(display: true);

  final String whenKey;
  final Object whenValue;

  @override
  int get initial => 0;
}

const _handSettings = [
  CountSetting('numHands', 'Num Hands', initial: 2, max: 4),
  ShareSetting('minHandDetectionConfidence', 'Min Hand Detection Confidence'),
  ShareSetting('minHandPresenceConfidence', 'Min Hand Presence Confidence'),
  ShareSetting('minTrackingConfidence', 'Min Tracking Confidence'),
];

/// Keyed by the catalog's runtime id.
const taskSettings = <String, List<TaskSetting>>{
  'face_detector': [
    ShareSetting('minDetectionConfidence', 'Min Detection Confidence'),
    ShareSetting(
      'minSuppressionThreshold',
      'Min Suppression Threshold',
      initial: 0.3,
    ),
  ],
  'face_landmarker': [
    CountSetting('numFaces', 'Num Faces', initial: 1),
    ShareSetting('minFaceDetectionConfidence', 'Min Detection Confidence'),
    ShareSetting('minFacePresenceConfidence', 'Min Presence Confidence'),
    ShareSetting('minTrackingConfidence', 'Min Tracking Confidence'),
  ],
  'hand_landmarker': _handSettings,
  'gesture_recognizer': [
    ..._handSettings,
    CountSetting('maxResults', 'Max Results', initial: 1, max: 8),
    ShareSetting('scoreThreshold', 'Score Threshold', initial: 0),
  ],
  'pose_landmarker': [
    CountSetting('numPoses', 'Num Poses', initial: 1, max: 5),
    ShareSetting('minPoseDetectionConfidence', 'Min Pose Detection Confidence'),
    ShareSetting('minPosePresenceConfidence', 'Min Pose Presence Confidence'),
    ShareSetting('minTrackingConfidence', 'Min Tracking Confidence'),
    SwitchSetting('outputSegmentationMasks', 'Output Segmentation Masks'),
  ],
  'holistic_landmarker': [
    ShareSetting('minFaceDetectionConfidence', 'Min Face Detection Confidence'),
    ShareSetting(
      'minFaceSuppressionThreshold',
      'Min Face Suppression Threshold',
    ),
    ShareSetting('minFacePresenceConfidence', 'Min Face Presence Confidence'),
    ShareSetting('minPoseDetectionConfidence', 'Min Pose Detection Confidence'),
    ShareSetting(
      'minPoseSuppressionThreshold',
      'Min Pose Suppression Threshold',
    ),
    ShareSetting('minPosePresenceConfidence', 'Min Pose Presence Confidence'),
    ShareSetting('minHandLandmarksConfidence', 'Min Hand Landmarks Confidence'),
    SwitchSetting('outputPoseSegmentationMask', 'Output Segmentation Mask'),
  ],
  'object_detector': [
    CountSetting('maxResults', 'Max Results', initial: 3, max: 25),
    ShareSetting('scoreThreshold', 'Score Threshold', initial: 0.5),
  ],
  // As Google's web demo: Category Mask colors every class with the legend's
  // colors, Confidence Mask shows how sure the model is of one chosen class.
  'image_segmenter': [
    ChoiceSetting(
      'outputConfidenceMasks',
      'Output Type',
      options: ['Category Mask', 'Confidence Mask'],
    ),
    LabelSetting(
      'confidenceClass',
      'Select Class',
      whenKey: 'outputConfidenceMasks',
      whenValue: 1,
    ),
    ShareSetting('opacity', 'Opacity', display: true),
  ],
  // The share of confidence a pixel needs to be drawn as selected.
  'interactive_segmenter': [
    ShareSetting('threshold', 'Threshold', display: true),
  ],
  'image_classifier': [
    CountSetting('maxResults', 'Max Results', initial: 3),
    ShareSetting('scoreThreshold', 'Score Threshold', initial: 0),
  ],
  'image_embedder': [
    SwitchSetting('l2Normalize', 'L2 Normalize'),
    SwitchSetting('quantize', 'Quantize'),
  ],
  'audio_classifier': [
    CountSetting('maxResults', 'Max Results', initial: 3),
    ShareSetting('scoreThreshold', 'Score Threshold', initial: 0),
  ],
  'text_classifier': [
    CountSetting('maxResults', 'Max Results', initial: 3),
    ShareSetting('scoreThreshold', 'Score Threshold', initial: 0),
  ],
  'language_detector': [
    CountSetting('maxResults', 'Max Results', initial: 3),
    ShareSetting('scoreThreshold', 'Score Threshold', initial: 0),
  ],
  'text_embedder': [
    SwitchSetting('l2Normalize', 'L2 Normalize'),
    SwitchSetting('quantize', 'Quantize'),
  ],
  // Google's embedder formats EmbeddingGemma's prompt for the chosen use.
  // The retrieval, question, fact and code uses pair a query with a
  // document: the first text is the query and the second the document.
  'embedding_gemma': [
    ChoiceSetting(
      'taskType',
      'Task Type',
      options: [
        'Semantic Similarity',
        'Retrieval',
        'Question Answering',
        'Fact Checking',
        'Code Retrieval',
        'Classification',
        'Clustering',
      ],
    ),
    SwitchSetting('l2Normalize', 'L2 Normalize'),
    SwitchSetting('quantize', 'Quantize'),
  ],
  // Streaming shows the text as Google generates it; off, the result
  // arrives whole, as `proofread()` and `summarize()` return it.
  'text_proofreader': [SwitchSetting('stream', 'Stream Output', initial: true)],
  'text_summarizer': [
    ChoiceSetting('mode', 'Mode', options: ['Key Points', 'TL;DR']),
    SwitchSetting('stream', 'Stream Output', initial: true),
  ],
  // Decision Maker's Yes / No threshold, and Google's normalization against
  // the model's empty-context prior, which removes label bias.
  'decision_maker': [
    ShareSetting('threshold', 'Yes Threshold'),
    SwitchSetting('normalizePrior', 'Normalize Prior'),
  ],
  // Universal Embedder's normalization, which Google's browser API defaults
  // to, and Semantic Retriever's result count and similarity floor.
  'universal_embedder': [
    SwitchSetting('l2Normalize', 'L2 Normalize', initial: true),
  ],
  'semantic_retriever': [
    CountSetting('limit', 'Results', initial: 3, min: 1, max: 6),
    ShareSetting('minSimilarity', 'Min Similarity', initial: 0),
  ],
};

/// The current value of every setting of one task.
final class TaskSettingValues {
  TaskSettingValues(String task)
    : _values = {
        for (final setting in taskSettings[task] ?? const <TaskSetting>[])
          setting.key: setting.initial,
      };

  final Map<String, Object> _values;

  int count(String key) => _values[key]! as int;
  double share(String key) => _values[key]! as double;
  bool on(String key) => _values[key]! as bool;
  int choice(String key) => _values[key]! as int;

  Object operator [](String key) => _values[key]!;
  void operator []=(String key, Object value) => _values[key] = value;
}
