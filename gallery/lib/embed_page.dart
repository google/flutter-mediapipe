import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:mediapipe_vision/mediapipe_vision.dart';

import 'catalog.dart';
import 'live/still_image.dart';
import 'live/task_models.dart';
import 'live/task_settings.dart';
import 'live/task_settings_panel.dart';
import 'ui/components.dart';
import 'ui/similarity.dart';
import 'ui/workspace.dart';

/// Image Embedder as Google's demo shows it: two still images, each a sample
/// or an upload, and the cosine similarity of their embeddings. Choosing an
/// image, the model, the delegate or a setting compares them again.
class EmbedPage extends StatefulWidget {
  const EmbedPage({
    super.key,
    required this.task,
    required this.platform,
    this.imagePicker,
    this.onOpenMenu,
  });

  final GalleryTask task;
  final TaskPlatform platform;

  /// Lets device tests upload a fixture through the real Upload buttons.
  final Future<XFile?> Function()? imagePicker;
  final VoidCallback? onOpenMenu;

  @override
  State<EmbedPage> createState() => _EmbedPageState();
}

class _EmbedPageState extends State<EmbedPage>
    with
        RevisionedState,
        ModelSelectionState,
        SimilarityState<EmbedPage, VisionImage, ImageEmbedder> {
  static const _id = 'image-embedder';

  late final List<Delegate> _delegates =
      widget.task.capabilities(widget.platform).supportedDelegates.toList()
        ..sort((a, b) => a.index.compareTo(b.index));
  late Delegate _delegate = preferredDelegate(_delegates);
  late final TaskSettingValues _values = TaskSettingValues(
    widget.task.runtimeId,
  );
  late final List<TaskSetting> _settings =
      taskSettings[widget.task.runtimeId] ?? const [];
  late final List<TaskModel> _models =
      taskModels[widget.task.runtimeId] ?? const [];

  /// Dog and Cat, so the page opens with a comparison on screen.
  final _slots = [
    SimilaritySlot<VisionImage>(sample: 'dog.jpg'),
    SimilaritySlot<VisionImage>(sample: 'cat.png'),
  ];

  @override
  String get id => _id;

  @override
  Future<XFile?> Function()? get imagePicker => widget.imagePicker;

  @override
  void initState() {
    super.initState();
    for (final slot in _slots) {
      unawaited(chooseSample(slot, slot.sample!));
    }
  }

  @override
  Future<VisionImage> decodeImage(Uint8List bytes) async =>
      (await decodeStillImage(bytes)).input;

  @override
  void imageShown() => _compare();

  /// Embeds both images and compares them, once both have decoded.
  void _compare() {
    final first = _slots[0].input;
    final second = _slots[1].input;
    if (first == null || second == null) return;
    compare((embedder) async {
      final a = (await embedder.embed(first)).embeddings.first;
      final b = (await embedder.embed(second)).embeddings.first;
      return (
        similarity: ImageEmbedder.cosineSimilarity(a, b),
        dimensions: a.floatEmbedding?.length ?? a.quantizedEmbedding?.length,
        ranOn: _delegate.name.toUpperCase(),
      );
    });
  }

  @override
  Future<ImageEmbedder> openEmbedder() async {
    final bytes = modelBytes;
    Future<ImageEmbedder> create(Delegate delegate) => ImageEmbedder.create(
      ImageEmbedderOptions(
        delegate: delegate,
        model: bytes == null ? widget.task.model : null,
        modelBytes: bytes,
        runningMode: RunningMode.image,
        l2Normalize: _values.on('l2Normalize'),
        quantize: _values.on('quantize'),
      ),
    );
    try {
      return await create(_delegate);
    } on Object {
      // GPU is only the default; a platform that refuses it gets CPU.
      if (_delegate != Delegate.gpu) rethrow;
      if (mounted) setState(() => _delegate = Delegate.cpu);
      return create(Delegate.cpu);
    }
  }

  @override
  Future<void> disposeEmbedder(ImageEmbedder embedder) => embedder.dispose();

  void _reopen() {
    closeEmbedder();
    _compare();
  }

  void _setSetting(String key, Object value) {
    setState(() => _values[key] = value);
    _reopen();
  }

  void _setDelegate(Delegate delegate) {
    if (delegate == _delegate) return;
    setState(() => _delegate = delegate);
    _reopen();
  }

  @override
  void modelChanged() => _reopen();

  Widget _panel() => ListenableBuilder(
    listenable: revision,
    builder: (context, _) => TaskSettingsPanel(
      settings: _settings,
      values: _values,
      delegates: _delegates,
      delegate: _delegate,
      // Every change queues behind the comparison running, so nothing
      // needs to wait for it.
      enabled: true,
      onChanged: _setSetting,
      onDelegate: _setDelegate,
      models: _models,
      model: model,
      uploaded: uploaded,
      modelStatus: modelStatus,
      onModel: chooseModel,
      onUpload: uploadModel,
      bundledModel: widget.task.modelFile,
      standardModel: standardModelNames[widget.task.runtimeId] ?? 'Standard',
    ),
  );

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    return TaskWorkspace(
      title: widget.task.title,
      onOpenMenu: widget.onOpenMenu,
      settings: _panel(),
      children: [
        TaskToolbar(task: widget.task),
        LayoutBuilder(
          builder: (context, constraints) {
            // Side by side, as Google's demo shows them, while each image's
            // chips still fit beside its Upload button.
            if (constraints.maxWidth >= 540) {
              final width = (constraints.maxWidth - 20) / 2;
              final height = math.min(width, 340.0);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _slot(context, 0, height)),
                  const SizedBox(width: 20),
                  Expanded(child: _slot(context, 1, height)),
                ],
              );
            }
            // Stacked, short enough that a phone shows both images and
            // the similarity together.
            final height = (screen.height * .19).clamp(130.0, 240.0);
            return Column(
              children: [
                _slot(context, 0, height),
                const SizedBox(height: 18),
                _slot(context, 1, height),
              ],
            );
          },
        ),
        ...similarityResults(context),
      ],
    );
  }

  /// One image, under its label.
  Widget _slot(BuildContext context, int index, double height) {
    final number = index + 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Eyebrow('Image $number'),
        const SizedBox(height: 10),
        imageSlot(context, number: number, slot: _slots[index], height: height),
      ],
    );
  }
}
