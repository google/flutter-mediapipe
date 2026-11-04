import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mediapipe_text/mediapipe_text.dart';

import 'catalog.dart';
import 'live/task_models.dart';
import 'live/task_settings.dart';
import 'live/task_settings_panel.dart';
import 'main.dart' show GalleryAssets;
import 'ui/components.dart';
import 'ui/design.dart';
import 'ui/workspace.dart';

/// The text the Proofreader or Summarizer wrote, which the journey test reads.
const generatedTextKey = ValueKey('generated_text');

/// A text task on typed input, laid out as the live demos are: the input and
/// its results beside the same settings panel, with MediaPipe Studio's
/// settings and model selection. The classic tasks and EmbeddingGemma score
/// or compare the input; the Proofreader and Summarizer write text, streamed
/// as Google generates it.
class TextPage extends StatefulWidget {
  const TextPage({super.key, required this.task, this.onOpenMenu});

  final GalleryTask task;
  final VoidCallback? onOpenMenu;

  @override
  State<TextPage> createState() => _TextPageState();
}

/// One line of a result: a label and its score, drawn as a bar.
typedef _Row = ({String label, double score});

/// EmbeddingGemma's uses, in the order the Task Type setting lists them.
const _gemmaTypes = [
  EmbeddingType.semanticSimilarity,
  EmbeddingType.retrievalQuery,
  EmbeddingType.questionAnswering,
  EmbeddingType.factChecking,
  EmbeddingType.codeRetrieval,
  EmbeddingType.classification,
  EmbeddingType.clustering,
];

/// The uses that pair a query with a document: the first text is the query
/// and the second the document.
const _pairTypes = {
  EmbeddingType.retrievalQuery,
  EmbeddingType.questionAnswering,
  EmbeddingType.factChecking,
  EmbeddingType.codeRetrieval,
};

class _TextPageState extends State<TextPage>
    with RevisionedState, ModelSelectionState {
  late final String _id = widget.task.runtimeId;
  late final TaskSettingValues _values = TaskSettingValues(_id);
  late final List<TaskSetting> _settings = taskSettings[_id] ?? const [];
  late final List<TaskModel> _models = taskModels[_id] ?? const [];
  late final _first = TextEditingController(text: _samples[_id]!.$1);
  late final _second = TextEditingController(text: _samples[_id]!.$2);

  /// The open task, rebuilt when a setting or the model changes.
  Object? _task;
  bool _busy = false;
  String? _error;
  List<_Row>? _rows;
  double? _similarity;

  /// What the Proofreader or Summarizer wrote so far, and the Proofreader's
  /// edits once it finished.
  String? _generated;
  List<ProofreadingCorrection>? _corrections;
  double? _milliseconds;

  // The Proofreader's and Summarizer's samples are cases of Google's
  // references, so what the models write for them is known on every platform.
  static const _samples = <String, (String, String)>{
    'text_classifier': ('I loved this movie, it was wonderful!', ''),
    'language_detector': ('Merci beaucoup pour votre aide.', ''),
    'text_embedder': (
      'The weather is lovely today.',
      "It's a beautiful sunny day.",
    ),
    'embedding_gemma': (
      'The weather is lovely today.',
      "It's a beautiful sunny day.",
    ),
    'text_proofreader': (
      'Our team have finished the first version of the app. We was testing '
          'it yesterday when we notice a small problem. The report explain '
          'how to reproduce the issue, and include a screenshot. Please let '
          'me knows if you needs any more details.',
      '',
    ),
    'text_summarizer': (
      'The team met on Monday to plan the next app release. Maya will '
          'finish the camera interface by Thursday. Leo will investigate the '
          'startup crash and send a fix for review on Wednesday. Testing '
          'begins on Friday, and the release is scheduled for the following '
          'Tuesday if no critical bugs remain. The team decided to postpone '
          'the new settings screen until the next release.',
      '',
    ),
  };

  bool get _embedder => _id == 'text_embedder' || _id == 'embedding_gemma';
  bool get _generative => _id == 'text_proofreader' || _id == 'text_summarizer';

  @override
  void dispose() {
    unawaited(_close());
    _first.dispose();
    _second.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    final task = _task;
    _task = null;
    switch (task) {
      case TextClassifier task:
        await task.dispose();
      case LanguageDetector task:
        await task.dispose();
      case TextEmbedder task:
        await task.dispose();
      case TextProofreader task:
        await task.dispose();
      case TextSummarizer task:
        await task.dispose();
    }
  }

  Future<Object> _open() async {
    if (_task case final task?) return task;
    // The bundled model by its pin, as an app passes it, unless a chosen or
    // uploaded one replaces it.
    final bytes = modelBytes;
    final model = bytes == null ? widget.task.model : null;
    return _task = switch (_id) {
      'text_classifier' => await TextClassifier.create(
        TextClassifierOptions(
          model: model,
          modelBytes: bytes,
          maxResults: _values.count('maxResults'),
          scoreThreshold: _values.share('scoreThreshold'),
        ),
      ),
      'language_detector' => await LanguageDetector.create(
        LanguageDetectorOptions(
          model: model,
          modelBytes: bytes,
          maxResults: _values.count('maxResults'),
          scoreThreshold: _values.share('scoreThreshold'),
        ),
      ),
      'text_proofreader' => await TextProofreader.create(
        TextProofreaderOptions(model: widget.task.model),
      ),
      'text_summarizer' => await TextSummarizer.create(
        TextSummarizerOptions(
          model: widget.task.model,
          mode: _values.choice('mode') == 1
              ? TextSummarizerMode.tldr
              : TextSummarizerMode.keypoints,
        ),
      ),
      'embedding_gemma' => await TextEmbedder.create(
        TextEmbedderOptions(
          modelBytes: bytes,
          // A file on native platforms; in browsers its URL, which Google's
          // runtime fetches itself, so 184 MB never passes through Dart.
          modelPath: bytes == null
              ? await GalleryAssets.modelPath(widget.task.model)
              : null,
          l2Normalize: _values.on('l2Normalize'),
          quantize: _values.on('quantize'),
        ),
      ),
      _ => await TextEmbedder.create(
        TextEmbedderOptions(
          model: model,
          modelBytes: bytes,
          l2Normalize: _values.on('l2Normalize'),
          quantize: _values.on('quantize'),
        ),
      ),
    };
  }

  /// How EmbeddingGemma formats each text for the chosen use; the classic
  /// embedder takes none.
  (TextFormatContext?, TextFormatContext?) _formats() {
    if (_id != 'embedding_gemma') return (null, null);
    final type = _gemmaTypes[_values.choice('taskType')];
    final pair = _pairTypes.contains(type);
    return (
      TextFormatContext(taskType: type),
      TextFormatContext(
        taskType: type == EmbeddingType.retrievalQuery
            ? EmbeddingType.retrievalDocument
            : type,
        role: pair ? TextRole.document : TextRole.query,
      ),
    );
  }

  Future<void> _run() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final task = await _open();
      final clock = Stopwatch()..start();
      final stream = _generative && _values.on('stream');
      switch (task) {
        case TextClassifier task:
          final result = await task.classify(_first.text);
          _rows = [
            for (final category in result.classifications.first.categories)
              (label: category.categoryName ?? '', score: category.score),
          ];
        case LanguageDetector task:
          final result = await task.detect(_first.text);
          _rows = [
            for (final prediction in result.predictions)
              (label: prediction.languageCode, score: prediction.probability),
          ];
        case TextEmbedder task:
          final (first, second) = _formats();
          final a = await task.embed(_first.text, formatContext: first);
          final b = await task.embed(_second.text, formatContext: second);
          _similarity = TextEmbedder.cosineSimilarity(
            a.embeddings.first,
            b.embeddings.first,
          );
        case TextProofreader task:
          var written = '';
          setState(() {
            _generated = written;
            _corrections = null;
          });
          if (stream) {
            await for (final update in task.proofreadStream(_first.text)) {
              written += update.chunk ?? '';
              if (!mounted) return;
              setState(() {
                _generated = written;
                if (update.done) _corrections = update.corrections;
              });
            }
          } else {
            final result = await task.proofread(_first.text);
            _generated = result.proofreadText ?? '';
            _corrections = result.corrections;
          }
        case TextSummarizer task:
          var written = '';
          setState(() => _generated = written);
          if (stream) {
            await for (final update in task.summarizeStream(_first.text)) {
              written += update.chunk ?? '';
              if (!mounted) return;
              setState(() => _generated = written);
            }
          } else {
            _generated = (await task.summarize(_first.text)).summary ?? '';
          }
      }
      _milliseconds = clock.elapsedMicroseconds / 1000;
    } on Object catch (error) {
      _error = '$error';
    }
    if (mounted) setState(() => _busy = false);
  }

  /// Rebuilds the task on the next run with the changed settings or model.
  Future<void> _reset() async {
    await _close();
    if (mounted) await _run();
  }

  void _setSetting(String key, Object value) {
    setState(() => _values[key] = value);
    // Streaming changes how the next run is shown, not the task.
    if (key == 'stream') return;
    unawaited(_reset());
  }

  @override
  void modelChanged() => unawaited(_reset());

  Widget _panel() => ListenableBuilder(
    listenable: revision,
    builder: (context, _) => TaskSettingsPanel(
      settings: _settings,
      values: _values,
      delegates: const [Delegate.cpu],
      delegate: Delegate.cpu,
      enabled: !_busy,
      onChanged: _setSetting,
      onDelegate: (_) {},
      models: _models,
      model: model,
      uploaded: uploaded,
      modelStatus: modelStatus,
      onModel: chooseModel,
      // Google's generative tasks read a `.litertlm` file, not bytes.
      onUpload: _generative ? null : uploadModel,
      bundledModel: widget.task.modelFile,
    ),
  );

  /// The Proofreader's segments: insertions, deletions and unchanged text.
  Widget _edits(BuildContext context, List<ProofreadingCorrection> edits) {
    final c = GalleryColors.of(context);
    final error = Theme.of(context).colorScheme.error;
    return Text.rich(
      TextSpan(
        children: [
          for (final edit in edits)
            TextSpan(
              text: edit.text,
              style: switch (edit.type) {
                ProofreadingCorrectionType.same => TextStyle(color: c.muted),
                ProofreadingCorrectionType.insertion => TextStyle(
                  color: c.teal,
                  fontWeight: FontWeight.w600,
                ),
                ProofreadingCorrectionType.deletion => TextStyle(
                  color: error,
                  decoration: TextDecoration.lineThrough,
                ),
              },
            ),
        ],
      ),
      style: TextStyle(fontSize: Sizes.sm, height: 1.5),
    );
  }

  /// The generated text and, for the Proofreader, its edits.
  OutputCard _generatedCard(BuildContext context) {
    final c = GalleryColors.of(context);
    final proofreader = _id == 'text_proofreader';
    final generated = _generated;
    String? count;
    if (generated != null && proofreader) {
      final edits = _corrections
          ?.where((edit) => edit.type != ProofreadingCorrectionType.same)
          .length;
      count = edits == null ? null : '$edits edit${edits == 1 ? '' : 's'}';
    } else if (generated != null) {
      final words = generated.trim().isEmpty
          ? 0
          : generated.trim().split(RegExp(r'\s+')).length;
      count = '$words word${words == 1 ? '' : 's'}';
    }
    final edits = _corrections ?? const <ProofreadingCorrection>[];
    return OutputCard(
      title: proofreader ? 'Corrected text' : 'Summary',
      count: count,
      empty: 'Run the task to see what the model writes.',
      child: generated == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  generated,
                  key: generatedTextKey,
                  style: TextStyle(
                    color: c.text,
                    fontSize: Sizes.md,
                    height: 1.5,
                  ),
                ),
                if (edits.any(
                  (edit) => edit.type != ProofreadingCorrectionType.same,
                )) ...[
                  const SizedBox(height: 18),
                  const Eyebrow('Edits'),
                  const SizedBox(height: 10),
                  _edits(context, edits),
                ],
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = GalleryColors.of(context);
    Widget field(TextEditingController controller, String label) => TextField(
      controller: controller,
      minLines: 3,
      maxLines: 6,
      style: TextStyle(color: c.text, fontSize: Sizes.md, height: 1.45),
      decoration: InputDecoration(labelText: label),
    );
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
              const Eyebrow('Input'),
              const SizedBox(height: 14),
              field(_first, _embedder ? 'First text' : 'Text'),
              if (_embedder) ...[
                const SizedBox(height: 12),
                field(_second, 'Second text'),
              ],
              const SizedBox(height: 16),
              TaskRunRow(
                busy: _busy,
                milliseconds: _milliseconds,
                button: PrimaryButton(
                  icon: LucideIcons.play,
                  label: _embedder ? 'Compare' : 'Run',
                  onPressed: _busy ? null : _run,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        if (_error case final error?)
          TaskErrorCard(error)
        else if (_embedder)
          OutputCard(
            title: 'Similarity',
            count: 'cosine',
            items: [
              if (_similarity case final similarity?)
                (name: 'Cosine similarity', value: similarity),
            ],
            empty: 'Compare two texts to see how alike they are.',
          )
        else if (_generative)
          _generatedCard(context)
        else
          OutputCard(
            title: _id == 'language_detector' ? 'Languages' : 'Categories',
            count: _rows == null
                ? null
                : '${_rows!.length} result${_rows!.length == 1 ? '' : 's'}',
            items: [
              for (final row in _rows ?? const <_Row>[])
                (name: row.label, value: row.score),
            ],
            empty: 'Run the task to see its results.',
          ),
        if (widget.task.gemmaModel) ...[
          const SizedBox(height: 22),
          const GemmaNotice(),
        ],
      ],
    );
  }
}
