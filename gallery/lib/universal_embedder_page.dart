import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mediapipe_retrieval/mediapipe_retrieval.dart';

import 'catalog.dart';
import 'live/task_settings.dart';
import 'live/task_settings_panel.dart';
import 'main.dart' show GalleryAssets;
import 'ui/components.dart';
import 'ui/design.dart';
import 'ui/similarity.dart';
import 'ui/workspace.dart';

/// The similarity the journey test reads.
const universalSimilarityKey = ValueKey('universal-similarity-value');

/// What one of the two inputs holds.
enum UniversalInputKind {
  text('Text'),
  image('Image');

  const UniversalInputKind(this.label);
  final String label;
}

/// Universal Embedder on two inputs, each a text or an image, and the cosine
/// similarity of their embeddings in Google's one multimodal space. Google's
/// 388 MB EmbeddingGemma 2 model downloads on first use.
class UniversalEmbedderPage extends StatefulWidget {
  const UniversalEmbedderPage({
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
  State<UniversalEmbedderPage> createState() => _UniversalEmbedderPageState();
}

/// One of the two inputs: its text, and its image, which the task embeds as
/// it is encoded.
final class _Slot {
  _Slot(this.kind, {String text = '', String? sample})
    : controller = TextEditingController(text: text),
      image = SimilaritySlot(sample: sample);

  UniversalInputKind kind;
  final TextEditingController controller;
  final SimilaritySlot<Uint8List> image;
}

class _UniversalEmbedderPageState extends State<UniversalEmbedderPage>
    with
        RevisionedState,
        SimilarityState<UniversalEmbedderPage, Uint8List, UniversalEmbedder> {
  static const _id = 'universal';

  late final List<Delegate> _delegates = widget.task
      .capabilities(widget.platform)
      .supportedDelegates
      .toList();
  late final Delegate _delegate = preferredDelegate(_delegates);
  late final TaskSettingValues _values = TaskSettingValues(
    widget.task.runtimeId,
  );
  late final List<TaskSetting> _settings =
      taskSettings[widget.task.runtimeId] ?? const [];

  /// A sentence and the photo it describes, so the page opens on a
  /// cross-modal comparison.
  final _slots = [
    _Slot(
      UniversalInputKind.text,
      text: 'A dog running across the grass with a ball.',
    ),
    _Slot(UniversalInputKind.image, sample: 'dog.jpg'),
  ];

  String? _modelStatus;

  @override
  String get id => _id;

  @override
  Future<XFile?> Function()? get imagePicker => widget.imagePicker;

  @override
  void initState() {
    super.initState();
    for (final slot in _slots) {
      if (slot.image.sample case final sample?) {
        unawaited(chooseSample(slot.image, sample));
      }
    }
  }

  @override
  void dispose() {
    for (final slot in _slots) {
      slot.controller.dispose();
    }
    super.dispose();
  }

  @override
  Future<Uint8List> decodeImage(Uint8List bytes) async => bytes;

  @override
  Future<UniversalEmbedder> openEmbedder() async {
    setState(
      () => _modelStatus =
          'Loading ${widget.task.modelFile}; the first run downloads it '
          '(388 MB).',
    );
    try {
      return await UniversalEmbedder.create(
        UniversalEmbedderOptions(
          modelPath: await GalleryAssets.downloadedModelPath(widget.task.model),
          delegate: _delegate,
          l2Normalize: _values.on('l2Normalize'),
        ),
      );
    } finally {
      if (mounted) setState(() => _modelStatus = null);
    }
  }

  @override
  Future<void> disposeEmbedder(UniversalEmbedder embedder) =>
      embedder.dispose();

  /// Embeds both inputs and compares them.
  void _compare() {
    compare((embedder) async {
      final embeddings = <Embedding>[];
      for (final slot in _slots) {
        final result = switch (slot.kind) {
          UniversalInputKind.text => await embedder.embedText(
            slot.controller.text,
          ),
          UniversalInputKind.image => await embedder.embedImage(
            slot.image.input ?? (throw StateError('Choose an image first.')),
          ),
        };
        embeddings.add(result.embeddings.first);
      }
      return (
        similarity: UniversalEmbedder.cosineSimilarity(
          embeddings[0],
          embeddings[1],
        ),
        dimensions: embeddings.first.length,
        ranOn: 'CPU',
      );
    });
  }

  void _setSetting(String key, Object value) {
    setState(() => _values[key] = value);
    closeEmbedder();
    if (similarity != null) _compare();
  }

  Widget _panel() => ListenableBuilder(
    listenable: revision,
    builder: (context, _) => TaskSettingsPanel(
      settings: _settings,
      values: _values,
      delegates: _delegates,
      delegate: _delegate,
      enabled: !busy,
      onChanged: _setSetting,
      onDelegate: (_) {},
      models: const [],
      model: null,
      uploaded: null,
      modelStatus: _modelStatus,
      onModel: (_) {},
      onUpload: null,
      bundledModel: widget.task.modelFile,
      standardModel: 'EmbeddingGemma 2 (text and vision)',
    ),
  );

  @override
  Widget build(BuildContext context) {
    final c = GalleryColors.of(context);
    return TaskWorkspace(
      title: widget.task.title,
      onOpenMenu: widget.onOpenMenu,
      settings: _panel(),
      children: [
        TaskToolbar(task: widget.task),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 640) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _slot(context, 0)),
                  const SizedBox(width: 20),
                  Expanded(child: _slot(context, 1)),
                ],
              );
            }
            return Column(
              children: [
                _slot(context, 0),
                const SizedBox(height: 18),
                _slot(context, 1),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        TaskRunRow(
          button: PrimaryButton(
            key: const ValueKey('$_id-compare'),
            icon: LucideIcons.play,
            label: 'Compare',
            onPressed: busy ? null : _compare,
          ),
          busy: busy,
          milliseconds: milliseconds,
        ),
        if (_modelStatus case final status?) ...[
          const SizedBox(height: 12),
          Text(
            status,
            style: TextStyle(color: c.muted, fontSize: Sizes.xs),
          ),
        ],
        const SizedBox(height: 16),
        ...similarityResults(context),
      ],
    );
  }

  /// One input: its kind, and the text field or the sample chips, Upload
  /// button and picture.
  Widget _slot(BuildContext context, int index) {
    final c = GalleryColors.of(context);
    final slot = _slots[index];
    final number = index + 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Eyebrow('Input $number')),
            Segmented<UniversalInputKind>(
              semanticsIdentifier: '$_id-$number-kind',
              segments: [
                for (final kind in UniversalInputKind.values)
                  (
                    value: kind,
                    label: kind.label,
                    icon: null,
                    key: ValueKey('$_id-$number-${kind.name}'),
                  ),
              ],
              selected: slot.kind,
              onChanged: (kind) => setState(() => slot.kind = kind),
            ),
          ],
        ),
        const SizedBox(height: 10),
        switch (slot.kind) {
          UniversalInputKind.text => TextField(
            key: ValueKey('$_id-$number-text'),
            controller: slot.controller,
            minLines: 3,
            maxLines: 6,
            style: TextStyle(color: c.text, fontSize: Sizes.md, height: 1.45),
            decoration: const InputDecoration(labelText: 'Text'),
          ),
          UniversalInputKind.image => imageSlot(
            context,
            number: number,
            slot: slot.image,
            height: math.min(MediaQuery.sizeOf(context).height * .3, 260),
          ),
        },
      ],
    );
  }
}
