/// The models, samples and task lists the gallery bundles on every target.
///
/// Every model name here must be in the owning package's `XxxModels.byName`;
/// `test/pins_test.dart` checks that, since this tool cannot import those
/// Flutter packages. The vision tasks come from the vision package's
/// `vision_tasks.dart`, a plain Dart file its build hook reads as well; only
/// file-relative imports reach it, so `bin/` and `test/` pass it in.
library;

/// The family and `XxxModels.byName` name the gallery lists in pubspec for
/// each task's model, as any app lists its own for `dart run
/// mediapipe_core:bundle_models`.
typedef BundledModel = ({String family, String name});

/// The model the gallery uses for every task some target bundles.
const models = <String, BundledModel>{
  'audio_classifier': (family: 'mediapipe_audio', name: 'yamnet'),
  'decision_maker': (family: 'mediapipe_decision', name: 'laya_s256'),
  'embedding_gemma': (family: 'mediapipe_text', name: 'embedding_gemma'),
  'face_detector': (family: 'mediapipe_vision', name: 'face_detector'),
  'face_landmarker': (family: 'mediapipe_vision', name: 'face_landmarker'),
  'gesture_recognizer': (
    family: 'mediapipe_vision',
    name: 'gesture_recognizer',
  ),
  'hand_landmarker': (family: 'mediapipe_vision', name: 'hand_landmarker'),
  'holistic_landmarker': (
    family: 'mediapipe_vision',
    name: 'holistic_landmarker',
  ),
  'image_classifier': (family: 'mediapipe_vision', name: 'image_classifier'),
  'image_embedder': (family: 'mediapipe_vision', name: 'image_embedder'),
  'image_segmenter': (family: 'mediapipe_vision', name: 'image_segmenter'),
  'interactive_segmenter': (
    family: 'mediapipe_vision',
    name: 'interactive_segmenter',
  ),
  'language_detector': (family: 'mediapipe_text', name: 'language_detector'),
  'object_detector': (family: 'mediapipe_vision', name: 'object_detector'),
  'pose_landmarker': (family: 'mediapipe_vision', name: 'pose_landmarker'),
  'text_classifier': (family: 'mediapipe_text', name: 'bert_classifier'),
  'text_embedder': (
    family: 'mediapipe_text',
    name: 'universal_sentence_encoder',
  ),
  'text_proofreader': (family: 'mediapipe_text', name: 'proofreader'),
  'text_summarizer': (family: 'mediapipe_text', name: 'summarizer'),
  'universal_embedder': (
    family: 'mediapipe_retrieval',
    name: 'embedding_gemma_2_text_vision',
  ),
  'semantic_retriever': (
    family: 'mediapipe_retrieval',
    name: 'embedding_gemma_2_text_vision',
  ),
};

/// The package directory whose `lib/models.dart` lists [family]'s names:
/// `mediapipe_<name>` is `packages/mediapipe-task-<name>`.
String packageOf(String family) {
  const prefix = 'mediapipe_';
  if (!family.startsWith(prefix) || family == 'mediapipe_core') {
    throw ArgumentError.value(family, 'family', 'is not a task family');
  }
  return 'mediapipe-task-${family.substring(prefix.length)}';
}

/// The text package's generative tasks and EmbeddingGemma, 419 MB of models
/// in all, bundled by default like every other task. Their integration suite
/// compares with Google's references, bundled from `--modern-text-reference`
/// or the package's checked-in macOS fixtures.
const modernTextTasks = {
  'embedding_gemma',
  'text_proofreader',
  'text_summarizer',
};

/// The checked-in fixture each modern text task's reference comes from.
const modernTextReferences = {
  'embedding_gemma': 'embedding_gemma',
  'text_proofreader': 'proofreader',
  'text_summarizer': 'summarizer',
};

/// Tasks whose model the gallery downloads on first use instead of bundling:
/// Decision Maker's smallest is 678 MB and the retrieval tasks' 388 MB, each
/// more than every other model put together.
const downloadedModelTasks = {
  'decision_maker',
  'semantic_retriever',
  'universal_embedder',
};

/// Tasks outside the vision package, which its build hook must not be asked
/// for.
const nonVisionTasks = {
  'audio_classifier',
  'decision_maker',
  'language_detector',
  'semantic_retriever',
  'text_classifier',
  'text_embedder',
  'universal_embedder',
  ...modernTextTasks,
};

/// The native targets the gallery builds for.
const nativeTargets = [
  'android/arm64',
  'android/x64',
  'ios/arm64',
  'ios-simulator/arm64',
  'linux/x64',
  'macos/arm64',
  'windows/x64',
];

/// Tasks Google's JavaScript runtime serves in browsers. It has no
/// Proofreader or Summarizer, so the web build bundles EmbeddingGemma alone of
/// the generative text tasks.
const webTasks = {
  'audio_classifier',
  'decision_maker',
  'embedding_gemma',
  'face_detector',
  'face_landmarker',
  'gesture_recognizer',
  'hand_landmarker',
  'holistic_landmarker',
  'image_classifier',
  'image_embedder',
  'image_segmenter',
  'interactive_segmenter',
  'language_detector',
  'object_detector',
  'pose_landmarker',
  'semantic_retriever',
  'text_classifier',
  'text_embedder',
  'universal_embedder',
};

/// The vision tasks a web build still lists for the vision hook: Chrome tests
/// also run the host's native hook, and the face pair is enough there; the
/// browser tasks run on Google's JavaScript runtime.
const webHostTestTasks = {'face_detector', 'face_landmarker'};

/// The tasks each target can bundle: on a native target every vision task
/// the vision package validates there ([visionRuntimeTasks], from
/// `vision_tasks.dart`), plus text and audio, whose packages bundle their own
/// Google libraries; in browsers, [webTasks].
Map<String, Set<String>> galleryTargets(
  Map<String, Set<String>> visionRuntimeTasks,
) => {
  for (final target in nativeTargets)
    target: {...visionRuntimeTasks[target]!, ...nonVisionTasks},
  'web': webTasks,
};

/// Sample inputs, from the test fixtures and the gallery's own samples, by
/// the name the gallery reads them under.
const samples = <String, String>{
  'packages/mediapipe-task-vision/test/fixtures/face_detection/landmark-ex1.jpg':
      'portrait.jpg',
  'packages/mediapipe-task-vision/test/fixtures/face_detection/group-shot-bounding-box-ex1.jpeg':
      'group.jpeg',
  'packages/mediapipe-task-vision/test/fixtures/landmark_tasks/right_hands.jpg':
      'hands.jpg',
  'packages/mediapipe-task-vision/test/fixtures/landmark_tasks/pose.jpg':
      'pose.jpg',
  'packages/mediapipe-task-vision/test/fixtures/landmark_tasks/thumb_up.jpg':
      'thumb_up.jpg',
  'packages/mediapipe-task-vision/test/fixtures/interactive_segmentation/cats_and_dogs.jpg':
      'animals.jpg',
  'packages/mediapipe-task-audio/test/fixtures/speech_16000_hz_mono.wav':
      'speech_16000_hz_mono.wav',
  'packages/mediapipe-task-audio/test/fixtures/speech_48000_hz_mono.wav':
      'speech_48000_hz_mono.wav',
  'packages/mediapipe-task-audio/test/fixtures/two_heads_16000_hz_mono.wav':
      'two_heads_16000_hz_mono.wav',
  'gallery/samples/dog.jpg': 'dog.jpg',
  'gallery/samples/cat.png': 'cat.png',
  'gallery/samples/elephant.png': 'elephant.png',
  // The video file mode's clip and the clip that checks a file's rotation,
  // made from the fixtures above by gallery/tool/make_sample_clip.py.
  'gallery/samples/scene.mp4': 'scene.mp4',
  'gallery/samples/rotated.mp4': 'rotated.mp4',
};

/// The photos Google's Image Embedding demo compares, bundled only with it
/// and with Universal Embedder, which offers the same three.
const embedderSamples = {'dog.jpg', 'cat.png', 'elephant.png'};

/// The tasks whose pages offer [embedderSamples].
const embedderSampleTasks = {'image_embedder', 'universal_embedder'};
