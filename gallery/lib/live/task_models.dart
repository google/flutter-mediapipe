import 'package:crypto/crypto.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:mediapipe_decision/mediapipe_decision.dart'
    show DecisionModels, DownloadAsset;
import 'package:mediapipe_text/mediapipe_text.dart' show TextModels;

/// One of Google's official models for a task, as the task's guide lists
/// them. The gallery bundles each task's standard model; these download when
/// chosen, from Google's LiteRT community on Hugging Face at a pinned
/// revision, and must match [sha256].
final class TaskModel {
  /// A model at [path] under https://huggingface.co/litert-community/.
  const TaskModel(this.name, String path, String sha256, this.bytes)
    : _path = path,
      _sha256 = sha256,
      _pin = null;

  /// A model its family package already pins, such as Decision Maker's.
  const TaskModel.pinned(this.name, DownloadAsset pin, this.bytes)
    : _pin = pin,
      _path = null,
      _sha256 = null;

  final String name;
  final String? _path;
  final String? _sha256;
  final DownloadAsset? _pin;

  /// Download size, shown before choosing.
  final int bytes;

  /// The download, checked against its SHA-256.
  DownloadAsset get pin =>
      _pin ??
      DownloadAsset(
        url: 'https://huggingface.co/litert-community/$_path',
        sha256: _sha256!,
      );

  Uri get url => Uri.parse(pin.url);

  /// The model's file name, as the Info dialog shows it.
  String get file => url.pathSegments.last;

  String get sha256 => pin.sha256;
}

/// The bundled model's name as the task's guide lists it, keyed by the
/// catalog's runtime id, for the tasks whose pages offer other models.
const standardModelNames = <String, String>{
  'face_detector': 'BlazeFace (short-range)',
  'image_classifier': 'EfficientNet-Lite0 (float 32)',
  'image_embedder': 'MobileNet-V3 (small)',
  'image_segmenter': 'DeepLab-V3',
  'object_detector': 'EfficientDet-Lite0 (float 32)',
  'pose_landmarker': 'Pose Landmarker (lite)',
  'text_classifier': 'BERT-classifier',
  'text_embedder': 'Universal Sentence Encoder',
};

/// Alternatives to each task's bundled model, keyed by the catalog's runtime
/// id. Every one runs through Google's own task API for that task.
const taskModels = <String, List<TaskModel>>{
  // Hungry Fish starts with EmbeddingGemma 2; Laya plays it as well.
  'decision_fish_game': [
    TaskModel.pinned('Laya (256-token)', DecisionModels.layaS256, 678477844),
  ],
  // Decision Maker downloads its model to a file rather than to memory: see
  // `GalleryAssets.downloadedModelPath`.
  'decision_maker': [
    TaskModel.pinned('Laya (512-token)', DecisionModels.layaS512, 679395348),
    TaskModel.pinned(
      'GLiNER2.5-Decide (256-token)',
      DecisionModels.glinerS256,
      981216352,
    ),
    TaskModel.pinned(
      'GLiNER2.5-Decide (512-token)',
      DecisionModels.glinerS512,
      1081879648,
    ),
  ],
  'face_detector': [
    TaskModel(
      'BlazeFace (full-range)',
      'MediaPipe-FaceDetector-BlazeFace-Full-Range/resolve/'
          '6bc74b6a14695b84caafcfb763b14ee633f02f60/'
          'blaze_face_full_range.tflite',
      '3698b18f063835bc609069ef052228fbe86d9c9a6dc8dcb7c7c2d69aed2b181b',
      1083786,
    ),
    TaskModel(
      'BlazeFace Sparse (full-range)',
      'MediaPipe-FaceDetector-BlazeFace-Full-Range-Sparse/resolve/'
          '06e2fd00dfe029e84b5bf1caa23e0c4c542e83e7/'
          'blaze_face_full_range_sparse.tflite',
      '2c3728e6da56f21e21a320433396fb06d40d9088f2247c05e5635a688d45dfe1',
      676746,
    ),
  ],
  'pose_landmarker': [
    TaskModel(
      'Pose Landmarker (full)',
      'MediaPipe-PoseLandmarker-Full/resolve/'
          'e356612f3ba14ec42a14f14d0d7d0a14d450de59/'
          'pose_landmarker_full.task',
      '4eaa5eb7a98365221087693fcc286334cf0858e2eb6e15b506aa4a7ecdcec4ad',
      9398198,
    ),
    TaskModel(
      'Pose Landmarker (heavy)',
      'MediaPipe-PoseLandmarker-Heavy/resolve/'
          '8a9deee6a176119dbaf22006b4a1db71fd889d82/'
          'pose_landmarker_heavy.task',
      '64437af838a65d18e5ba7a0d39b465540069bc8aae8308de3e318aad31fcbc7b',
      30664242,
    ),
  ],
  'object_detector': [
    TaskModel(
      'EfficientDet-Lite2 (float 16)',
      'MediaPipe-ObjectDetector-EfficientDet-Lite2/resolve/'
          '50785e6df46b2549e3e3608fa9f0d238f345f482/'
          'efficientdet_lite2_float16.tflite',
      '5d4ebec1029bc9907aeadb9e7b4ac9cb1da6a19d01ad375210a9ae18ba173302',
      12138859,
    ),
    TaskModel(
      'SSDMobileNet-V2 (float 16)',
      'MediaPipe-ObjectDetector-SSD-MobileNet-V2/resolve/'
          'a9d10f5380cec69294aca48e1ddf350fce3adefe/'
          'ssd_mobilenet_v2_float16.tflite',
      'ee21e12bfdc464100c6008c865ab8294f6a04162e6ed2e11986f1175b02cfab2',
      5918749,
    ),
  ],
  'image_classifier': [
    TaskModel(
      'EfficientNet-Lite2 (float 32)',
      'MediaPipe-ImageClassifier-EfficientNet-Lite2/resolve/'
          '12e1bd15b84d3c4d69066c85c5bca3fb7572c921/'
          'efficientnet_lite2_float32.tflite',
      '94b6c84a5d6de20f932558de213b50e0338dcc06ab83d8d64b12128a476b4b83',
      24325765,
    ),
  ],
  'image_embedder': [
    TaskModel(
      'MobileNet-V3 (large)',
      'MediaPipe-ImageEmbedder-MobileNet-V3-Large/resolve/'
          'c9f46d7bfe7977c7fc0ecf5fe45679fac09f410e/'
          'mobilenet_v3_large.tflite',
      '11af3c560dfeed7737cb4c03c23bf52a8403020784192d4dea0b74862a12828d',
      10889458,
    ),
  ],
  'image_segmenter': [
    TaskModel(
      'SelfieSegmenter (square)',
      'MediaPipe-ImageSegmenter-Selfie-Square/resolve/'
          '051d3732aad8fd018433520029e00ade7463aaea/'
          'selfie_segmenter.tflite',
      '191ac9529ae506ee0beefa6b2c945a172dab9d07d1e802a290a4e4038226658b',
      249537,
    ),
    TaskModel(
      'SelfieSegmenter (landscape)',
      'MediaPipe-ImageSegmenter-Selfie-Landscape/resolve/'
          'f04c07a5598479d0b03c796c0806329e9fab4082/'
          'selfie_segmenter_landscape.tflite',
      '490e9ea734313e0de10fa0cd9e3c6133e36ea4db2b7a49bde9ef019f72796b8e',
      250177,
    ),
    TaskModel(
      'HairSegmenter',
      'MediaPipe-ImageSegmenter-Hair/resolve/'
          '636ae705ff62db7fcdb8af27b19abb8ffc168f34/'
          'hair_segmenter.tflite',
      '2628cf3ce5f695f604cbea2841e00befcaa3624bf80caf3664bef2656d59bf84',
      781618,
    ),
    TaskModel(
      'SelfieMulticlass (256 x 256)',
      'MediaPipe-ImageSegmenter-Selfie-Multiclass/resolve/'
          'c7b7e9e0f1e73c10a12114379077b5257e60c25c/'
          'selfie_multiclass_256x256.tflite',
      'c6748b1253a99067ef71f7e26ca71096cd449baefa8f101900ea23016507e0e0',
      16371837,
    ),
  ],
  'text_classifier': [
    TaskModel(
      'Average word embedding',
      'MediaPipe-TextClassifier-AverageWord/resolve/'
          '22c1175ba45ca7185c2e7f9484c6e705bb3f9230/'
          'average_word_classifier.tflite',
      '13bf6f7f35964f1e85d6cc762ee7b1952009b532b233baa5bdb4bf7441097f34',
      775706,
    ),
  ],
  // The two models Google's Text Embedder guide lists: the bundled Universal
  // Sentence Encoder, and EmbeddingGemma where the build bundles it too, so
  // choosing it downloads nothing (`offersEmbeddingGemma` in the catalog).
  'text_embedder': [embeddingGemmaModel],
};

/// EmbeddingGemma, as Google's Text Embedder guide names it.
const embeddingGemmaModel = TaskModel.pinned(
  'EmbeddingGemma 300M',
  TextModels.embeddingGemma,
  183816181,
);

final _downloaded = <String, Uint8List>{};

/// Downloads [model] once per session and refuses bytes that do not match
/// its pinned digest. package:http, unlike [NetworkAssetBundle], whose
/// `HttpClient` the web has not, downloads on every platform.
Future<Uint8List> downloadModel(TaskModel model) async {
  if (_downloaded[model.sha256] case final bytes?) return bytes;
  final response = await http.get(model.url);
  if (response.statusCode != 200) {
    throw StateError(
      '${model.name} did not download: HTTP ${response.statusCode}.',
    );
  }
  final bytes = response.bodyBytes;
  if (sha256.convert(bytes).toString() != model.sha256) {
    throw StateError('${model.name} did not match its pinned checksum.');
  }
  return _downloaded[model.sha256] = bytes;
}

/// A page whose task runs the bundled model, one of Google's others, or a
/// file of the user's own, as the settings panel offers them.
mixin ModelSelectionState<T extends StatefulWidget> on State<T> {
  /// The chosen official model, or null for the bundled or uploaded one.
  TaskModel? model;

  /// The uploaded file's name while an upload is chosen.
  String? uploaded;

  /// The chosen or uploaded model's bytes, or null for the bundled one.
  Uint8List? modelBytes;

  /// A download in progress, or what failed.
  String? modelStatus;

  /// The chosen or uploaded model's file name, or null for the bundled one.
  String? get modelFile => uploaded ?? model?.file;

  /// Rebuilds the task with [modelBytes], after every change.
  void modelChanged();

  /// Downloads and verifies an official model before the task is rebuilt
  /// with it, so a failed download leaves the running model in place. Null
  /// returns to the bundled model.
  Future<void> chooseModel(TaskModel? chosen) async {
    if (chosen == null) {
      setState(() {
        model = null;
        uploaded = null;
        modelBytes = null;
        modelStatus = null;
      });
      modelChanged();
      return;
    }
    setState(() => modelStatus = 'Downloading ${chosen.name}…');
    try {
      final bytes = await downloadModel(chosen);
      if (!mounted) return;
      setState(() {
        model = chosen;
        uploaded = null;
        modelBytes = bytes;
        modelStatus = null;
      });
      modelChanged();
    } on Object catch (error) {
      if (mounted) setState(() => modelStatus = '$error');
    }
  }

  /// A model file of the user's own.
  Future<void> uploadModel() async {
    try {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'MediaPipe models',
            extensions: ['tflite', 'task'],
            // iOS filters by type, and models have none of their own.
            uniformTypeIdentifiers: ['public.data'],
          ),
        ],
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        model = null;
        uploaded = file.name;
        modelBytes = bytes;
        modelStatus = null;
      });
      modelChanged();
    } on Object catch (error) {
      if (mounted) setState(() => modelStatus = '$error');
    }
  }
}
