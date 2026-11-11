import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mediapipe_audio/mediapipe_audio.dart';

import 'bundled_model_assets.dart';
import 'catalog.dart';
import 'live/task_settings.dart';
import 'live/task_settings_panel.dart';
import 'main.dart' show GalleryAssets;
import 'ui/components.dart';
import 'ui/design.dart';
import 'ui/workspace.dart';

/// The final transcript the journey test reads.
const transcriptKey = ValueKey('transcriber-text');

/// The bundled speech clips, the package's reference recordings of one
/// sentence at two rates.
const _clips = <String, String>{
  'speech_16000_hz_mono.wav': '16 kHz',
  'speech_48000_hz_mono.wav': '48 kHz',
};

/// Audio Transcriber on a bundled clip: the whole clip at once, or a second
/// at a time with Google's interim hypotheses, then the final segments.
/// NVIDIA's 615 MB Parakeet model, as Google's LiteRT community converted
/// it, downloads on first use.
class TranscriberPage extends StatefulWidget {
  const TranscriberPage({
    super.key,
    required this.task,
    required this.platform,
    this.onOpenMenu,
  });

  final GalleryTask task;
  final TaskPlatform platform;
  final VoidCallback? onOpenMenu;

  @override
  State<TranscriberPage> createState() => _TranscriberPageState();
}

class _TranscriberPageState extends State<TranscriberPage>
    with RevisionedState {
  late final String _id = widget.task.runtimeId;
  late final TaskSettingValues _values = TaskSettingValues(_id);
  late final List<TaskSetting> _settings = taskSettings[_id] ?? const [];
  late final List<Delegate> _delegates = widget.task
      .capabilities(widget.platform)
      .supportedDelegates
      .toList();
  late Delegate _delegate = preferredDelegate(_delegates);

  String _clip = _clips.keys.first;
  AudioTranscriber? _task;

  /// The rate and interim setting [_task] was created with.
  (int, bool)? _taskKey;
  bool _busy = false;
  String? _error;
  String? _modelStatus;
  List<TranscriptionSegment>? _segments;

  /// The interim hypotheses, one per second of audio that produced any.
  List<TranscriptionSegment> _interim = const [];
  double? _milliseconds;

  @override
  void dispose() {
    unawaited(_close());
    super.dispose();
  }

  Future<void> _close() async {
    final task = _task;
    _task = null;
    _taskKey = null;
    await task?.dispose();
  }

  Future<AudioTranscriber> _open(int rate, bool interim) async {
    if (_task case final task? when _taskKey == (rate, interim)) return task;
    await _close();
    setState(
      () => _modelStatus =
          'Loading ${widget.task.modelFile}; the first run downloads it '
          '(615 MB).',
    );
    try {
      final task = await AudioTranscriber.create(
        AudioTranscriberOptions(
          modelPath: await GalleryAssets.downloadedModelPath(widget.task.model),
          delegate: _delegate,
          sampleRateHz: rate,
          enableInterimResults: interim,
        ),
      );
      // The page closed during the load, so its dispose found no task.
      if (!mounted) {
        await task.dispose();
        throw StateError('The page closed.');
      }
      _taskKey = (rate, interim);
      return _task = task;
    } finally {
      if (mounted) setState(() => _modelStatus = null);
    }
  }

  Future<void> _run() async {
    setState(() {
      _busy = true;
      _error = null;
      _interim = const [];
    });
    try {
      final audio = decodeWav(await loadAssetBytes('assets/samples/$_clip'));
      final rate = audio.sampleRate.round();
      final interim = _values.on('enableInterimResults');
      final task = await _open(rate, interim);
      final clock = Stopwatch()..start();
      if (interim) {
        final segments = <TranscriptionSegment>[];
        final hypotheses = <TranscriptionSegment>[];
        for (var start = 0; start < audio.samples.length; start += rate) {
          final part = AudioData(
            samples: Float32List.sublistView(
              audio.samples,
              start,
              math.min(start + rate, audio.samples.length),
            ),
            sampleRate: audio.sampleRate,
          );
          final result = await task.transcribe(part, endOfStream: false);
          for (final segment in result.segments) {
            (segment.isFinal ? segments : hypotheses).add(segment);
          }
          if (mounted) setState(() => _interim = List.of(hypotheses));
        }
        segments.addAll((await task.finishStream()).segments);
        _segments = segments;
      } else {
        _segments = (await task.transcribe(audio)).segments;
      }
      _milliseconds = clock.elapsedMicroseconds / 1000;
    } on Object catch (error) {
      _error = '$error';
      _segments = null;
    }
    if (mounted) setState(() => _busy = false);
  }

  void _setSetting(String key, Object value) {
    setState(() => _values[key] = value);
    if (_segments != null && !_busy) unawaited(_run());
  }

  /// The next run creates the task on [delegate]; the last answer goes, as it
  /// came from the other one.
  void _setDelegate(Delegate delegate) {
    if (delegate == _delegate) return;
    setState(() {
      _delegate = delegate;
      _segments = null;
      _interim = const [];
      _milliseconds = null;
    });
    unawaited(_close());
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
      onDelegate: _setDelegate,
      models: const [],
      model: null,
      uploaded: null,
      modelStatus: _modelStatus,
      onModel: (_) {},
      onUpload: null,
      bundledModel: widget.task.modelFile,
      standardModel: 'Parakeet TDT 0.6B v3',
    ),
  );

  static String _span(TranscriptionSegment segment) =>
      '${(segment.fromTimestampMilliseconds / 1000).toStringAsFixed(2)} s to '
      '${(segment.toTimestampMilliseconds / 1000).toStringAsFixed(2)} s';

  Widget _segment(
    BuildContext context,
    TranscriptionSegment segment, {
    bool small = false,
  }) {
    final c = GalleryColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          segment.transcript,
          style: TextStyle(
            color: segment.isFinal && !small ? c.text : c.muted,
            fontSize: Sizes.md,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${_span(segment)}, ${segment.isFinal ? 'final' : 'interim'}',
          style: TextStyle(color: c.soft, fontSize: Sizes.xs),
        ),
      ],
    );
  }

  Widget _results(BuildContext context) {
    final segments = _segments;
    final interim = _interim;
    if (segments == null && interim.isEmpty) {
      return const OutputCard(
        title: 'Transcript',
        empty: 'Transcribe the clip to see its text and timings.',
      );
    }
    final text = AudioTranscriberResult(segments ?? const []).text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (segments != null)
          OutputCard(
            title: 'Transcript',
            count:
                '${segments.length} '
                '${segments.length == 1 ? 'segment' : 'segments'}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  identifier: 'transcriber-text',
                  container: true,
                  child: Text(
                    text,
                    key: transcriptKey,
                    style: TextStyle(
                      color: GalleryColors.of(context).text,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Eyebrow('Segments'),
                for (final segment in segments) ...[
                  const SizedBox(height: 10),
                  _segment(context, segment, small: true),
                ],
              ],
            ),
          ),
        if (interim.isNotEmpty) ...[
          if (segments != null) const SizedBox(height: 22),
          OutputCard(
            title: 'Interim results',
            count: '${interim.length}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (i, segment) in interim.indexed) ...[
                  if (i > 0) const SizedBox(height: 12),
                  _segment(context, segment),
                ],
              ],
            ),
          ),
        ],
      ],
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
              const Eyebrow('Speech clip'),
              const SizedBox(height: 14),
              Text(
                '"Send a text to Mike, I\'ll be home late tomorrow." '
                'Google\'s reference recording, at either rate.',
                style: TextStyle(color: c.muted, fontSize: Sizes.sm),
              ),
              const SizedBox(height: 12),
              Segmented<String>(
                semanticsIdentifier: 'transcriber-clip',
                segments: [
                  for (final MapEntry(key: file, value: label)
                      in _clips.entries)
                    (value: file, label: label, icon: null, key: null),
                ],
                selected: _clip,
                onChanged: _busy
                    ? null
                    : (file) => setState(() => _clip = file),
              ),
              const SizedBox(height: 16),
              TaskRunRow(
                busy: _busy,
                milliseconds: _milliseconds,
                button: PrimaryButton(
                  key: const ValueKey('transcriber-run'),
                  icon: LucideIcons.audioLines,
                  label: 'Transcribe',
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
          _results(context),
      ],
    );
  }
}
