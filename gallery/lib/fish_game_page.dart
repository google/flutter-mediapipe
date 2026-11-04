import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mediapipe_decision/mediapipe_decision.dart';

import 'catalog.dart';
import 'fish/fish_game.dart';
import 'live/task_models.dart';
import 'live/task_settings.dart';
import 'live/task_settings_panel.dart';
import 'main.dart' show GalleryAssets;
import 'ui/components.dart';
import 'ui/design.dart';
import 'ui/workspace.dart';

/// "N decisions · M matched the scene", which the journey reads.
const fishScoreKey = ValueKey('fish-score');

/// Hungry Fish: Decision Maker steers a fish that eats smaller fish and
/// flees bigger ones, as Google's dino game steers its dino. Beside the sea,
/// the sentence the model read and its answer; below it, the three choices'
/// descriptions, which a player can rewrite to change how the fish behaves.
class FishGamePage extends StatefulWidget {
  const FishGamePage({
    super.key,
    required this.task,
    required this.platform,
    this.onOpenMenu,
  });

  final GalleryTask task;

  /// Decides the delegate, as on the Decision Maker page.
  final TaskPlatform platform;
  final VoidCallback? onOpenMenu;

  @override
  State<FishGamePage> createState() => _FishGamePageState();
}

class _FishGamePageState extends State<FishGamePage>
    with SingleTickerProviderStateMixin, RevisionedState {
  static const _tick = 1 / 60;

  late final String _id = widget.task.id;
  late final TaskSettingValues _values = TaskSettingValues(_id);
  late final List<TaskModel> _models = [
    for (final model in taskModels[_id] ?? const <TaskModel>[])
      if (decisionRunsModel(widget.platform, model)) model,
  ];
  late final List<Delegate> _delegates = widget.task
      .capabilities(widget.platform)
      .supportedDelegates
      .toList();
  late final Delegate _delegate = preferredDelegate(_delegates);

  /// The standard model: the catalog's text-only EmbeddingGemma 2 (165 MB).
  /// WebKit runs no EmbeddingGemma 2 model (UP-054), so there the page is a
  /// card.
  DownloadAsset get _standard => widget.task.model;
  late final Ticker _ticker = createTicker(_frame);
  late final _game = FishGame(decide: _decide);
  late final _rules = {
    for (final MapEntry(:key, :value) in defaultFishRules.entries)
      key: TextEditingController(text: value),
  };
  late ChoiceQuestion _question = _ask();

  TaskModel? _model;
  DecisionMaker? _task;
  Future<DecisionMaker>? _opening;
  String? _status;
  Duration _previous = Duration.zero;
  double _pending = 0;

  /// Seconds the model has been loading, which the loading screen counts.
  int _loadingSeconds = 0;
  Timer? _loadingClock;

  /// Whether Play was pressed while the model loaded, so the game starts as
  /// soon as it is ready.
  bool _playWhenReady = false;

  @override
  void initState() {
    super.initState();
    // The model loads as the page opens, behind the loading screen, so the
    // game is ready by the time Play is pressed.
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      await _open();
    } on Object catch (error) {
      if (mounted) setState(() => _game.error = error);
      return;
    }
    if (mounted && _playWhenReady) {
      _playWhenReady = false;
      await _play();
    }
  }

  @override
  void dispose() {
    _loadingClock?.cancel();
    _ticker.dispose();
    for (final controller in _rules.values) {
      controller.dispose();
    }
    unawaited(_close());
    super.dispose();
  }

  Future<void> _close() async {
    final opening = _opening;
    _opening = null;
    _task = null;
    if (opening != null) await (await opening).dispose();
  }

  ChoiceQuestion _ask() => ChoiceQuestion(
    {
      for (final intent in FishIntent.values)
        intent.name: _rules[intent]!.text.trim().isEmpty
            ? defaultFishRules[intent]!
            : _rules[intent]!.text.trim(),
    },
    instructions: fishInstructions,
    normalizePrior: true,
  );

  /// The chosen model's pin: the standard EmbeddingGemma 2 unless another
  /// was chosen.
  DownloadAsset get _pin => switch (_model) {
    final model? => model.pin,
    null => _standard,
  };

  Future<DecisionMaker> _open() => _opening ??= () async {
    final pin = _pin;
    final name = _model?.name ?? 'EmbeddingGemma 2 (165 MB)';
    _loadingSeconds = 0;
    _loadingClock?.cancel();
    _loadingClock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _loadingSeconds++);
    });
    // Natively the model cache keeps the download; browsers fetch it again,
    // since the hosts give it no lasting cache lifetime.
    setState(
      () => _status = kIsWeb
          ? 'Loading $name. Your browser downloads it for each visit.'
          : 'Loading $name. The first game downloads it; after that it '
                'loads from this device.',
    );
    try {
      return _task = await DecisionMaker.create(
        DecisionMakerOptions(
          modelPath: await GalleryAssets.downloadedModelPath(pin),
          delegate: _delegate,
        ),
      );
    } catch (_) {
      _opening = null;
      rethrow;
    } finally {
      _loadingClock?.cancel();
      _loadingClock = null;
      if (mounted) setState(() => _status = null);
    }
  }();

  Future<FishAnswer> _decide(String text) async {
    final task = _task ?? await _open();
    final result = await task.evaluateChoice(text, _question);
    return (
      intent: FishIntent.values.byName(result.selectedKey),
      probabilities: {
        for (final intent in FishIntent.values)
          intent: result.probabilities[intent.name] ?? 0,
      },
    );
  }

  void _frame(Duration elapsed) {
    final seconds = (elapsed - _previous).inMicroseconds / 1e6;
    _previous = elapsed;
    // A frame that comes late, such as after a pause, does not fast-forward.
    _pending += math.min(seconds, 0.1);
    while (_pending >= _tick) {
      _game.tick(_tick);
      _pending -= _tick;
    }
    if (_game.error != null) _ticker.stop();
    setState(() {});
  }

  Future<void> _play() async {
    if (_ticker.isActive) {
      setState(_ticker.stop);
      return;
    }
    // While the model loads, Play starts the game the moment it is ready.
    if (_task == null && _opening != null) {
      setState(() => _playWhenReady = !_playWhenReady);
      return;
    }
    try {
      await _open();
    } on Object catch (error) {
      setState(() => _game.error = error);
      return;
    }
    if (!mounted) return;
    _previous = Duration.zero;
    _pending = 0;
    unawaited(_ticker.start());
    setState(() {});
  }

  void _step() => setState(() => _game.tick(_tick));

  void _restart() => setState(_game.restart);

  Future<void> _chooseModel(TaskModel? model) async {
    final running = _ticker.isActive;
    _ticker.stop();
    await _close();
    setState(() {
      _model = model;
      _game.restart();
    });
    _playWhenReady = running;
    if (mounted) await _load();
  }

  Widget _panel() => ListenableBuilder(
    listenable: revision,
    builder: (context, _) => TaskSettingsPanel(
      settings: taskSettings[_id] ?? const [],
      values: _values,
      delegates: _delegates,
      delegate: _delegate,
      enabled: _status == null,
      onChanged: (key, value) => setState(() => _values[key] = value),
      onDelegate: (_) {},
      models: _models,
      model: _model,
      uploaded: null,
      modelStatus: _status,
      onModel: _chooseModel,
      onUpload: null,
      bundledModel: widget.task.modelFile,
      standardModel: 'EmbeddingGemma 2 (270M)',
    ),
  );

  Widget _thoughts(BuildContext context) {
    final c = GalleryColors.of(context);
    final last = _game.last;
    final muted = TextStyle(color: c.muted, fontSize: Sizes.sm);
    if (_game.error case final error?) {
      return TaskErrorCard(error);
    }
    return OutputCard(
      title: 'What the model decided',
      count: last == null ? null : '${last.milliseconds.toStringAsFixed(0)} ms',
      empty: 'Press Play: the model steers the fish.',
      child: last == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('It read', style: muted),
                const SizedBox(height: 4),
                Text(
                  '"${last.text}"',
                  style: TextStyle(color: c.text, fontSize: Sizes.md),
                ),
                const SizedBox(height: 12),
                Text(
                  last.answer.intent.name[0].toUpperCase() +
                      last.answer.intent.name.substring(1),
                  style: TextStyle(
                    color: last.matched ? c.teal : Colors.redAccent,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                ScoreBars([
                  for (final intent in FishIntent.values)
                    (
                      name: intent.name,
                      value: last.answer.probabilities[intent] ?? 0,
                    ),
                ]),
              ],
            ),
    );
  }

  Widget _rulesCard(BuildContext context) {
    final c = GalleryColors.of(context);
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('The question'),
          const SizedBox(height: 8),
          Text(
            '"$fishInstructions" Rewrite a choice\'s description and the fish '
            'behaves differently from its next decision.',
            style: TextStyle(color: c.muted, fontSize: Sizes.sm, height: 1.4),
          ),
          const SizedBox(height: 12),
          for (final intent in FishIntent.values) ...[
            TextField(
              key: ValueKey('fish-rule-${intent.name}'),
              controller: _rules[intent],
              style: TextStyle(color: c.text, fontSize: Sizes.sm),
              decoration: InputDecoration(labelText: intent.name),
              onChanged: (_) => _question = _ask(),
            ),
            const SizedBox(height: 10),
          ],
          OutlineButton(
            icon: LucideIcons.rotateCcw,
            label: 'Google\'s wording',
            tooltip: 'Restore the descriptions both models get right',
            onPressed: () {
              for (final MapEntry(:key, :value) in defaultFishRules.entries) {
                _rules[key]!.text = value;
              }
              _question = _ask();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = GalleryColors.of(context);
    final world = _game.world;
    final playing = _ticker.isActive;
    return TaskWorkspace(
      title: widget.task.title,
      onOpenMenu: widget.onOpenMenu,
      settings: _panel(),
      children: [
        TaskToolbar(task: widget.task),
        SurfaceCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(Sizes.radiusSmall),
                child: AspectRatio(
                  aspectRatio: FishWorld.width / FishWorld.height,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomPaint(
                        key: const ValueKey('fish-sea'),
                        painter: _SeaPainter(_game),
                      ),
                      if (_status case final status?)
                        FishLoadingScreen(
                          status: status,
                          seconds: _loadingSeconds,
                          starting: _playWhenReady,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  PrimaryButton(
                    key: const ValueKey('fish-play'),
                    icon: playing ? LucideIcons.pause : LucideIcons.play,
                    label: playing
                        ? 'Pause'
                        : _status != null && _playWhenReady
                        ? 'Starting…'
                        : 'Play',
                    onPressed: _game.error == null ? _play : null,
                  ),
                  OutlineButton(
                    icon: LucideIcons.stepForward,
                    label: 'Step',
                    tooltip: 'Advance one sixtieth of a second',
                    onPressed: playing || _task == null ? null : _step,
                  ),
                  OutlineButton(
                    icon: LucideIcons.refreshCw,
                    label: 'Restart',
                    tooltip: 'A small fish in a fresh sea',
                    onPressed: _restart,
                  ),
                  Text(
                    'Size ${world.player.size.toStringAsFixed(0)} · '
                    'eaten ${world.eaten} · lost ${world.lost}',
                    style: TextStyle(color: c.text, fontSize: Sizes.sm),
                  ),
                  Text(
                    '${_game.decisions} decisions · ${_game.matched} matched '
                    'the scene',
                    key: fishScoreKey,
                    style: TextStyle(color: c.muted, fontSize: Sizes.sm),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        _thoughts(context),
        const SizedBox(height: 22),
        _rulesCard(context),
      ],
    );
  }
}

/// What covers the sea while the model loads: what is loading, for how long,
/// and whether the game starts as soon as it is ready.
class FishLoadingScreen extends StatelessWidget {
  const FishLoadingScreen({
    super.key,
    required this.status,
    required this.seconds,
    required this.starting,
  });

  final String status;
  final int seconds;
  final bool starting;

  @override
  Widget build(BuildContext context) => ColoredBox(
    key: const ValueKey('fish-loading'),
    color: const Color(0xB3012F52),
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        // Wraps at the sea's width, then scales down in a short sea rather
        // than overflowing: a 360-point-wide phone, such as a Galaxy S24,
        // leaves it 254 by 133 points.
        child: LayoutBuilder(
          builder: (context, box) => FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: box.maxWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    status,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${seconds}s${starting ? ' · the game starts when it is ready' : ''}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The sea: every fish with its name, the player's in orange with its
/// sight, and a ring on the fish the model is thinking about.
class _SeaPainter extends CustomPainter {
  _SeaPainter(this.game);

  final FishGame game;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / FishWorld.width;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4FC3F7), Color(0xFF01579B)],
        ).createShader(Offset.zero & size),
    );
    canvas.scale(scale);
    final world = game.world;
    final player = world.player;
    canvas.drawCircle(
      Offset(player.x, player.y),
      world.sight,
      Paint()
        ..color = const Color(0x22FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final encounter = world.encounter;
    for (final fish in world.others) {
      _fish(canvas, fish, Color(fish.species!.color));
      _label(canvas, fish.species!.name, fish);
    }
    if (encounter != null) {
      canvas.drawCircle(
        Offset(encounter.fish.x, encounter.fish.y),
        encounter.fish.size + 8,
        Paint()
          ..color = encounter.prey
              ? const Color(0xFFB9F6CA)
              : const Color(0xFFFF8A80)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
    _fish(canvas, player, const Color(0xFFFF9800), outline: true);
  }

  void _fish(Canvas canvas, Fish fish, Color color, {bool outline = false}) {
    final direction = fish.facingLeft ? -1.0 : 1.0;
    final body = Rect.fromCenter(
      center: Offset(fish.x, fish.y),
      width: fish.size * 2.4,
      height: fish.size * 1.5,
    );
    final tail = Path()
      ..moveTo(fish.x - direction * fish.size * 1.0, fish.y)
      ..lineTo(fish.x - direction * fish.size * 1.9, fish.y - fish.size * 0.7)
      ..lineTo(fish.x - direction * fish.size * 1.9, fish.y + fish.size * 0.7)
      ..close();
    final paint = Paint()..color = color;
    canvas
      ..drawPath(tail, paint)
      ..drawOval(body, paint);
    if (outline) {
      canvas.drawOval(
        body,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }
    canvas
      ..drawCircle(
        Offset(fish.x + direction * fish.size * 0.6, fish.y - fish.size * 0.2),
        math.max(1.5, fish.size * 0.16),
        Paint()..color = Colors.white,
      )
      ..drawCircle(
        Offset(fish.x + direction * fish.size * 0.65, fish.y - fish.size * 0.2),
        math.max(0.8, fish.size * 0.08),
        Paint()..color = Colors.black,
      );
  }

  void _label(Canvas canvas, String name, Fish fish) {
    final text = TextPainter(
      text: TextSpan(
        text: name,
        style: const TextStyle(color: Colors.white70, fontSize: 13),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(
      canvas,
      Offset(fish.x - text.width / 2, fish.y + fish.size * 0.8 + 2),
    );
  }

  @override
  bool shouldRepaint(covariant _SeaPainter oldDelegate) => true;
}
