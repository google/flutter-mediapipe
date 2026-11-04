/// Hungry Fish: a fish steered by Decision Maker, as Google's dino game
/// steers its dino. The model never sees positions or sizes: whenever the
/// fish nearest the player changes, the game describes it in words and asks
/// one Choice question (chase, flee or explore). The game code only steers:
/// toward the fish the model chose to chase, away from one it chose to flee.
///
/// Free of Flutter, so the world and the decision loop are unit-tested.
library;

import 'dart:math' as math;

/// What the player's fish does, as the model decides it.
enum FishIntent { chase, flee, explore }

/// A fish the game spawns: its name, which is all the model reads of it,
/// its radius in world units and its color.
typedef FishSpecies = ({String name, double size, int color});

/// Smallest first. No name starts with a vowel: the model reads every
/// sentence with "a", which both models were checked on.
const fishSpecies = <FishSpecies>[
  (name: 'shrimp', size: 6, color: 0xFFFF8A80),
  (name: 'minnow', size: 8, color: 0xFFB0BEC5),
  (name: 'guppy', size: 9, color: 0xFFFFD54F),
  (name: 'sardine', size: 11, color: 0xFF90A4AE),
  (name: 'clownfish', size: 12, color: 0xFFFF7043),
  (name: 'pufferfish', size: 15, color: 0xFFFFF176),
  (name: 'herring', size: 17, color: 0xFF78909C),
  (name: 'mackerel', size: 20, color: 0xFF4DB6AC),
  (name: 'trout', size: 24, color: 0xFFA1887F),
  (name: 'salmon', size: 29, color: 0xFFFF8A65),
  (name: 'tuna', size: 36, color: 0xFF5C6BC0),
  (name: 'barracuda', size: 44, color: 0xFF7E57C2),
  (name: 'grouper', size: 52, color: 0xFF8D6E63),
  (name: 'swordfish', size: 62, color: 0xFF42A5F5),
  (name: 'shark', size: 76, color: 0xFF607D8B),
  (name: 'killer whale', size: 92, color: 0xFF263238),
];

/// The question's instructions; with [defaultFishRules] and Google's prior
/// normalization, EmbeddingGemma 2 and Laya choose right for every sentence
/// the game writes (33 of 33 each, against Google's 1.1.0 wheel).
const fishInstructions = 'What should the fish do?';

/// Each choice's description, which the page lets players rewrite.
const defaultFishRules = <FishIntent, String>{
  FishIntent.chase: 'prey nearby, a fish smaller than you',
  FishIntent.flee: 'a predator nearby, a fish bigger than you',
  FishIntent.explore: 'no fish nearby',
};

/// One fish: the player's, with no species, or one the game spawned.
final class Fish {
  Fish(this.id, this.species, this.x, this.y, this.size, {this.vx = 0});

  final int id;
  final FishSpecies? species;
  double x;
  double y;
  double vx;
  double vy = 0;
  double size;

  /// Whether it faces left, for drawing.
  bool get facingLeft => vx < 0;
}

/// The fish the model is asked about, and whether the player can eat it.
typedef FishEncounter = ({Fish fish, bool prey});

/// The sentence the model reads: what is nearby, in words only.
String describeEncounter(FishEncounter? encounter) => switch (encounter) {
  null => 'No fish nearby.',
  (:final fish, prey: true) =>
    'Prey nearby: a ${fish.species!.name}, smaller than you.',
  (:final fish, prey: false) =>
    'Predator nearby: a ${fish.species!.name}, bigger than you.',
};

/// What the scene calls for, against which the page scores the model.
FishIntent expectedIntent(FishEncounter? encounter) => switch (encounter) {
  null => FishIntent.explore,
  (prey: true, fish: _) => FishIntent.chase,
  (prey: false, fish: _) => FishIntent.flee,
};

/// The ocean: the player's fish, the others, and what has happened so far.
final class FishWorld {
  FishWorld({int seed = 7}) : _random = math.Random(seed) {
    reset();
  }

  static const width = 1000.0;
  static const height = 600.0;
  static const startSize = 14.0;

  /// How many other fish swim at once.
  static const population = 9;

  /// How fast a predator that sees the player swims at it: slower than the
  /// player's fish, so a good escape works.
  static const predatorSpeed = 95.0;

  /// The headings the player's fish weighs, in a full circle.
  static const _headings = 32;

  final math.Random _random;
  late Fish player;
  final others = <Fish>[];
  int eaten = 0;
  int lost = 0;
  int _nextId = 1;
  double _heading = 0;

  /// The escape heading the fish is committed to while it flees, how many
  /// ticks it has held it, and the open water it is heading for.
  double? _route;
  int _held = 0;
  (double, double)? _safe;

  /// How far the player's fish sees; it grows with the fish.
  double get sight => 150 + player.size * 3;

  /// Starts over: a small fish in the middle and a fresh sea.
  void reset() {
    player = Fish(0, null, width / 2, height / 2, startSize);
    others.clear();
    eaten = 0;
    lost = 0;
    for (var i = 0; i < population; i++) {
      others.add(_spawn(anywhere: true));
    }
  }

  /// Whether the player's fish is clearly bigger than [fish].
  bool canEat(Fish fish) => player.size > fish.size * 1.1;

  /// Whether [fish] can eat the player's fish.
  bool dangerous(Fish fish) => fish.size > player.size * 1.1;

  /// The fish the model is asked about: the nearest predator within three
  /// quarters of the player's sight, since danger comes first, else the
  /// nearest fish in sight; null when none is in sight.
  FishEncounter? get encounter {
    Fish? nearest;
    Fish? predator;
    var best = double.infinity;
    var closestPredator = double.infinity;
    for (final fish in others) {
      final distance = _distance(player, fish) - fish.size;
      if (distance < sight && distance < best) {
        best = distance;
        nearest = fish;
      }
      if (dangerous(fish) && distance < sight * 0.75) {
        if (distance < closestPredator) {
          closestPredator = distance;
          predator = fish;
        }
      }
    }
    final fish = predator ?? nearest;
    return fish == null ? null : (fish: fish, prey: canEat(fish));
  }

  /// Advances [dt] seconds, the player's fish doing [intent] about the fish
  /// with id [target], or exploring when that fish is gone.
  void step(double dt, FishIntent intent, int? target) {
    final about = others.where((fish) => fish.id == target).firstOrNull;
    _steerPlayer(dt, about == null ? FishIntent.explore : intent, about);
    for (final fish in others) {
      // A bigger fish that sees the player turns toward it, a little slower
      // than the player swims, so fleeing in time works.
      if (!canEat(fish) && _distance(player, fish) < sight) {
        final (vx, vy) = _hunt(
          fish.x,
          fish.y,
          fish.vx,
          fish.vy,
          player.x,
          player.y,
          dt,
        );
        fish
          ..vx = vx
          ..vy = vy;
      }
      fish
        ..x += fish.vx * dt
        ..y = (fish.y + fish.vy * dt).clamp(fish.size, height - fish.size);
    }
    _collide();
    others.removeWhere(
      (fish) => fish.x < -fish.size * 3 || fish.x > width + fish.size * 3,
    );
    while (others.length < population) {
      others.add(_spawn());
    }
  }

  void _steerPlayer(double dt, FishIntent intent, Fish? about) {
    final speed = math.max(120.0, 190 - player.size * 0.6);
    // Every fish that could eat the player's, as far as it could matter.
    final threats = [
      for (final fish in others)
        if (dangerous(fish) && _distance(player, fish) < sight * 1.6) fish,
    ];
    if (intent != FishIntent.flee) {
      _route = null;
      _safe = null;
    }
    final (dx, dy) = switch (intent) {
      FishIntent.flee => _escape(speed, threats),
      FishIntent.chase => _pursue(speed, about!, threats),
      FishIntent.explore => _wander(dt),
    };
    // Fleeing turns fast; cruising turns smoothly.
    final turn = math.min(1.0, dt * (intent == FishIntent.flee ? 8 : 4));
    player.vx += (dx * speed - player.vx) * turn;
    player.vy += (dy * speed - player.vy) * turn;
    player
      ..x = (player.x + player.vx * dt).clamp(player.size, width - player.size)
      ..y = (player.y + player.vy * dt).clamp(
        player.size,
        height - player.size,
      );
    if (intent != FishIntent.explore) {
      _heading = math.atan2(player.vy, player.vx);
    }
  }

  /// The heading that keeps the player's fish farthest from every predator:
  /// each of [_headings] directions is swum a little over a second ahead,
  /// sliding along any wall it meets, while the predators swim at the fish,
  /// and scored by the closest it lets any of them come, how much open water
  /// it ends in, and how near it gets to the part of the sea farthest from
  /// them all. Running into a wall or a corner stalls a path, so it scores
  /// low, and slipping past a predator scores well when that keeps a gap.
  (double, double) _escape(double speed, List<Fish> threats) {
    if (threats.isEmpty) {
      _route = null;
      return (math.cos(_heading), math.sin(_heading));
    }
    final (safeX, safeY) = _safe = _safestSpot(threats, _safe);
    (double, double) score(double angle) {
      final (ux, uy) = (math.cos(angle), math.sin(angle));
      final (gap, end, x, y, clear) = _lookAhead(ux, uy, speed, threats);
      final toSafe = math.sqrt(
        (x - safeX) * (x - safeX) + (y - safeY) * (y - safeY),
      );
      // The distance a heading wins from the predators counts most, and the
      // closest they come on the way keeps it safe. The pull toward the open
      // water farthest from them fades in as the fish gets clear, so up close
      // only distance counts.
      final room = ((end - 50) / 150).clamp(0.0, 1.0);
      // A route the look-ahead says brings a predator within 30 units, let
      // alone through it, never wins, however open the water it ends in.
      return (
        end +
            0.5 * gap +
            0.6 * math.min(clear, 150) -
            0.15 * room * toSafe -
            8 * math.max(0, 30 - gap),
        gap,
      );
    }

    var best = 0.0;
    var bestScore = double.negativeInfinity;
    for (var i = 0; i < _headings; i++) {
      final angle = i * 2 * math.pi / _headings;
      final (value, _) = score(angle);
      if (value > bestScore) {
        bestScore = value;
        best = angle;
      }
    }
    // The fish keeps its route for a while unless another is clearly better
    // or the route turns dangerous: switching between near-equal escapes each
    // tick leaves it swimming nowhere.
    final route = _route;
    if (route == null) {
      _route = best;
      _held = 0;
    } else {
      final (value, gap) = score(route);
      _held++;
      if (gap < 15 || (_held > 18 && bestScore > value + 12)) {
        _route = best;
        _held = 0;
      }
    }
    return (math.cos(_route!), math.sin(_route!));
  }

  /// Toward [prey], unless that brings a predator close: among the headings,
  /// the one that best closes on the prey while keeping 80 units from any.
  (double, double) _pursue(double speed, Fish prey, List<Fish> threats) {
    final aimX = prey.x + prey.vx * 0.3 - player.x;
    final aimY = prey.y + prey.vy * 0.3 - player.y;
    final aim = math.max(1e-6, math.sqrt(aimX * aimX + aimY * aimY));
    if (threats.isEmpty) return (aimX / aim, aimY / aim);
    var best = (aimX / aim, aimY / aim);
    var bestScore = double.negativeInfinity;
    for (var i = 0; i < _headings; i++) {
      final angle = i * 2 * math.pi / _headings;
      final (ux, uy) = (math.cos(angle), math.sin(angle));
      final (gap, _, _, _, _) = _lookAhead(ux, uy, speed, threats);
      final toward = (ux * aimX + uy * aimY) / aim;
      final score = 100 * toward - 6 * math.max(0, 80 - gap);
      if (score > bestScore) {
        bestScore = score;
        best = (ux, uy);
      }
    }
    return best;
  }

  /// A slow wander that turns away from walls.
  (double, double) _wander(double dt) {
    _heading += (_random.nextDouble() - 0.5) * dt * 3;
    var dx = math.cos(_heading);
    var dy = math.sin(_heading) * 0.6;
    const margin = 80.0;
    if (player.x < margin) dx += (margin - player.x) / margin * 2;
    if (player.x > width - margin) {
      dx -= (player.x - width + margin) / margin * 2;
    }
    if (player.y < margin) dy += (margin - player.y) / margin * 2;
    if (player.y > height - margin) {
      dy -= (player.y - height + margin) / margin * 2;
    }
    final length = math.max(1e-6, math.sqrt(dx * dx + dy * dy));
    return (dx / length, dy / length);
  }

  /// Swims heading ([ux], [uy]) for 1.8 seconds in twelve steps, sliding
  /// along walls, and returns the smallest gap to any predator on the way,
  /// the gap at the end, and where the fish ends up. Each predator is
  /// followed twice and the worse counts: chasing the fish head-on, and
  /// turning as the world turns it, with its momentum, which catches a fish
  /// that cuts across its path.
  (double, double, double, double, double) _lookAhead(
    double ux,
    double uy,
    double speed,
    List<Fish> threats,
  ) {
    const steps = 12;
    const step = 1.8 / steps;
    var x = player.x;
    var y = player.y;
    final chasing = [for (final fish in threats) (fish.x, fish.y)];
    final drifting = [for (final fish in threats) (fish.x, fish.y)];
    final velocities = [for (final fish in threats) (fish.vx, fish.vy)];
    var gap = double.infinity;
    var last = double.infinity;
    var clear = double.infinity;
    for (var s = 0; s < steps; s++) {
      x = (x + ux * speed * step).clamp(player.size, width - player.size);
      y = (y + uy * speed * step).clamp(player.size, height - player.size);
      clear = math.min(clear, _clearance(x, y));
      last = double.infinity;
      for (var k = 0; k < threats.length; k++) {
        var (cx, cy) = chasing[k];
        final dx = x - cx;
        final dy = y - cy;
        final length = math.max(1.0, math.sqrt(dx * dx + dy * dy));
        cx += dx / length * predatorSpeed * step;
        cy += dy / length * predatorSpeed * step;
        chasing[k] = (cx, cy);
        var (mx, my) = drifting[k];
        final (vx, vy) = _hunt(
          mx,
          my,
          velocities[k].$1,
          velocities[k].$2,
          x,
          y,
          step,
        );
        mx += vx * step;
        my += vy * step;
        drifting[k] = (mx, my);
        velocities[k] = (vx, vy);
        final reach = threats[k].size + player.size;
        final between = math.min(
          math.sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy)),
          math.sqrt((x - mx) * (x - mx) + (y - my) * (y - my)),
        );
        gap = math.min(gap, between - reach);
        last = math.min(last, between - reach);
      }
    }
    return (gap, last, x, y, clear);
  }

  /// The open water farthest from every predator: the best of a grid of
  /// points across the sea, away from the walls. The [current] spot stays
  /// until another is clearly better, so the fish does not chase a spot that
  /// hops as the predators move.
  (double, double) _safestSpot(List<Fish> threats, (double, double)? current) {
    double value(double x, double y) {
      var nearest = double.infinity;
      for (final fish in threats) {
        final distance = math.sqrt(
          (x - fish.x) * (x - fish.x) + (y - fish.y) * (y - fish.y),
        );
        nearest = math.min(nearest, distance - fish.size);
      }
      return nearest + 0.5 * math.min(_clearance(x, y), 150);
    }

    var best = current ?? (width / 2, height / 2);
    var bestScore = value(best.$1, best.$2) + (current == null ? 0 : 40);
    for (var gx = 1; gx < 10; gx++) {
      for (var gy = 1; gy < 6; gy++) {
        final x = width * gx / 10;
        final y = height * gy / 6;
        final score = value(x, y);
        if (score > bestScore) {
          bestScore = score;
          best = (x, y);
        }
      }
    }
    return best;
  }

  /// A predator's new velocity after [dt] seconds of turning toward the
  /// player's fish at ([px], [py]): slowly, so it keeps its momentum.
  static (double, double) _hunt(
    double x,
    double y,
    double vx,
    double vy,
    double px,
    double py,
    double dt,
  ) {
    final dx = px - x;
    final dy = py - y;
    final length = math.max(1.0, math.sqrt(dx * dx + dy * dy));
    final turn = math.min(1.0, dt * 0.8);
    return (
      vx + (dx / length * predatorSpeed - vx) * turn,
      vy + (dy / length * predatorSpeed - vy) * turn,
    );
  }

  /// How far ([x], [y]) is from the nearest wall.
  static double _clearance(double x, double y) =>
      math.min(math.min(x, width - x), math.min(y, height - y));

  void _collide() {
    for (final fish in [...others]) {
      if (_distance(player, fish) > (player.size + fish.size) * 0.75) continue;
      if (canEat(fish)) {
        others.remove(fish);
        eaten++;
        // Area grows by a quarter of the meal's.
        player.size = math.sqrt(
          player.size * player.size + 0.25 * fish.size * fish.size,
        );
      } else if (fish.size > player.size * 1.1) {
        lost++;
        player = Fish(0, null, width / 2, height / 2, startSize);
        others.removeWhere((other) => _distance(player, other) < 250);
        return;
      }
    }
  }

  /// A fish entering from either side, sized around the player's so the sea
  /// holds both prey and predators.
  Fish _spawn({bool anywhere = false}) {
    final wanted = player.size * math.exp((_random.nextDouble() - 0.45) * 2.4);
    final species = fishSpecies.reduce(
      (a, b) => (a.size - wanted).abs() <= (b.size - wanted).abs() ? a : b,
    );
    final left = _random.nextBool();
    final speed = 40 + _random.nextDouble() * 70;
    final x = anywhere
        ? _random.nextDouble() * width
        : left
        ? -species.size * 2
        : width + species.size * 2;
    var y = species.size + _random.nextDouble() * (height - 2 * species.size);
    // Nothing starts on top of the player.
    if (anywhere && (x - player.x).abs() < 200 && (y - player.y).abs() < 150) {
      y = y < player.y ? species.size : height - species.size;
    }
    return Fish(
      _nextId++,
      species,
      x,
      y,
      species.size,
      vx: left ? speed : -speed,
    )..vy = (_random.nextDouble() - 0.5) * 20;
  }

  static double _distance(Fish a, Fish b) =>
      math.sqrt((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y));
}

/// The model's answer to one sentence.
typedef FishAnswer = ({
  FishIntent intent,
  Map<FishIntent, double> probabilities,
});

/// One decision as the page shows it.
typedef FishDecision = ({
  String text,
  FishAnswer answer,
  double milliseconds,
  bool matched,
});

/// The world and the model together: each tick asks the model when the
/// encounter changed, unless an answer is still on its way, then moves the
/// world on the latest answer.
final class FishGame {
  FishGame({required this.decide, int seed = 7})
    : world = FishWorld(seed: seed);

  /// Asks the model about one sentence.
  Future<FishAnswer> Function(String text) decide;

  final FishWorld world;
  FishIntent intent = FishIntent.explore;
  int? _target;
  String? _asked;
  bool _waiting = false;

  /// The latest decision, for the page's thought bubble.
  FishDecision? last;

  /// Decisions made, and how many chose what the scene called for.
  int decisions = 0;
  int matched = 0;

  /// The model's failure, which stops the game.
  Object? error;

  /// One tick of [dt] seconds.
  void tick(double dt) {
    if (error != null) return;
    final encounter = world.encounter;
    final key = encounter == null
        ? 'none'
        : '${encounter.fish.id}:${encounter.prey}';
    if (!_waiting && key != _asked) {
      _asked = key;
      _ask(encounter);
    }
    world.step(dt, intent, _target);
  }

  /// Starts over, keeping the model.
  void restart() {
    world.reset();
    intent = FishIntent.explore;
    _target = null;
    _asked = null;
    last = null;
    decisions = 0;
    matched = 0;
    error = null;
  }

  Future<void> _ask(FishEncounter? encounter) async {
    _waiting = true;
    final text = describeEncounter(encounter);
    final clock = Stopwatch()..start();
    try {
      final answer = await decide(text);
      final right = answer.intent == expectedIntent(encounter);
      intent = answer.intent;
      _target = encounter?.fish.id;
      decisions++;
      if (right) matched++;
      last = (
        text: text,
        answer: answer,
        milliseconds: clock.elapsedMicroseconds / 1000,
        matched: right,
      );
    } on Object catch (failure) {
      error = failure;
    } finally {
      _waiting = false;
    }
  }
}
