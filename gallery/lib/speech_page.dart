import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mediapipe_audio/mediapipe_audio.dart';

import 'catalog.dart';
import 'live/task_settings.dart';
import 'live/task_settings_panel.dart';
import 'main.dart' show GalleryAssets;
import 'ui/components.dart';
import 'ui/design.dart';
import 'ui/workspace.dart';

/// The synthesized audio's length and word count the journey test reads.
const speechSummaryKey = ValueKey('speech-summary');

/// The text the page opens with, the package's reference utterance.
const speechSampleText = 'The quick brown fox jumps over the lazy dog.';

/// Text to Speech on typed input: the text spoken in a chosen voice, drawn
/// as its waveform with when each word is spoken. The gallery has no audio
/// player, so the speech is shown rather than played. Gradium's 87 MB Phonon
/// model, as Google's LiteRT community converted it, downloads on first use.
class SpeechPage extends StatefulWidget {
  const SpeechPage({
    super.key,
    required this.task,
    required this.platform,
    this.onOpenMenu,
  });

  final GalleryTask task;
  final TaskPlatform platform;
  final VoidCallback? onOpenMenu;

  @override
  State<SpeechPage> createState() => _SpeechPageState();
}

/// The delegates the page offers on [platform]: every one [task] supports
/// but the GPU. The page speaks with Phonon, whose bundle marks no GPU
/// section, so create refuses the GPU for it where the platform offers it
/// for Kokoro.
List<Delegate> speechPageDelegates(GalleryTask task, TaskPlatform platform) => [
  for (final delegate in task.capabilities(platform).supportedDelegates)
    if (delegate != Delegate.gpu) delegate,
];

class _SpeechPageState extends State<SpeechPage> with RevisionedState {
  late final String _id = widget.task.runtimeId;
  late final TaskSettingValues _values = TaskSettingValues(_id);
  late final List<TaskSetting> _settings = taskSettings[_id] ?? const [];
  late final List<Delegate> _delegates = speechPageDelegates(
    widget.task,
    widget.platform,
  );
  late final Delegate _delegate = preferredDelegate(_delegates);

  final _text = TextEditingController(text: speechSampleText);

  TextToSpeech? _task;

  /// The speaking rate [_task] was created with.
  double? _taskRate;

  /// The model's voices, listed once it has loaded.
  List<TextToSpeechVoice> _voices = const [];

  /// The chosen voice's id, or null for the model's default.
  String? _voice;
  bool _busy = false;
  String? _error;
  String? _modelStatus;
  TextToSpeechResult? _result;

  /// The text [_result] speaks, which its word timestamps index into.
  String _spoken = '';
  double? _milliseconds;

  double get _rate => speakingRateValues[_values.choice('speakingRate')];

  @override
  void dispose() {
    unawaited(_close());
    _text.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    final task = _task;
    _task = null;
    _taskRate = null;
    await task?.dispose();
  }

  Future<TextToSpeech> _open() async {
    final rate = _rate;
    if (_task case final task? when _taskRate == rate) return task;
    await _close();
    setState(
      () => _modelStatus =
          'Loading ${widget.task.modelFile}; the first run downloads it '
          '(87 MB).',
    );
    try {
      final task = await TextToSpeech.create(
        TextToSpeechOptions(
          modelPath: await GalleryAssets.downloadedModelPath(widget.task.model),
          delegate: _delegate,
          speakingRate: rate,
        ),
      );
      // The page closed during the load, so its dispose found no task.
      if (!mounted) {
        await task.dispose();
        throw StateError('The page closed.');
      }
      // Set first, so that a dispose or failure during the listing closes it.
      _task = task;
      _taskRate = rate;
      _voices = await task.listVoices();
      return task;
    } finally {
      if (mounted) setState(() => _modelStatus = null);
    }
  }

  Future<void> _speak() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final task = await _open();
      final text = _text.text.trim();
      if (text.isEmpty) throw StateError('Type something to speak.');
      final voice = [
        for (final voice in _voices)
          if (voice.voiceId == _voice) voice,
      ].firstOrNull;
      final clock = Stopwatch()..start();
      _result = await task.synthesize(
        text,
        voiceId: voice?.voiceId,
        locale: voice?.locale,
      );
      _spoken = text;
      _milliseconds = clock.elapsedMicroseconds / 1000;
    } on Object catch (error) {
      _error = '$error';
      _result = null;
    }
    if (mounted) setState(() => _busy = false);
  }

  void _setSetting(String key, Object value) {
    setState(() => _values[key] = value);
    if (_result != null && !_busy) unawaited(_speak());
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
      standardModel: 'Phonon',
    ),
  );

  Widget _voicePicker() {
    return SelectField<String?>(
      label: 'Voice',
      value: _voice,
      options: [
        (null, 'Default voice'),
        for (final voice in _voices) (voice.voiceId, voice.displayName),
      ],
      onChanged: _busy
          ? null
          : (voice) {
              setState(() => _voice = voice);
              if (_result != null) unawaited(_speak());
            },
    );
  }

  Widget _results(BuildContext context) {
    final c = GalleryColors.of(context);
    final result = _result;
    if (result == null) {
      return const OutputCard(
        title: 'Speech',
        empty: 'Speak the text to see its waveform and word timings.',
      );
    }
    final seconds = result.duration.inMicroseconds / 1e6;
    final words = result.wordTimestamps;
    return OutputCard(
      title: 'Speech',
      count: '${result.sampleRateHz ~/ 1000} kHz',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            identifier: 'speech-summary',
            container: true,
            child: Text(
              '${seconds.toStringAsFixed(2)} s, ${words.length} '
              '${words.length == 1 ? 'word' : 'words'}',
              key: speechSummaryKey,
              style: TextStyle(
                color: c.text,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${result.samples.length} samples',
            style: TextStyle(color: c.soft, fontSize: Sizes.xs),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 96,
            width: double.infinity,
            child: CustomPaint(
              painter: _WaveformPainter(
                samples: result.samples,
                sampleRate: result.sampleRateHz,
                words: words,
                wave: c.accent,
                mark: c.line,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Eyebrow('Word timings'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final word in words)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: c.surface2,
                    border: Border.all(color: c.line),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _spoken.substring(word.start, word.end),
                        style: TextStyle(color: c.text, fontSize: Sizes.md),
                      ),
                      Text(
                        '${word.startSeconds.toStringAsFixed(2)}'
                        '-${word.endSeconds.toStringAsFixed(2)} s',
                        style: TextStyle(color: c.soft, fontSize: Sizes.xs),
                      ),
                    ],
                  ),
                ),
            ],
          ),
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
              const Eyebrow('Text'),
              const SizedBox(height: 14),
              TextField(
                key: const ValueKey('speech-text'),
                controller: _text,
                minLines: 2,
                maxLines: 8,
                style: TextStyle(
                  color: c.text,
                  fontSize: Sizes.md,
                  height: 1.45,
                ),
                decoration: const InputDecoration(labelText: 'Text'),
              ),
              const SizedBox(height: 12),
              _voicePicker(),
              if (_voices.isEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'The other voices are listed once the model has loaded.',
                  style: TextStyle(color: c.soft, fontSize: Sizes.xs),
                ),
              ],
              const SizedBox(height: 16),
              TaskRunRow(
                busy: _busy,
                milliseconds: _milliseconds,
                button: PrimaryButton(
                  key: const ValueKey('speech-run'),
                  icon: LucideIcons.audioLines,
                  label: 'Speak',
                  onPressed: _busy ? null : _speak,
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

/// The speech's peak level across the width, with a tick where each word
/// starts.
class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.samples,
    required this.sampleRate,
    required this.words,
    required this.wave,
    required this.mark,
  });

  final Float32List samples;
  final int sampleRate;
  final List<WordTimestamp> words;
  final Color wave;
  final Color mark;

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty || size.width <= 0) return;
    final seconds = samples.length / sampleRate;
    final ticks = Paint()
      ..color = mark
      ..strokeWidth = 1;
    for (final word in words) {
      final x = size.width * word.startSeconds / seconds;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), ticks);
    }
    final bars = Paint()
      ..color = wave
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final columns = math.max(1, (size.width / 3).floor());
    final perColumn = samples.length / columns;
    final middle = size.height / 2;
    for (var i = 0; i < columns; i++) {
      var peak = 0.0;
      final end = math.min(samples.length, ((i + 1) * perColumn).ceil());
      for (var j = (i * perColumn).floor(); j < end; j++) {
        peak = math.max(peak, samples[j].abs());
      }
      final half = math.max(1.0, math.min(peak, 1.0) * middle);
      final x = i * 3 + 1.5;
      canvas.drawLine(Offset(x, middle - half), Offset(x, middle + half), bars);
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.samples != samples || old.wave != wave || old.mark != mark;
}
