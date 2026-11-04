import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mediapipe_decision/mediapipe_decision.dart';

import 'catalog.dart';
import 'live/task_models.dart';
import 'live/task_settings.dart';
import 'live/task_settings_panel.dart';
import 'main.dart' show GalleryAssets;
import 'ui/components.dart';
import 'ui/design.dart';
import 'ui/workspace.dart';

/// The answer the journey test reads: Yes or No, the winning option, or the
/// expected score.
const decisionAnswerKey = ValueKey('decision_answer');

/// The kinds of question Google's Decision Maker answers.
enum DecisionKind {
  boolean('Yes / No'),
  choice('Choice'),
  score('Score');

  const DecisionKind(this.label);
  final String label;
}

/// Decision Maker on typed input: a question about the text, answered with
/// Google's calibrated probabilities, beside MediaPipe Studio's settings.
/// Google's 678 MB model downloads on first use: verified into the model
/// cache on native platforms, and fetched by Google's runtime in browsers.
class DecisionPage extends StatefulWidget {
  const DecisionPage({
    super.key,
    required this.task,
    required this.platform,
    this.onOpenMenu,
  });

  final GalleryTask task;

  /// The platform the capability query evaluated, which decides the
  /// delegate: the CPU on the desktop, the GPU in browsers (UP-049).
  final TaskPlatform platform;
  final VoidCallback? onOpenMenu;

  @override
  State<DecisionPage> createState() => _DecisionPageState();
}

class _DecisionPageState extends State<DecisionPage> with RevisionedState {
  late final String _id = widget.task.runtimeId;
  late final TaskSettingValues _values = TaskSettingValues(_id);
  late final List<TaskSetting> _settings = taskSettings[_id] ?? const [];
  // Only the alternatives the package accepts here: browsers run neither
  // GLiNER2.5-Decide model (UP-055).
  late final List<TaskModel> _models = [
    for (final model in taskModels[_id] ?? const <TaskModel>[])
      if (decisionRunsModel(widget.platform, model)) model,
  ];
  late final List<Delegate> _delegates = widget.task
      .capabilities(widget.platform)
      .supportedDelegates
      .toList();
  late final Delegate _delegate = preferredDelegate(_delegates);

  final _text = TextEditingController(
    text: 'My order arrived broken and I want my money back.',
  );
  final _condition = TextEditingController(
    text: 'The customer wants a refund.',
  );
  final _options = TextEditingController(
    text:
        'shipping: A problem with delivery or a damaged package\n'
        'billing: A question about a charge or a refund\n'
        'account: A question about the account or its settings\n'
        'other: Anything else',
  );
  final _rubric = TextEditingController(
    text: 'very unhappy\nunhappy\nneutral\nhappy\nvery happy',
  );

  DecisionKind _kind = DecisionKind.boolean;
  TaskModel? _model;
  String? _modelStatus;
  DecisionMaker? _task;
  bool _busy = false;
  String? _error;
  Object? _result;
  double? _milliseconds;

  @override
  void dispose() {
    unawaited(_close());
    for (final controller in [_text, _condition, _options, _rubric]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _close() async {
    final task = _task;
    _task = null;
    await task?.dispose();
  }

  /// The chosen model's pin: the catalog's unless another was chosen.
  DownloadAsset get _pin => switch (_model) {
    final model? => model.pin,
    null => widget.task.model,
  };

  Future<DecisionMaker> _open() async {
    if (_task case final task?) return task;
    final pin = _pin;
    setState(
      () => _modelStatus =
          'Loading ${Uri.parse(pin.url).pathSegments.last}; the first run '
          'downloads it.',
    );
    try {
      return _task = await DecisionMaker.create(
        DecisionMakerOptions(
          modelPath: await GalleryAssets.downloadedModelPath(pin),
          delegate: _delegate,
        ),
      );
    } finally {
      if (mounted) setState(() => _modelStatus = null);
    }
  }

  /// The options as `key: description` lines.
  Map<String, String> _criteria() => {
    for (final line in _options.text.split('\n'))
      if (line.trim().isNotEmpty)
        line.split(':').first.trim(): line.contains(':')
            ? line.substring(line.indexOf(':') + 1).trim()
            : '',
  };

  List<String> _levels() => [
    for (final line in _rubric.text.split('\n'))
      if (line.trim().isNotEmpty) line.trim(),
  ];

  Future<void> _run() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final task = await _open();
      final clock = Stopwatch()..start();
      final text = _text.text;
      _result = switch (_kind) {
        DecisionKind.boolean => await task.evaluateBoolean(
          text,
          BooleanQuestion(
            _condition.text,
            threshold: _values.share('threshold'),
            normalizePrior: _values.on('normalizePrior'),
          ),
        ),
        DecisionKind.choice => await task.evaluateChoice(
          text,
          ChoiceQuestion(
            _criteria(),
            normalizePrior: _values.on('normalizePrior'),
          ),
        ),
        DecisionKind.score => await task.evaluateScore(
          text,
          ScoreQuestion(_levels()),
        ),
      };
      _milliseconds = clock.elapsedMicroseconds / 1000;
    } on Object catch (error) {
      _error = '$error';
      _result = null;
    }
    if (mounted) setState(() => _busy = false);
  }

  void _setSetting(String key, Object value) {
    setState(() => _values[key] = value);
    if (_result != null && !_busy) unawaited(_run());
  }

  Future<void> _chooseModel(TaskModel? model) async {
    setState(() {
      _model = model;
      _result = null;
    });
    await _close();
    if (mounted) await _run();
  }

  Widget _panel() => ListenableBuilder(
    listenable: revision,
    builder: (context, _) => TaskSettingsPanel(
      settings: [
        for (final setting in _settings)
          if (setting.key != 'threshold' || _kind == DecisionKind.boolean)
            if (setting.key != 'normalizePrior' || _kind != DecisionKind.score)
              setting,
      ],
      values: _values,
      delegates: _delegates,
      delegate: _delegate,
      enabled: !_busy,
      onChanged: _setSetting,
      onDelegate: (_) {},
      models: _models,
      model: _model,
      uploaded: null,
      modelStatus: _modelStatus,
      onModel: _chooseModel,
      onUpload: null,
      bundledModel: widget.task.modelFile,
      standardModel: 'Laya (256 tokens)',
    ),
  );

  Widget _field(TextEditingController controller, String label, {int? lines}) {
    final c = GalleryColors.of(context);
    return TextField(
      controller: controller,
      minLines: lines ?? 2,
      maxLines: (lines ?? 2) + 4,
      style: TextStyle(color: c.text, fontSize: Sizes.md, height: 1.45),
      decoration: InputDecoration(labelText: label),
    );
  }

  Widget _question() => switch (_kind) {
    DecisionKind.boolean => _field(_condition, 'Condition', lines: 1),
    DecisionKind.choice => _field(
      _options,
      'Options, one per line: key: description',
      lines: 4,
    ),
    DecisionKind.score => _field(_rubric, 'Levels, lowest first', lines: 5),
  };

  Widget _answer(BuildContext context) {
    final c = GalleryColors.of(context);
    final big = TextStyle(
      color: c.text,
      fontSize: 22,
      fontWeight: FontWeight.w600,
    );
    final muted = TextStyle(color: c.muted, fontSize: Sizes.sm);
    switch (_result) {
      case final BooleanResult result:
        return OutputCard(
          title: 'Answer',
          count: 'confidence ${result.confidence.toStringAsFixed(2)}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                result.value ? 'Yes' : 'No',
                key: decisionAnswerKey,
                style: big,
              ),
              const SizedBox(height: 14),
              ScoreBars([
                (name: 'Probability true', value: result.probabilityTrue),
              ]),
            ],
          ),
        );
      case final ChoiceResult result:
        return OutputCard(
          title: 'Answer',
          count: 'confidence ${result.confidence.toStringAsFixed(2)}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(result.selectedKey, key: decisionAnswerKey, style: big),
              const SizedBox(height: 6),
              Text(
                'Prediction set: ${result.predictionSet.join(', ')}',
                style: muted,
              ),
              const SizedBox(height: 14),
              ScoreBars([
                for (final MapEntry(:key, :value)
                    in result.probabilities.entries)
                  (name: key, value: value),
              ]),
            ],
          ),
        );
      case final ScoreResult result:
        final levels = _levels();
        return OutputCard(
          title: 'Answer',
          count: 'confidence ${result.confidence.toStringAsFixed(2)}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                result.expectedScore.toStringAsFixed(2),
                key: decisionAnswerKey,
                style: big,
              ),
              const SizedBox(height: 6),
              Text(
                'Expected level, from 0 (${levels.first}) to '
                '${levels.length - 1} (${levels.last})',
                style: muted,
              ),
              const SizedBox(height: 14),
              ScoreBars([
                for (final (i, probability) in result.probabilities.indexed)
                  (
                    name: i < levels.length ? levels[i] : '$i',
                    value: probability,
                  ),
              ]),
            ],
          ),
        );
    }
    return const OutputCard(
      title: 'Answer',
      empty: 'Ask the question to see what the model decides.',
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
        TaskToolbar(
          task: widget.task,
          leading: Segmented<DecisionKind>(
            segments: [
              for (final kind in DecisionKind.values)
                (
                  value: kind,
                  label: kind.label,
                  icon: null,
                  key: ValueKey('decision-${kind.name}'),
                ),
            ],
            selected: _kind,
            onChanged: _busy
                ? null
                : (kind) => setState(() {
                    _kind = kind;
                    _result = null;
                    _error = null;
                  }),
          ),
        ),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Eyebrow('Input'),
              const SizedBox(height: 14),
              _field(_text, 'Text', lines: 3),
              const SizedBox(height: 12),
              _question(),
              const SizedBox(height: 16),
              TaskRunRow(
                busy: _busy,
                milliseconds: _milliseconds,
                button: PrimaryButton(
                  icon: LucideIcons.play,
                  label: 'Ask',
                  onPressed: _busy ? null : _run,
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
          _answer(context),
      ],
    );
  }
}
