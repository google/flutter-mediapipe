import 'package:crypto/crypto.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:mediapipe_decision/mediapipe_decision.dart'
    show DecisionModels, DownloadAsset;

/// One of Google's official models for a task, as MediaPipe Studio offers
/// them. The gallery bundles each task's standard model; these download when
/// chosen, from Google's pinned version 1, and must match [sha256].
final class TaskModel {
  /// A model at [path] under https://storage.googleapis.com/mediapipe-models/.
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
        url: 'https://storage.googleapis.com/mediapipe-models/$_path',
        sha256: _sha256!,
      );

  Uri get url => Uri.parse(pin.url);

  String get sha256 => pin.sha256;
}

/// The bundled model's name where Google's demo names it, keyed by the
/// catalog's runtime id; other tasks call theirs "Standard".
const standardModelNames = <String, String>{
  'image_embedder': 'MobileNet-V3 (Small)',
  'image_segmenter': 'DeepLab V3',
};

/// Alternatives to each task's bundled model, keyed by the catalog's runtime
/// id. Every one runs through Google's own task API for that task.
const taskModels = <String, List<TaskModel>>{
  // Hungry Fish starts with EmbeddingGemma 2; Laya plays it as well.
  'decision_fish_game': [
    TaskModel.pinned('Laya (256 tokens)', DecisionModels.layaS256, 678477844),
  ],
  // Decision Maker downloads its model to a file rather than to memory: see
  // `GalleryAssets.downloadedModelPath`.
  'decision_maker': [
    TaskModel.pinned('Laya (512 tokens)', DecisionModels.layaS512, 679395348),
    TaskModel.pinned(
      'GLiNER2.5-Decide (256 tokens)',
      DecisionModels.glinerS256,
      981216352,
    ),
    TaskModel.pinned(
      'GLiNER2.5-Decide (512 tokens)',
      DecisionModels.glinerS512,
      1081879648,
    ),
  ],
  'pose_landmarker': [
    TaskModel(
      'Pose Landmarker (Full)',
      'pose_landmarker/pose_landmarker_full/float16/1/pose_landmarker_full.task',
      '5134a3aad27a58b93da0088d431f366da362b44e3ccfbe3462b3827a839011b1',
      9398198,
    ),
    TaskModel(
      'Pose Landmarker (Heavy)',
      'pose_landmarker/pose_landmarker_heavy/float16/1/pose_landmarker_heavy.task',
      '64437af838a65d18e5ba7a0d39b465540069bc8aae8308de3e318aad31fcbc7b',
      30664242,
    ),
  ],
  'object_detector': [
    TaskModel(
      'EfficientDet-Lite2',
      'object_detector/efficientdet_lite2/float16/1/efficientdet_lite2.tflite',
      '5d4ebec1029bc9907aeadb9e7b4ac9cb1da6a19d01ad375210a9ae18ba173302',
      12138859,
    ),
    TaskModel(
      'SSD MobileNetV2',
      'object_detector/ssd_mobilenet_v2/float16/1/ssd_mobilenet_v2.tflite',
      'ee21e12bfdc464100c6008c865ab8294f6a04162e6ed2e11986f1175b02cfab2',
      5918749,
    ),
  ],
  'image_classifier': [
    TaskModel(
      'EfficientNet-Lite2',
      'image_classifier/efficientnet_lite2/float32/1/efficientnet_lite2.tflite',
      '94b6c84a5d6de20f932558de213b50e0338dcc06ab83d8d64b12128a476b4b83',
      24325765,
    ),
  ],
  'image_embedder': [
    TaskModel(
      'MobileNet-V3 (Large)',
      'image_embedder/mobilenet_v3_large/float32/1/mobilenet_v3_large.tflite',
      '11af3c560dfeed7737cb4c03c23bf52a8403020784192d4dea0b74862a12828d',
      10889458,
    ),
  ],
  'image_segmenter': [
    TaskModel(
      'Selfie Segmenter',
      'image_segmenter/selfie_segmenter/float16/1/selfie_segmenter.tflite',
      '191ac9529ae506ee0beefa6b2c945a172dab9d07d1e802a290a4e4038226658b',
      249537,
    ),
    TaskModel(
      'Selfie Segmenter (Landscape)',
      'image_segmenter/selfie_segmenter_landscape/float16/1/'
          'selfie_segmenter_landscape.tflite',
      '490e9ea734313e0de10fa0cd9e3c6133e36ea4db2b7a49bde9ef019f72796b8e',
      250177,
    ),
    TaskModel(
      'Hair Segmenter',
      'image_segmenter/hair_segmenter/float32/1/hair_segmenter.tflite',
      '2628cf3ce5f695f604cbea2841e00befcaa3624bf80caf3664bef2656d59bf84',
      781618,
    ),
    TaskModel(
      'Selfie Multiclass (256x256)',
      'image_segmenter/selfie_multiclass_256x256/float32/1/'
          'selfie_multiclass_256x256.tflite',
      'c6748b1253a99067ef71f7e26ca71096cd449baefa8f101900ea23016507e0e0',
      16371837,
    ),
  ],
  'text_classifier': [
    TaskModel(
      'Average Word Embedding',
      'text_classifier/average_word_classifier/float32/1/'
          'average_word_classifier.tflite',
      '13bf6f7f35964f1e85d6cc762ee7b1952009b532b233baa5bdb4bf7441097f34',
      775706,
    ),
  ],
  'text_embedder': [
    TaskModel(
      'BERT Embedder',
      'text_embedder/bert_embedder/float32/1/bert_embedder.tflite',
      '02ae6279faf86c2cd4ff18f61876c878bcc0b572b472f0678897a184c4ac7ef6',
      26142232,
    ),
  ],
};

final _downloaded = <String, Uint8List>{};

/// Downloads [model] once per session and refuses bytes that do not match
/// its pinned digest.
Future<Uint8List> downloadModel(TaskModel model) async {
  if (_downloaded[model.sha256] case final bytes?) return bytes;
  final data = await NetworkAssetBundle(model.url).load('');
  final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
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

  /// A model file of the user's own, as MediaPipe Studio's Upload.
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
