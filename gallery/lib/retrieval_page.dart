import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mediapipe_retrieval/mediapipe_retrieval.dart';

import 'catalog.dart';
import 'live/task_settings.dart';
import 'live/task_settings_panel.dart';
import 'main.dart' show GalleryAssets;
import 'ui/components.dart';
import 'ui/design.dart';
import 'ui/workspace.dart';

/// The best match the journey test reads.
const retrievalTopKey = ValueKey('retrieval-top');

/// The documents the page opens with: six short texts on distinct topics,
/// the corpus the package's reference test runs against Google's Python API.
const retrievalSampleDocuments = [
  'A dog chases a ball across the park on a sunny afternoon.',
  'Whisk the eggs with sugar, then fold in the flour to make the cake batter.',
  'The quarterly budget review moved the marketing spend into the next fiscal '
      'year.',
  'Astronomers photographed a spiral galaxy two hundred million light years '
      'away.',
  'Fixing a flat bicycle tire takes a patch kit, a pump and ten minutes.',
  'The cat slept on the warm windowsill while rain tapped the glass.',
];

/// Semantic Retriever on typed input: a handful of documents indexed on the
/// device and searched by meaning, with the nearest ones and their scores.
/// Google's 388 MB EmbeddingGemma 2 model downloads on first use.
class RetrievalPage extends StatefulWidget {
  const RetrievalPage({
    super.key,
    required this.task,
    required this.platform,
    this.onOpenMenu,
  });

  final GalleryTask task;
  final TaskPlatform platform;
  final VoidCallback? onOpenMenu;

  @override
  State<RetrievalPage> createState() => _RetrievalPageState();
}

class _RetrievalPageState extends State<RetrievalPage> with RevisionedState {
  late final String _id = widget.task.runtimeId;
  late final TaskSettingValues _values = TaskSettingValues(_id);
  late final List<TaskSetting> _settings = taskSettings[_id] ?? const [];
  late final List<Delegate> _delegates = widget.task
      .capabilities(widget.platform)
      .supportedDelegates
      .toList();
  late final Delegate _delegate = preferredDelegate(_delegates);

  final _documents = TextEditingController(
    text: retrievalSampleDocuments.join('\n'),
  );
  final _query = TextEditingController(text: 'A puppy playing fetch outside.');

  UniversalEmbedder? _embedder;
  SemanticRetriever? _retriever;

  /// The documents in the index, so an unchanged corpus is not re-embedded.
  List<String>? _indexed;
  bool _busy = false;
  String? _error;
  String? _modelStatus;
  RetrievalResult? _result;
  int? _indexedCount;
  double? _milliseconds;

  @override
  void dispose() {
    unawaited(_close());
    _documents.dispose();
    _query.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    final retriever = _retriever;
    final embedder = _embedder;
    _retriever = null;
    _embedder = null;
    _indexed = null;
    await retriever?.dispose();
    await embedder?.dispose();
  }

  List<String> _lines() => [
    for (final line in _documents.text.split('\n'))
      if (line.trim().isNotEmpty) line.trim(),
  ];

  Future<SemanticRetriever> _open() async {
    if (_retriever case final retriever?) return retriever;
    setState(
      () => _modelStatus =
          'Loading ${widget.task.modelFile}; the first run downloads it '
          '(388 MB).',
    );
    try {
      final embedder = _embedder ??= await UniversalEmbedder.create(
        UniversalEmbedderOptions(
          modelPath: await GalleryAssets.downloadedModelPath(widget.task.model),
          delegate: _delegate,
        ),
      );
      return _retriever = await SemanticRetriever.create(
        SemanticRetrieverOptions(embedder: embedder),
      );
    } finally {
      if (mounted) setState(() => _modelStatus = null);
    }
  }

  Future<void> _search() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final retriever = await _open();
      final lines = _lines();
      if (lines.isEmpty) throw StateError('Add a document to search.');
      final clock = Stopwatch()..start();
      if (_indexed == null || !_sameLines(_indexed!, lines)) {
        await retriever.deleteAll();
        for (final (i, line) in lines.indexed) {
          await retriever.insertDocument('doc-${i + 1}', line);
        }
        _indexed = lines;
      }
      _result = await retriever.retrieve(
        _query.text,
        limit: _values.count('limit'),
        minSimilarity: _values.share('minSimilarity'),
      );
      _indexedCount = lines.length;
      _milliseconds = clock.elapsedMicroseconds / 1000;
    } on Object catch (error) {
      _error = '$error';
      _result = null;
    }
    if (mounted) setState(() => _busy = false);
  }

  static bool _sameLines(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _setSetting(String key, Object value) {
    setState(() => _values[key] = value);
    if (_result != null && !_busy) unawaited(_search());
  }

  Widget _panel() => ListenableBuilder(
    listenable: revision,
    builder: (context, _) => TaskSettingsPanel(
      settings: _settings,
      values: _values,
      delegates: _delegates,
      delegate: _delegate,
      enabled: !_busy,
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

  Widget _field(
    TextEditingController controller,
    String label, {
    required int lines,
    Key? key,
  }) {
    final c = GalleryColors.of(context);
    return TextField(
      key: key,
      controller: controller,
      minLines: lines,
      maxLines: lines + 6,
      style: TextStyle(color: c.text, fontSize: Sizes.md, height: 1.45),
      decoration: InputDecoration(labelText: label),
    );
  }

  Widget _results(BuildContext context) {
    final c = GalleryColors.of(context);
    final result = _result;
    if (result == null) {
      return const OutputCard(
        title: 'Results',
        empty: 'Search to see which documents come closest to the query.',
      );
    }
    final lines = _indexed ?? const <String>[];
    String text(RetrievalRecord record) {
      final index = int.tryParse(record.id.replaceFirst('doc-', ''));
      return index != null && index <= lines.length
          ? lines[index - 1]
          : record.text;
    }

    return OutputCard(
      title: 'Results',
      count: '${result.records.length} of ${_indexedCount ?? 0} documents',
      child: result.records.isEmpty
          ? Text(
              'No document scores at least the minimum similarity.',
              style: TextStyle(color: c.muted, fontSize: Sizes.sm),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (i, record) in result.records.indexed) ...[
                  if (i > 0) const SizedBox(height: 14),
                  Semantics(
                    identifier: i == 0 ? 'retrieval-top' : null,
                    container: i == 0,
                    child: Text(
                      text(record),
                      key: i == 0 ? retrievalTopKey : null,
                      style: TextStyle(
                        color: c.text,
                        fontSize: i == 0 ? 18 : Sizes.md,
                        fontWeight: i == 0 ? FontWeight.w600 : FontWeight.w400,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  ScoreBars([
                    (name: record.id, value: record.score.clamp(0, 1)),
                  ]),
                ],
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = GalleryColors.of(context);
    return TaskWorkspace(
      title: widget.task.title,
      onOpenMenu: widget.onOpenMenu,
      settings: _panel(),
      children: [
        TaskToolbar(task: widget.task),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Eyebrow('Documents, one per line'),
              const SizedBox(height: 14),
              _field(
                _documents,
                'Documents',
                lines: 6,
                key: const ValueKey('retrieval-documents'),
              ),
              const SizedBox(height: 12),
              _field(
                _query,
                'Query',
                lines: 1,
                key: const ValueKey('retrieval-query'),
              ),
              const SizedBox(height: 16),
              TaskRunRow(
                busy: _busy,
                milliseconds: _milliseconds,
                button: PrimaryButton(
                  key: const ValueKey('retrieval-search'),
                  icon: LucideIcons.search,
                  label: 'Search',
                  onPressed: _busy ? null : _search,
                ),
              ),
              if (_modelStatus case final status?) ...[
                const SizedBox(height: 12),
                Text(
                  status,
                  style: TextStyle(color: c.muted, fontSize: Sizes.xs),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 22),
        if (_error case final error?)
          TaskErrorCard(error)
        else
          _results(context),
      ],
    );
  }
}
