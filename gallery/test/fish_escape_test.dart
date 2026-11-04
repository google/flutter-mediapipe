import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:mediapipe_gallery/fish/fish_game.dart';

/// Where a loss happened: in a corner, against one wall, or in open water.
enum _Where { corner, wall, open }

_Where _where(double x, double y) {
  const near = 90.0;
  final walls = [
    x < near,
    x > FishWorld.width - near,
    y < near,
    y > FishWorld.height - near,
  ].where((wall) => wall).length;
  return walls >= 2
      ? _Where.corner
      : walls == 1
      ? _Where.wall
      : _Where.open;
}

/// Plays [games] games of [seconds] each with a model that always chooses
/// what the scene calls for and answers [latencyTicks] ticks later, as the
/// real models do in about 60 ms, and logs every loss.
Future<
  ({
    int lost,
    int eaten,
    Map<_Where, int> where,
    List<String> log,
    double fleeSpeed,
  })
>
_simulate({int games = 40, int seconds = 120, int latencyTicks = 4}) async {
  var lost = 0;
  var eaten = 0;
  final where = {for (final place in _Where.values) place: 0};
  final log = <String>[];
  var fleeing = 0;
  var fleeSpeed = 0.0;
  for (var seed = 1; seed <= games; seed++) {
    var tick = 0;
    final answers = <(int, Completer<FishAnswer>, FishIntent)>[];
    final game = FishGame(
      seed: seed,
      decide: (text) {
        final intent = text.startsWith('Prey')
            ? FishIntent.chase
            : text.startsWith('Predator')
            ? FishIntent.flee
            : FishIntent.explore;
        final answer = Completer<FishAnswer>();
        answers.add((tick + latencyTicks, answer, intent));
        return answer.future;
      },
    );
    for (; tick < seconds * 60; tick++) {
      final world = game.world;
      final (x, y, size) = (world.player.x, world.player.y, world.player.size);
      final losses = world.lost;
      final intent = game.intent;
      if (intent == FishIntent.flee && game.world.encounter?.prey == false) {
        fleeing++;
        fleeSpeed += math.sqrt(
          world.player.vx * world.player.vx + world.player.vy * world.player.vy,
        );
      }
      game.tick(1 / 60);
      for (final pending in [...answers]) {
        if (pending.$1 <= tick) {
          pending.$2.complete((
            intent: pending.$3,
            probabilities: {pending.$3: 1.0},
          ));
          answers.remove(pending);
        }
      }
      await Future<void>.delayed(Duration.zero);
      if (world.lost > losses) {
        final place = _where(x, y);
        where[place] = where[place]! + 1;
        log.add(
          'game $seed t=${(tick / 60).toStringAsFixed(1)}s '
          'at (${x.toStringAsFixed(0)}, ${y.toStringAsFixed(0)}) '
          '${place.name}, size ${size.toStringAsFixed(0)}, '
          'intent ${intent.name}',
        );
      }
    }
    lost += game.world.lost;
    eaten += game.world.eaten;
  }
  return (
    lost: lost,
    eaten: eaten,
    where: where,
    log: log,
    fleeSpeed: fleeing == 0 ? 0.0 : fleeSpeed / fleeing,
  );
}

void main() {
  test(
    'a correctly decided fish escapes predators instead of cornering',
    () async {
      final result = await _simulate();
      // The game's log, for watching where the fish dies.
      // ignore: avoid_print
      print(
        'FISH_SIMULATION lost ${result.lost}, eaten ${result.eaten}, '
        'where ${result.where}, mean speed fleeing '
        '${result.fleeSpeed.toStringAsFixed(0)}',
      );
      for (final line in result.log.take(20)) {
        // ignore: avoid_print
        print('FISH_LOSS $line');
      }
      // 40 games of two minutes, with a model that never errs. Before the
      // look-ahead escape the fish lost 5.5 times a game, 88% of them against
      // a wall or in a corner.
      final walled = result.where[_Where.corner]! + result.where[_Where.wall]!;
      expect(result.lost, lessThanOrEqualTo(20), reason: '${result.where}');
      expect(walled, lessThanOrEqualTo(10), reason: '${result.where}');
      expect(result.eaten, greaterThanOrEqualTo(300));
      expect(
        result.fleeSpeed,
        greaterThan(120),
        reason: 'it runs, not dithers',
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
