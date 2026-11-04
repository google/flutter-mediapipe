import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mediapipe_audio/mediapipe_audio.dart';

import 'audio/microphone.dart';
import 'catalog.dart';
import 'live/task_models.dart';
import 'live/task_settings.dart';
import 'live/task_settings_panel.dart';
import 'ui/components.dart';
import 'ui/design.dart';
import 'ui/workspace.dart';
import 'bundled_model_assets.dart';

/// Audio Classifier on a clip, or on the microphone as Google's audio stream,
/// laid out as the other demos are: the audio and its results beside the
/// same settings panel, with MediaPipe Studio's settings and model selection.
class AudioPage extends StatefulWidget {
  const AudioPage({
    super.key,
    required this.task,
    this.onOpenMenu,
    this.microphone,
  });

  final GalleryTask task;
  final VoidCallback? onOpenMenu;

  /// Where microphone mode reads its audio; the device's microphone when
  /// null.
  final MicrophoneSource? microphone;

  @override
  State<AudioPage> createState() => _AudioPageState();
}

/// Google's sample clips, bundled with the gallery on macOS.
const _clips = <String, String>{
  'speech_16000_hz_mono.wav': 'Speech (16 kHz)',
  'speech_48000_hz_mono.wav': 'Speech (48 kHz)',
  'two_heads_16000_hz_mono.wav': 'Animal sounds',
};

class _AudioPageState extends State<AudioPage>
    with RevisionedState, ModelSelectionState {
  late final TaskSettingValues _values = TaskSettingValues('audio_classifier');
  late final List<TaskSetting> _settings =
      taskSettings['audio_classifier'] ?? const [];

  String _clip = _clips.keys.first;
  ({String name, Uint8List bytes})? _uploadedClip;

  AudioClassifier? _task;
  Future<void> _resets = Future.value();
  bool _busy = false;
  String? _error;
  AudioData? _audio;
  List<AudioClassifierResult>? _chunks;
  double? _milliseconds;

  /// Microphone mode: the recorder's 16 kHz mono PCM as one audio stream,
  /// each window's result as it completes, newest first.
  bool _microphone = false;
  AudioClassifier? _stream;
  StreamSubscription<Uint8List>? _recording;
  PcmBlocks? _blocks;

  /// Blocks that arrive while a settings change replaces the stream task;
  /// the new task gets them first, so no audio is lost.
  final _waiting = <(AudioData, int)>[];
  final _heard = <AudioClassifierResult>[];
  static const _rate = 16000;
  static const _shown = 8;

  /// When the audio reached each point of the stream: each block's end, in
  /// the stream's milliseconds, and when it arrived.
  final _arrivals = <(int, int)>[];
  final _clock = Stopwatch()..start();

  /// The latest window's start and when its result arrived; its audio ended
  /// where the next window starts.
  (int, int)? _latest;

  /// Milliseconds from the end of a window's audio to its result.
  int? _delay;

  @override
  void initState() {
    super.initState();
    unawaited(_run());
  }

  @override
  void dispose() {
    unawaited(_stopListening());
    unawaited(_task?.dispose());
    super.dispose();
  }

  Future<AudioClassifier> _open() async =>
      _task ??= await AudioClassifier.create(
        AudioClassifierOptions(
          model: modelBytes == null ? AudioModels.yamnet : null,
          modelBytes: modelBytes,
          maxResults: _values.count('maxResults'),
          scoreThreshold: _values.share('scoreThreshold'),
        ),
      );

  /// A stream task with the current settings, listened to at once.
  Future<AudioClassifier> _openStream() async {
    final task = await AudioClassifier.create(
      AudioClassifierOptions(
        model: modelBytes == null ? AudioModels.yamnet : null,
        modelBytes: modelBytes,
        maxResults: _values.count('maxResults'),
        scoreThreshold: _values.share('scoreThreshold'),
        runningMode: AudioRunningMode.audioStream,
      ),
    );
    task.results.listen(_heardWindow, onError: _failed);
    return task;
  }

  Future<void> _run() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final bytes =
          _uploadedClip?.bytes ?? await loadAssetBytes('assets/samples/$_clip');
      final audio = decodeWav(bytes);
      final task = await _open();
      final clock = Stopwatch()..start();
      final chunks = await task.classify(audio);
      _milliseconds = clock.elapsedMicroseconds / 1000;
      _audio = audio;
      _chunks = chunks;
    } on Object catch (error) {
      _error = '$error';
    }
    if (mounted) setState(() => _busy = false);
  }

  /// Rebuilds the tasks with the changed settings or model, then reruns the
  /// clip, or goes on classifying the microphone with a new stream task.
  Future<void> _reset() => _inTurn(_rebuild);

  /// Runs [step] after the rebuilds and stream openings before it. While
  /// listening the settings stay enabled, and two of these at once would
  /// open two tasks, keeping whichever finished last.
  Future<void> _inTurn(Future<void> Function() step) {
    final turn = _resets.then((_) => step());
    _resets = turn.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return turn;
  }

  Future<void> _rebuild() async {
    final task = _task;
    _task = null;
    await task?.dispose();
    if (!mounted) return;
    if (!_microphone) return _run();
    // The old stream delivers its tail as it closes; the audio that arrives
    // meanwhile waits for the new stream, which continues the timeline.
    final stream = _stream;
    _stream = null;
    await stream?.dispose();
    if (!mounted || !_microphone) return;
    try {
      final next = await _openStream();
      if (!mounted || !_microphone) return unawaited(next.dispose());
      for (final (block, timestamp) in _waiting) {
        next.classifyAsync(block, timestampMilliseconds: timestamp);
      }
      _waiting.clear();
      _stream = next;
      setState(() => _error = null);
    } on Object catch (error) {
      // Without a stream the microphone's audio would wait without end.
      _failed(error);
    }
  }

  Future<void> _listen() async {
    setState(() {
      _error = null;
      _heard.clear();
      _arrivals.clear();
      _latest = null;
      _delay = null;
    });
    final blocks = _blocks = PcmBlocks(_rate);
    // Leaving the mode replaces or clears the blocks, so a start that it
    // overtook undoes itself.
    bool left() => !mounted || !identical(_blocks, blocks);
    try {
      await _inTurn(() async {
        // A settings change queued first has opened the stream already.
        if (left() || _stream != null) return;
        final stream = await _openStream();
        if (left()) return unawaited(stream.dispose());
        _stream = stream;
      });
      if (left()) return;
      final audio = await (widget.microphone ?? recorderMicrophone)(_rate);
      if (left()) {
        // Cancelling the new subscription stops the recorder again.
        await audio.listen(null).cancel();
        return;
      }
      setState(
        () => _recording = audio.listen(
          (chunk) => _chunk(blocks, chunk),
          onError: _failed,
        ),
      );
    } on Object catch (error) {
      if (left()) return;
      await _stopListening();
      if (mounted) setState(() => _error = '$error');
    }
  }

  /// Hands each block a recorder chunk completes to the stream, stamped with
  /// its first sample's time in the stream.
  void _chunk(PcmBlocks blocks, Uint8List chunk) {
    final block = blocks.add(chunk);
    if (block == null) return;
    _arrivals.add((blocks.sentMilliseconds, _clock.elapsedMicroseconds));
    final stream = _stream;
    if (stream == null) return _waiting.add(block);
    try {
      stream.classifyAsync(block.$1, timestampMilliseconds: block.$2);
    } on Object catch (error) {
      _failed(error);
    }
  }

  void _heardWindow(AudioClassifierResult result) {
    final now = _clock.elapsedMicroseconds;
    final start = result.timestampMilliseconds;
    if (_latest case (_, final arrived)) {
      // The previous window's audio ended where this one starts: the block
      // that reached that point completed it.
      while (_arrivals.isNotEmpty && _arrivals.first.$1 < start) {
        _arrivals.removeAt(0);
      }
      if (_arrivals.isNotEmpty) {
        _delay = ((arrived - _arrivals.first.$2) / 1000).round();
      }
    }
    _latest = (start, now);
    if (!mounted || !_microphone) return;
    setState(() {
      _heard.insert(0, result);
      if (_heard.length > _shown) _heard.removeRange(_shown, _heard.length);
    });
  }

  /// A failure ends the stream, so the microphone stops with it.
  void _failed(Object error) {
    if (!mounted) return;
    setState(() => _error = '$error');
    unawaited(_stopListening());
  }

  /// Stops the recorder, then disposes the stream task, which classifies the
  /// audio short of a window as Google's close does.
  Future<void> _stopListening() async {
    final recording = _recording;
    _recording = null;
    _blocks = null;
    _waiting.clear();
    await recording?.cancel();
    final stream = _stream;
    _stream = null;
    await stream?.dispose();
  }

  Future<void> _setMicrophone(bool on) async {
    setState(() {
      _microphone = on;
      _chunks = null;
      _milliseconds = null;
      _error = null;
    });
    if (on) {
      await _listen();
    } else {
      await _stopListening();
      await _run();
    }
  }

  void _setSetting(String key, Object value) {
    setState(() => _values[key] = value);
    unawaited(_reset());
  }

  Future<void> _uploadClip() async {
    try {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'WAV audio',
            extensions: ['wav'],
            uniformTypeIdentifiers: ['com.microsoft.waveform-audio'],
          ),
        ],
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() => _uploadedClip = (name: file.name, bytes: bytes));
      await _run();
    } on Object catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
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
      models: const [],
      model: null,
      uploaded: uploaded,
      modelStatus: modelStatus,
      onModel: chooseModel,
      onUpload: uploadModel,
      bundledModel: 'yamnet.tflite',
    ),
  );

  @override
  Widget build(BuildContext context) {
    final c = GalleryColors.of(context);
    final audio = _audio;
    final muted = TextStyle(color: c.muted, fontSize: Sizes.xs);
    final chunks = _microphone
        ? _heard
        : _chunks ?? const <AudioClassifierResult>[];
    return TaskWorkspace(
      title: widget.task.title,
      onOpenMenu: widget.onOpenMenu,
      settings: _panel(),
      children: [
        TaskToolbar(
          task: widget.task,
          leading: Segmented<bool>(
            key: const ValueKey('audio-source'),
            segments: const [
              (
                value: false,
                label: 'Clips',
                icon: LucideIcons.fileAudio,
                key: ValueKey('audio-source-clips'),
              ),
              (
                value: true,
                label: 'Microphone',
                icon: LucideIcons.mic,
                key: ValueKey('audio-source-microphone'),
              ),
            ],
            selected: _microphone,
            onChanged: _busy ? null : (on) => unawaited(_setMicrophone(on)),
          ),
        ),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Eyebrow(_microphone ? 'Microphone' : 'Audio clip'),
              const SizedBox(height: 14),
              if (_microphone)
                Row(
                  children: [
                    if (_recording != null) ...[
                      const StatusDot(),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        _recording == null
                            ? 'Starting the microphone…'
                            : kIsWeb
                            ? 'Listening: the microphone is framed into the '
                                  "model's windows as Google's audio stream "
                                  "frames it, and Google's browser task "
                                  'classifies each window as it completes, '
                                  'newest first.'
                            : "Listening: Google's audio stream frames the "
                                  "microphone into the model's windows and "
                                  'classifies each one as it completes, '
                                  'newest first.',
                        style: TextStyle(color: c.soft, fontSize: Sizes.sm),
                      ),
                    ),
                  ],
                )
              else ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final MapEntry(key: file, value: label)
                        in _clips.entries)
                      Segmented<bool>(
                        segments: [
                          (value: true, label: label, icon: null, key: null),
                        ],
                        selected: _uploadedClip == null && _clip == file,
                        onChanged: _busy
                            ? null
                            : (_) {
                                setState(() {
                                  _clip = file;
                                  _uploadedClip = null;
                                });
                                unawaited(_run());
                              },
                      ),
                    Segmented<bool>(
                      segments: [
                        (
                          value: true,
                          label: _uploadedClip?.name ?? 'Upload WAV',
                          icon: LucideIcons.upload,
                          key: null,
                        ),
                      ],
                      selected: _uploadedClip != null,
                      onChanged: _busy ? null : (_) => _uploadClip(),
                    ),
                  ],
                ),
                if (audio != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    '${(audio.samples.length / audio.channels / audio.sampleRate).toStringAsFixed(2)} s · '
                    '${audio.sampleRate.round()} Hz · '
                    '${audio.channels} channel${audio.channels == 1 ? '' : 's'}',
                    style: muted,
                  ),
                ],
              ],
            ],
          ),
        ),
        FeedStatus(
          parts: [
            if (_microphone && _delay != null)
              '$_delay ms from the end of a window to its result'
            else if (!_microphone && _busy)
              'Classifying…'
            else if (!_microphone && _milliseconds != null)
              'Done in ${_milliseconds!.toStringAsFixed(1)} ms',
          ],
          delegate: 'CPU',
        ),
        const SizedBox(height: 11),
        if (_error case final error?)
          TaskErrorCard(error)
        else
          OutputCard(
            title: _microphone ? 'Heard' : 'Sounds over time',
            count: chunks.isEmpty
                ? null
                : '${chunks.length} window${chunks.length == 1 ? '' : 's'}',
            empty: _microphone
                ? 'Waiting for the first window.'
                : 'Choose a clip to classify it.',
            child: chunks.isEmpty
                ? null
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final (i, chunk) in chunks.indexed) ...[
                        if (i > 0) const SizedBox(height: 22),
                        Text(
                          '${(chunk.timestampMilliseconds / 1000).toStringAsFixed(3)} s',
                          key: ValueKey('audio-window-$i'),
                          style: eyebrowStyle(context),
                        ),
                        const SizedBox(height: 12),
                        if (_categories(chunk).isEmpty)
                          Text(
                            'Nothing above the score threshold.',
                            style: muted,
                          )
                        else
                          ScoreBars(key: ValueKey('audio-scores-$i'), [
                            for (final category in _categories(chunk))
                              (
                                name: category.categoryName ?? '',
                                value: category.score,
                              ),
                          ]),
                      ],
                    ],
                  ),
          ),
      ],
    );
  }
}

/// The first head's categories: YAMNet has one.
List<MediaPipeCategory> _categories(AudioClassifierResult chunk) =>
    chunk.classifications.isEmpty
    ? const []
    : chunk.classifications.first.categories;
