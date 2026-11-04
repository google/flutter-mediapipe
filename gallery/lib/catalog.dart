import 'package:mediapipe_audio/mediapipe_audio.dart'
    show AudioModels, audioClassifierCapabilitiesForPlatform;
import 'package:mediapipe_decision/mediapipe_decision.dart'
    show DecisionModels, decisionMakerCapabilitiesForPlatform;
import 'package:mediapipe_retrieval/mediapipe_retrieval.dart'
    show
        RetrievalModels,
        semanticRetrieverCapabilitiesForPlatform,
        universalEmbedderCapabilitiesForPlatform;
import 'package:mediapipe_text/mediapipe_text.dart'
    show
        TextModels,
        textClassifierCapabilitiesForPlatform,
        textEmbedderCapabilitiesForPlatform,
        textProofreaderCapabilitiesForPlatform,
        textSummarizerCapabilitiesForPlatform;
import 'package:mediapipe_vision/mediapipe_vision.dart';

import 'live/task_models.dart' show TaskModel;

/// How a tile demonstrates its task.
enum GalleryDemo {
  /// Known to the gallery, but with no screen of its own, so it never becomes
  /// a tile.
  none,

  /// Live camera capture.
  live,

  /// Interactive segmentation on a bundled image.
  segment,

  /// Two still images compared by their embeddings.
  embed,

  /// A text task on typed input.
  text,

  /// An audio task on a clip.
  audio,

  /// A question about typed text, answered by Decision Maker.
  decision,

  /// A game Decision Maker plays.
  game,

  /// Two inputs, a text or an image each, compared by Universal Embedder.
  universalEmbed,

  /// Documents indexed on the device and searched by meaning.
  retrieve,
}

/// The home page's sections, in MediaPipe Studio's order, then the families
/// Google added in MediaPipe 1.1.0.
enum GalleryCategory {
  vision('Vision'),
  audio('Audio'),
  text('Text'),
  decision('Decision'),
  retrieval('Retrieval');

  const GalleryCategory(this.title);
  final String title;
}

/// A MediaPipe task the home page lists in its section on every platform
/// even though this build cannot run it; [plannedReason] says why.
typedef PlannedTask = ({
  GalleryCategory category,
  String title,
  String runtimeId,
});

/// The audio, text, decision and retrieval tasks, listed as MediaPipe Studio
/// lists them. A build prepared without one, or a platform whose runtime
/// lacks it, shows its card in place of the tile.
final plannedTasks = <PlannedTask>[
  for (final task in _catalog)
    if (task.category != GalleryCategory.vision)
      (category: task.category, title: task.title, runtimeId: task.runtimeId),
];

/// Why [task] is a card rather than a tile: this build did not bundle it, or
/// its runtime on [platform] cannot run it, in the package's own words.
String plannedReason(
  PlannedTask task,
  TaskPlatform platform,
  Set<String> bundled,
) {
  if (!bundled.contains(task.runtimeId)) return 'Not bundled in this build.';
  // A runtime can have several entries, such as Decision Maker and its game.
  final entry = _catalog.firstWhere(
    (t) => t.runtimeId == task.runtimeId && t.title == task.title,
  );
  return entry.capabilities(platform).unavailableReasons[Delegate.cpu] ??
      'Not validated on this platform.';
}

/// One entry in the gallery.
///
/// [capabilities] is the package's own support query, so a tile appears only
/// where the runtime is validated. Nothing here restates support by hand: when
/// a task is validated on a new platform the gallery follows automatically.
final class GalleryTask {
  const GalleryTask({
    required this.id,
    required this.title,
    required this.summary,
    required this.model,
    required this.sample,
    required this.capabilities,
    this.demo = GalleryDemo.none,
    this.category = GalleryCategory.vision,
    this.downloadsModel = false,
    String? runtimeId,
  }) : runtimeId = runtimeId ?? id;

  /// The home page section the tile belongs to.
  final GalleryCategory category;

  /// Tile id, unique within the catalog.
  final String id;

  /// Task id as the build hook and the bundled manifest spell it. A live demo
  /// shares the runtime of the still-image tile beside it.
  final String runtimeId;
  final String title;
  final String summary;

  /// How this tile demonstrates its task.
  final GalleryDemo demo;

  /// Whether this tile opens the live camera demo.
  bool get live => demo == GalleryDemo.live;

  /// Whether this entry has a screen of its own, and so can be a tile.
  bool get hasOwnPage => demo != GalleryDemo.none;

  /// The pinned model the demo runs, which the gallery's pubspec lists for
  /// `dart run mediapipe_core:bundle_models` like any app's.
  final DownloadAsset model;

  /// The model's file name, as Google publishes it.
  String get modelFile => Uri.parse(model.url).pathSegments.last;

  /// Whether the page downloads [model] on first use rather than the app
  /// bundling it: Decision Maker's and the retrieval tasks' models are
  /// larger than every other model together (`downloadedModelTasks` in
  /// tool/gallery_builder).
  final bool downloadsModel;

  /// Whether the model is one of Google's Gemma models, which come under the
  /// Gemma Terms of Use rather than Apache 2.0, so the gallery passes the
  /// terms on wherever it runs one.
  bool get gemmaModel => const {
    'embedding_gemma',
    'text_proofreader',
    'text_summarizer',
  }.contains(runtimeId);

  /// Sample input shipped for the demo.
  final String sample;

  final TaskCapabilities Function(TaskPlatform) capabilities;
}

/// The delegate a demo opens on: GPU wherever this platform offers it for the
/// task, as Google's web demo does, otherwise the first supported delegate.
Delegate preferredDelegate(Iterable<Delegate> supported) =>
    supported.contains(Delegate.gpu)
    ? Delegate.gpu
    : supported.isEmpty
    ? Delegate.cpu
    : supported.first;

/// The classic text tasks' support, from their own capability table: CPU on
/// core's shared runtime, and in browsers and on mobile once a platform
/// plugin has installed its backend.
TaskCapabilities _text(TaskPlatform platform) =>
    textClassifierCapabilitiesForPlatform(platform);

/// EmbeddingGemma's support, from the embedder's table for that model: the
/// CPU wherever the classic embedders run.
TaskCapabilities _embeddingGemma(TaskPlatform platform) =>
    textEmbedderCapabilitiesForPlatform(
      platform,
      model: TextModels.embeddingGemma,
    );

/// Audio Classifier's support, from its own capability table.
TaskCapabilities _audio(TaskPlatform platform) =>
    audioClassifierCapabilitiesForPlatform(platform);

/// The EmbeddingGemma 2 model Hungry Fish plays on by default on [platform]:
/// the text-only one, or null where Google's runtime cannot run it, as in
/// WebKit (UP-054).
DownloadAsset? fishGameModel(TaskPlatform platform) =>
    decisionMakerCapabilitiesForPlatform(
      platform,
      model: DecisionModels.embeddingGemma2Text,
    ).isSupported
    ? DecisionModels.embeddingGemma2Text
    : null;

/// Hungry Fish's support on [platform]: Decision Maker's with the model it
/// plays on, so the tile is a card, with the package's reason, where neither
/// model runs.
TaskCapabilities fishGameCapabilitiesForPlatform(TaskPlatform platform) =>
    decisionMakerCapabilitiesForPlatform(
      platform,
      model: fishGameModel(platform) ?? DecisionModels.embeddingGemma2Text,
    );

/// Whether Decision Maker on [platform] runs the alternative [model] a page
/// offers, so a picker lists only models the package accepts there.
bool decisionRunsModel(TaskPlatform platform, TaskModel model) =>
    decisionMakerCapabilitiesForPlatform(
      platform,
      model: model.pin,
    ).isSupported;

final _catalog = <GalleryTask>[
  GalleryTask(
    id: 'face_landmarker_live',
    runtimeId: 'face_landmarker',
    demo: GalleryDemo.live,
    title: 'Face Landmarker',
    summary: 'Facial landmarks from the camera or a still image.',
    model: VisionModels.faceLandmarker,
    sample: 'portrait.jpg',
    capabilities: faceLandmarkerCapabilitiesForPlatform,
  ),
  GalleryTask(
    id: 'hand_landmarker_live',
    runtimeId: 'hand_landmarker',
    demo: GalleryDemo.live,
    title: 'Hand Landmarker',
    summary: 'Hand landmarks and handedness in camera frames or an image.',
    model: VisionModels.handLandmarker,
    sample: 'hands.jpg',
    capabilities: handLandmarkerCapabilitiesForPlatform,
  ),
  GalleryTask(
    id: 'pose_landmarker_live',
    runtimeId: 'pose_landmarker',
    demo: GalleryDemo.live,
    title: 'Pose Landmarker',
    summary: 'Pose landmarks and skeleton in camera frames or an image.',
    model: VisionModels.poseLandmarker,
    sample: 'pose.jpg',
    capabilities: poseLandmarkerCapabilitiesForPlatform,
  ),
  GalleryTask(
    id: 'gesture_recognizer_live',
    runtimeId: 'gesture_recognizer',
    demo: GalleryDemo.live,
    title: 'Gesture Recognizer',
    summary: 'Hand landmarks and recognized gestures in video or an image.',
    model: VisionModels.gestureRecognizer,
    sample: 'thumb_up.jpg',
    capabilities: gestureRecognizerCapabilitiesForPlatform,
  ),
  GalleryTask(
    id: 'holistic_landmarker_live',
    runtimeId: 'holistic_landmarker',
    demo: GalleryDemo.live,
    title: 'Holistic Landmarker',
    summary: 'Body, hands and face together in video or an image.',
    model: VisionModels.holisticLandmarker,
    sample: 'pose.jpg',
    capabilities: holisticLandmarkerCapabilitiesForPlatform,
  ),
  GalleryTask(
    id: 'face_detector_live',
    runtimeId: 'face_detector',
    demo: GalleryDemo.live,
    title: 'Face Detector',
    summary: 'Face boxes and six keypoints in video or an image.',
    model: VisionModels.faceDetector,
    sample: 'portrait.jpg',
    capabilities: faceDetectorCapabilitiesForPlatform,
  ),
  GalleryTask(
    id: 'object_detector_live',
    runtimeId: 'object_detector',
    demo: GalleryDemo.live,
    title: 'Object Detector',
    summary: 'Labeled object boxes in camera frames or an image.',
    model: VisionModels.objectDetector,
    sample: 'group.jpeg',
    capabilities: objectDetectorCapabilitiesForPlatform,
  ),
  GalleryTask(
    id: 'image_classifier_live',
    runtimeId: 'image_classifier',
    demo: GalleryDemo.live,
    title: 'Image Classifier',
    summary: 'The top three classes for camera frames or an image.',
    model: VisionModels.imageClassifier,
    sample: 'portrait.jpg',
    capabilities: imageClassifierCapabilitiesForPlatform,
  ),
  GalleryTask(
    id: 'object_detector',
    title: 'Object Detector',
    summary: 'Labelled boxes over everyday objects.',
    model: VisionModels.objectDetector,
    sample: 'group.jpeg',
    capabilities: objectDetectorCapabilitiesForPlatform,
  ),
  GalleryTask(
    id: 'image_classifier',
    title: 'Image Classifier',
    summary: 'Top-k labels with scores.',
    model: VisionModels.imageClassifier,
    sample: 'portrait.jpg',
    capabilities: imageClassifierCapabilitiesForPlatform,
  ),
  // Still images only, as Google's Image Embedding demo compares them.
  GalleryTask(
    id: 'image_embedder',
    demo: GalleryDemo.embed,
    title: 'Image Embedder',
    summary: 'Two images as vectors, compared by similarity.',
    model: VisionModels.imageEmbedder,
    sample: 'dog.jpg',
    capabilities: imageEmbedderCapabilitiesForPlatform,
  ),
  GalleryTask(
    id: 'hand_landmarker',
    title: 'Hand Landmarker',
    summary: '21 landmarks per hand, with handedness.',
    model: VisionModels.handLandmarker,
    sample: 'hands.jpg',
    capabilities: handLandmarkerCapabilitiesForPlatform,
  ),
  GalleryTask(
    id: 'gesture_recognizer',
    title: 'Gesture Recognizer',
    summary: 'Hand landmarks plus a recognised gesture.',
    model: VisionModels.gestureRecognizer,
    sample: 'thumb_up.jpg',
    capabilities: gestureRecognizerCapabilitiesForPlatform,
  ),
  GalleryTask(
    id: 'pose_landmarker',
    title: 'Pose Landmarker',
    summary: '33 body landmarks with visibility.',
    model: VisionModels.poseLandmarker,
    sample: 'pose.jpg',
    capabilities: poseLandmarkerCapabilitiesForPlatform,
  ),
  GalleryTask(
    id: 'holistic_landmarker',
    title: 'Holistic Landmarker',
    summary: 'Face, hands and pose in one graph.',
    model: VisionModels.holisticLandmarker,
    sample: 'pose.jpg',
    capabilities: holisticLandmarkerCapabilitiesForPlatform,
  ),
  GalleryTask(
    id: 'image_segmenter',
    title: 'Image Segmenter',
    summary: 'Category and confidence masks.',
    model: VisionModels.imageSegmenter,
    sample: 'portrait.jpg',
    capabilities: imageSegmenterCapabilitiesForPlatform,
  ),
  GalleryTask(
    id: 'image_segmenter_live',
    runtimeId: 'image_segmenter',
    demo: GalleryDemo.live,
    title: 'Image Segmenter',
    summary: 'Segmentation masks for camera frames or an image.',
    model: VisionModels.imageSegmenter,
    sample: 'portrait.jpg',
    capabilities: imageSegmenterCapabilitiesForPlatform,
  ),
  GalleryTask(
    id: 'interactive_segmenter',
    demo: GalleryDemo.segment,
    title: 'Interactive Segmenter',
    summary: 'Tap a subject to segment it, stroke by stroke.',
    model: VisionModels.interactiveSegmenter,
    sample: 'animals.jpg',
    capabilities: interactiveSegmenterCapabilitiesForPlatform,
  ),
  // The audio package's Audio Classifier, on the same shared runtime.
  GalleryTask(
    id: 'audio_classifier',
    category: GalleryCategory.audio,
    demo: GalleryDemo.audio,
    title: 'Audio Classifier',
    summary: 'Sound categories in a clip, second by second.',
    model: AudioModels.yamnet,
    sample: 'speech_16000_hz_mono.wav',
    capabilities: _audio,
  ),
  // The text package's classic tasks, on the shared runtime: macOS
  // arm64 CPU, where the gallery bundles their models.
  GalleryTask(
    id: 'language_detector',
    category: GalleryCategory.text,
    demo: GalleryDemo.text,
    title: 'Language Detector',
    summary: 'The language of a piece of text.',
    model: TextModels.languageDetector,
    sample: '',
    capabilities: _text,
  ),
  GalleryTask(
    id: 'text_classifier',
    category: GalleryCategory.text,
    demo: GalleryDemo.text,
    title: 'Text Classifier',
    summary: 'Sentiment of a piece of text.',
    model: TextModels.bertClassifier,
    sample: '',
    capabilities: _text,
  ),
  GalleryTask(
    id: 'text_embedder',
    category: GalleryCategory.text,
    demo: GalleryDemo.text,
    title: 'Text Embedder',
    summary: 'Two texts as vectors, compared by similarity.',
    model: TextModels.universalSentenceEncoder,
    sample: '',
    capabilities: _text,
  ),
  GalleryTask(
    id: 'embedding_gemma',
    category: GalleryCategory.text,
    demo: GalleryDemo.text,
    title: 'EmbeddingGemma',
    summary: 'Two texts as Gemma vectors, formatted for a chosen use.',
    model: TextModels.embeddingGemma,
    sample: '',
    capabilities: _embeddingGemma,
  ),
  GalleryTask(
    id: 'text_proofreader',
    category: GalleryCategory.text,
    demo: GalleryDemo.text,
    title: 'Proofreader',
    summary: 'Corrected text and the edits that make it, as it is written.',
    model: TextModels.proofreader,
    sample: '',
    capabilities: textProofreaderCapabilitiesForPlatform,
  ),
  // Decision Maker, on Google's per-family library and its browser runtime.
  GalleryTask(
    id: 'decision_maker',
    category: GalleryCategory.decision,
    demo: GalleryDemo.decision,
    downloadsModel: true,
    title: 'Decision Maker',
    summary: 'Yes-or-no, choice and score questions about a text.',
    model: DecisionModels.layaS256,
    sample: '',
    capabilities: decisionMakerCapabilitiesForPlatform,
  ),
  // Decision Maker playing a game, as Google's web demo plays its dino game.
  // Its model is the text-only EmbeddingGemma 2; in WebKit, which runs no
  // EmbeddingGemma 2 model (UP-054), the tile is a card.
  GalleryTask(
    id: 'decision_fish_game',
    runtimeId: 'decision_maker',
    category: GalleryCategory.decision,
    demo: GalleryDemo.game,
    downloadsModel: true,
    title: 'Hungry Fish',
    summary:
        'A fish that eats smaller fish and flees bigger ones, steered '
        'by Decision Maker.',
    model: DecisionModels.embeddingGemma2Text,
    sample: '',
    capabilities: fishGameCapabilitiesForPlatform,
  ),
  GalleryTask(
    id: 'text_summarizer',
    category: GalleryCategory.text,
    demo: GalleryDemo.text,
    title: 'Summarizer',
    summary: 'Key points or a short paragraph for a piece of text.',
    model: TextModels.summarizer,
    sample: '',
    capabilities: textSummarizerCapabilitiesForPlatform,
  ),
  // The retrieval package's tasks, on Google's per-family retrieval library
  // and, in browsers, its JavaScript runtime. Their 388 MB model downloads
  // on first use.
  GalleryTask(
    id: 'universal_embedder',
    category: GalleryCategory.retrieval,
    demo: GalleryDemo.universalEmbed,
    title: 'Universal Embedder',
    summary: 'A text and an image as vectors in one space, compared.',
    model: RetrievalModels.embeddingGemma2TextVision,
    sample: 'dog.jpg',
    capabilities: universalEmbedderCapabilitiesForPlatform,
    downloadsModel: true,
  ),
  GalleryTask(
    id: 'semantic_retriever',
    category: GalleryCategory.retrieval,
    demo: GalleryDemo.retrieve,
    title: 'Semantic Retriever',
    summary: 'A few documents indexed on the device, searched by meaning.',
    model: RetrievalModels.embeddingGemma2TextVision,
    sample: '',
    capabilities: semanticRetrieverCapabilitiesForPlatform,
    downloadsModel: true,
  ),
];

/// The catalog restricted to tasks this build actually bundled and whose
/// runtime is validated here. [bundled] comes from `assets/manifest.json`.
List<GalleryTask> supportedTasks(TaskPlatform platform, Set<String> bundled) =>
    [
      for (final task in _catalog)
        if (bundled.contains(task.runtimeId) &&
            task.capabilities(platform).isSupported)
          task,
    ];
