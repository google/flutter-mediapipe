import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mediapipe_gallery/fish/fish_game.dart';
import 'package:mediapipe_gallery/fish/fish_paint.dart';

FishSpecies _species(String name) =>
    fishSpecies.firstWhere((species) => species.name == name);

/// A world whose player has [playerSize] and faces right, with one fish of
/// [other]'s species ([dx], [dy]) from it, facing left when [left].
FishWorld _sea(
  double playerSize,
  String other,
  double dx,
  double dy, {
  bool left = false,
}) {
  final world = FishWorld()..others.clear();
  world.player
    ..size = playerSize
    ..vx = 1;
  final species = _species(other);
  world.others.add(
    Fish(
      1,
      species,
      world.player.x + dx,
      world.player.y + dy,
      species.size,
      vx: left ? -1 : 1,
    ),
  );
  return world;
}

String _point((double, double) point) =>
    '(${point.$1.toStringAsFixed(2)}, ${point.$2.toStringAsFixed(2)})';

/// Every point of [fish]'s shape, for reading a case in the test's output.
String _points(String who, Fish fish) {
  final nose =
      fish.x + (fish.facingLeft ? -1 : 1) * Fish.bodyHalfLength * fish.size;
  return '  $who size ${fish.size} center ${_point((fish.x, fish.y))} '
      'facing ${fish.facingLeft ? 'left' : 'right'} '
      'nose ${_point((nose, fish.y))}\n'
      '    tail ${fish.tailPoints.map(_point).join(' ')}\n'
      '    body ${fish.bodyPoints.map(_point).join(' ')}';
}

/// One fish alone, drawn by the page's own [paintFish], as its pixels.
final class _Mask {
  _Mask(this.side, this.alpha)
    : solid = [
        for (var i = 0; i < alpha.length; i++)
          if (alpha[i] >= 128 && _edge(side, alpha, i)) i,
      ];

  final int side;
  final Uint8List alpha;

  /// The solid pixels on the shape's edge: two shapes that overlap have one
  /// inside the other, the smaller's edge in the bigger's solid.
  final List<int> solid;

  static bool _edge(int side, Uint8List alpha, int i) =>
      i < side ||
      i >= alpha.length - side ||
      alpha[i - 1] < 128 ||
      alpha[i + 1] < 128 ||
      alpha[i - side] < 128 ||
      alpha[i + side] < 128;
}

/// Pixels per world unit in the rendered masks.
const _scale = 4;

Future<_Mask> _render(Fish fish) async {
  // Even, so that any two fish's centers land on the same pixel grid.
  final side = ((fish.reach + 2) * _scale).ceil() * 2;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(_scale.toDouble());
  final at = Fish(
    fish.id,
    fish.species,
    side / 2 / _scale,
    side / 2 / _scale,
    fish.size,
    vx: fish.vx,
  );
  paintFish(canvas, at, const Color(0xFF00FF00));
  final image = await recorder.endRecording().toImage(side, side);
  final bytes = await image.toByteData();
  image.dispose();
  final rgba = bytes!.buffer.asUint8List();
  return _Mask(
    side,
    Uint8List.fromList([for (var i = 3; i < rgba.length; i += 4) rgba[i]]),
  );
}

/// Whether [a]'s and [b]'s pixels share one with b's center ([px], [py])
/// pixels from a's, at least [threshold] opaque in both.
bool _pixelsTouch(_Mask a, _Mask b, int px, int py, {int threshold = 128}) {
  final (small, big, sign) = a.solid.length <= b.solid.length
      ? (a, b, 1)
      : (b, a, -1);
  final shift = (small.side - big.side) ~/ 2;
  bool hit(int i) {
    final x = i % small.side - sign * px - shift;
    final y = i ~/ small.side - sign * py - shift;
    return x >= 0 &&
        y >= 0 &&
        x < big.side &&
        y < big.side &&
        big.alpha[y * big.side + x] >= threshold;
  }

  if (threshold >= 128) return small.solid.any(hit);
  for (var i = 0; i < small.alpha.length; i++) {
    if (small.alpha[i] >= threshold && hit(i)) return true;
  }
  return false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The player's fish, size 14, reaches 18.05 ahead (1.2 × 14 and half its
  // outline), 26.6 behind (its tail) and 11.75 above and below. A pufferfish
  // reaches 18 ahead; a shark 91.2 ahead, 144.4 behind and 57 above.
  const cases =
      <
        ({
          String name,
          double player,
          String other,
          double dx,
          double dy,
          bool left,
          bool dies,
        })
      >[
        (
          name: 'nose to nose, overlapping by 1',
          player: 14,
          other: 'pufferfish',
          dx: 35.05,
          dy: 0,
          left: true,
          dies: true,
        ),
        (
          name: 'nose to nose, 1 apart',
          player: 14,
          other: 'pufferfish',
          dx: 37.05,
          dy: 0,
          left: true,
          dies: false,
        ),
        (
          name: 'side-on, deep inside',
          player: 14,
          other: 'shark',
          dx: 60,
          dy: 0,
          left: true,
          dies: true,
        ),
        (
          name: 'side-on, overlapping by 1',
          player: 14,
          other: 'shark',
          dx: 108.25,
          dy: 0,
          left: true,
          dies: true,
        ),
        (
          name: 'side-on, 1 apart',
          player: 14,
          other: 'shark',
          dx: 110.25,
          dy: 0,
          left: true,
          dies: false,
        ),
        (
          name: 'only its tail reaches the player',
          player: 14,
          other: 'shark',
          dx: 161.45,
          dy: 0,
          left: false,
          dies: true,
        ),
        (
          name: 'its tail, 1 apart',
          player: 14,
          other: 'shark',
          dx: 163.45,
          dy: 0,
          left: false,
          dies: false,
        ),
        (
          name: 'only the player\'s tail is reached',
          player: 14,
          other: 'shark',
          dx: -117,
          dy: 0,
          left: false,
          dies: true,
        ),
        (
          name: 'the player\'s tail, 1 apart',
          player: 14,
          other: 'shark',
          dx: -118.8,
          dy: 0,
          left: false,
          dies: false,
        ),
        (
          name: 'from above, overlapping by 1',
          player: 14,
          other: 'shark',
          dx: 0,
          dy: -67.75,
          left: true,
          dies: true,
        ),
        (
          name: 'from above, 1 apart',
          player: 14,
          other: 'shark',
          dx: 0,
          dy: -69.75,
          left: true,
          dies: false,
        ),
        (
          name: 'a fish 7% bigger',
          player: 14,
          other: 'pufferfish',
          dx: 20,
          dy: 0,
          left: true,
          dies: true,
        ),
        (
          name: 'a fish 1% bigger',
          player: 14.85,
          other: 'pufferfish',
          dx: 20,
          dy: 0,
          left: true,
          dies: true,
        ),
      ];

  group('touching a bigger fish kills the player', () {
    for (final item in cases) {
      test(item.name, () {
        final world = _sea(
          item.player,
          item.other,
          item.dx,
          item.dy,
          left: item.left,
        );
        // ignore: avoid_print
        print(
          'FISH_CASE ${item.name}: ${item.dies ? 'dies' : 'lives'}\n'
          '${_points('player', world.player)}\n'
          '${_points(item.other, world.others.single)}',
        );
        final (x, y) = (world.player.x, world.player.y);
        // No time passes, so the step only decides the collision.
        world.step(0, FishIntent.explore, null);
        expect(world.lost, item.dies ? 1 : 0);
        expect(world.eaten, 0);
        expect(
          world.player.size,
          item.dies ? FishWorld.startSize : item.player,
        );
        if (!item.dies) expect((world.player.x, world.player.y), (x, y));
      });
    }
  });

  test('touching a smaller fish eats it, however little bigger the player', () {
    for (final (name, size, dx) in [
      ('the side of a fish 3% smaller', 15.5, 20.0),
      ('the nose of a shrimp', 14.0, 25.0),
      ('the tail of a sardine', 14.0, 38.0),
    ]) {
      final world = _sea(
        size,
        switch (name) {
          'the side of a fish 3% smaller' => 'pufferfish',
          'the nose of a shrimp' => 'shrimp',
          _ => 'sardine',
        },
        dx,
        0,
        left: name != 'the tail of a sardine',
      );
      final fish = world.others.single;
      expect(fishTouch(world.player, fish), isTrue, reason: name);
      world.step(0, FishIntent.explore, null);
      expect(world.eaten, 1, reason: name);
      expect(world.lost, 0, reason: name);
      expect(world.others, isNot(contains(fish)), reason: name);
    }
  });

  test('two fish of the same size pass each other', () {
    final world = _sea(15, 'pufferfish', 5, 0);
    world.step(0, FishIntent.explore, null);
    expect(world.eaten, 0);
    expect(world.lost, 0);
  });

  test('a turn never swings the player\'s tail into a bigger fish', () {
    // The shark's nose is 5 from the player's, nearer than the player's tail
    // is long, so the turn away from it would put the tail in the shark.
    final world = _sea(14, 'shark', 114.25, 0, left: true);
    final shark = world.others.single;
    final turned = Fish(0, null, world.player.x, world.player.y, 14, vx: -1);
    expect(fishTouch(world.player, shark), isFalse);
    expect(fishTouch(turned, shark), isTrue);

    world.step(1 / 60, FishIntent.flee, shark.id);
    expect(
      world.player.vx,
      lessThan(0),
      reason: 'it swims away from the shark',
    );
    expect(world.player.facingLeft, isFalse, reason: 'tail first, for now');
    expect(fishTouch(world.player, shark), isFalse);

    for (var i = 0; i < 60; i++) {
      world.step(1 / 60, FishIntent.flee, shark.id);
    }
    expect(world.lost, 0);
    expect(world.player.facingLeft, isTrue, reason: 'with room, it turns');
  });

  test('a turn with room to spare happens at once', () {
    final world = _sea(14, 'shark', 200, 0, left: true);
    world.step(1 / 60, FishIntent.flee, world.others.single.id);
    expect(world.player.vx, lessThan(0));
    expect(world.player.facingLeft, isTrue);
  });

  test('a touch drawn before a fish turns still kills', () {
    // The shark's tail is on the player's nose, and in this very step the
    // shark turns to hunt it, which swings that tail away.
    final world = _sea(14, 'shark', 161.45, 0);
    final shark = world.others.single;
    expect(fishTouch(world.player, shark), isTrue);
    world.step(1 / 60, FishIntent.explore, null);
    expect(world.lost, 1);
  });

  test('a meal does not save the player from a bigger fish it touches', () {
    final world = _sea(14.9, 'pufferfish', 20, 0, left: true);
    final shrimp = _species('shrimp');
    world.others.insert(
      0,
      Fish(2, shrimp, world.player.x - 25, world.player.y, shrimp.size),
    );
    world.step(0, FishIntent.explore, null);
    expect(world.lost, 1);
    expect(world.eaten, 0);
  });

  test(
    'a touch past the sea\'s side, which the page clips, does not count',
    () {
      // The player's tail and the shark's nose overlap only left of the sea.
      final world = _sea(14, 'shark', -117, 0);
      world.player.x = 14;
      world.others.single.x = 14 - 117;
      final (player, shark) = (world.player, world.others.single);
      expect(
        player.tailPoints.map((point) => point.$1).reduce(math.min),
        closeTo(-12.6, 1e-9),
      );
      expect(fishTouch(player, shark), isFalse);
      world.step(0, FishIntent.explore, null);
      expect(world.lost, 0);

      // On the right side, too.
      final right = _sea(14, 'shark', 117, 0, left: true);
      right.player
        ..x = FishWorld.width - 14
        ..vx = -1;
      right.others.single.x = FishWorld.width - 14 + 117;
      expect(fishTouch(right.player, right.others.single), isFalse);

      // Once any of the contact is inside the sea, it counts: here the shark's
      // nose is 2 inside it, on the player's body.
      final inside = _sea(14, 'shark', -89.2, 0);
      inside.player.x = 14;
      inside.others.single.x = 2 - 91.2;
      expect(fishTouch(inside.player, inside.others.single), isTrue);
      inside.step(0, FishIntent.explore, null);
      expect(inside.lost, 1);
    },
  );

  test('a fish entering the sea cannot kill before it shows', () {
    final world = _sea(14, 'shark', 0, 0, left: false);
    world.player.x = 14;
    final shark = world.others.single..x = -92;
    expect(fishTouch(world.player, shark), isFalse);
    shark.x = -80;
    expect(fishTouch(world.player, shark), isTrue);
  });

  test('every touch drawn kills on the next tick, and nothing else does', () {
    bool touch(Fish fish, bool left, Fish other, bool otherLeft) => fishTouch(
      Fish(0, null, fish.x, fish.y, fish.size, vx: left ? -1 : 1),
      Fish(
        1,
        other.species,
        other.x,
        other.y,
        other.size,
        vx: otherLeft ? -1 : 1,
      ),
    );

    var deaths = 0;
    var ticks = 0;
    for (final steered in const [true, false]) {
      for (var seed = 1; seed <= 6; seed++) {
        final world = FishWorld(seed: seed);
        for (var tick = 0; tick < 7200; tick++) {
          final drawn = world.others.any(
            (fish) => world.dangerous(fish) && fishTouch(world.player, fish),
          );
          final lost = world.lost;
          final facing = {
            for (final fish in world.others) fish: fish.facingLeft,
          };
          final (player, playerLeft) = (world.player, world.player.facingLeft);
          final encounter = world.encounter;
          world.step(
            1 / 60,
            steered ? expectedIntent(encounter) : FishIntent.explore,
            encounter?.fish.id,
          );
          ticks++;
          expect(world.lost - lost, drawn ? 1 : 0, reason: 'seed $seed $tick');
          if (drawn || !identical(player, world.player)) continue;
          // A touch that starts now comes from swimming, not from a turn: it
          // is there with every fish still facing the way it was.
          for (final fish in world.others) {
            if (world.dangerous(fish) && fishTouch(player, fish)) {
              expect(
                touch(
                  player,
                  playerLeft,
                  fish,
                  facing[fish] ?? fish.facingLeft,
                ),
                isTrue,
                reason: 'seed $seed tick $tick ${fish.species!.name}',
              );
            }
          }
        }
        deaths += world.lost;
      }
    }
    // ignore: avoid_print
    print('FISH_DRAWN $ticks ticks, $deaths deaths, each after a drawn touch');
    expect(deaths, greaterThan(20), reason: 'the games really test this');
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('the collision shape is the drawn fish, at every position', () async {
    var positions = 0;
    var touching = 0;
    var missed = 0;
    var overshoot = 0;
    var oldMissed = 0;
    for (final playerSize in const [14.0, 40.0]) {
      for (final playerLeft in const [false, true]) {
        final (cx, cy) = (FishWorld.width / 2, FishWorld.height / 2);
        final player = Fish(
          0,
          null,
          cx,
          cy,
          playerSize,
          vx: playerLeft ? -1 : 1,
        );
        final playerMask = await _render(player);
        for (final name in const [
          'shrimp',
          'pufferfish',
          'shark',
          'killer whale',
        ]) {
          for (final left in const [false, true]) {
            final species = _species(name);
            final other = Fish(
              1,
              species,
              0,
              0,
              species.size,
              vx: left ? -1 : 1,
            );
            final otherMask = await _render(other);
            final reach = player.reach + other.reach + 4;
            final pixels = (reach * 2 * _scale / 41).ceil();
            for (var py = -20 * pixels; py <= 20 * pixels; py += pixels) {
              for (var px = -20 * pixels; px <= 20 * pixels; px += pixels) {
                other
                  ..x = cx + px / _scale
                  ..y = cy + py / _scale;
                positions++;
                final rule = fishTouch(player, other);
                final seen = _pixelsTouch(playerMask, otherMask, px, py);
                if (seen) {
                  touching++;
                  if (!rule) {
                    missed++;
                    // ignore: avoid_print
                    print(
                      'FISH_MISSED $name at (${other.x}, ${other.y})\n'
                      '${_points('player', player)}\n${_points(name, other)}',
                    );
                  }
                  final distance = (px * px + py * py) / (_scale * _scale);
                  final old = (playerSize + species.size) * 0.75;
                  if (distance > old * old) oldMissed++;
                } else if (rule) {
                  // Within three quarters of a unit of the pixels is fine: the
                  // polygon stands just outside the oval and pixels are blunt.
                  final near = [
                    for (final sx in const [-3, 0, 3])
                      for (final sy in const [-3, 0, 3])
                        _pixelsTouch(
                          playerMask,
                          otherMask,
                          px + sx,
                          py + sy,
                          threshold: 1,
                        ),
                  ].any((hit) => hit);
                  if (!near) overshoot++;
                }
              }
            }
          }
        }
      }
    }
    // ignore: avoid_print
    print(
      'FISH_SWEEP $positions positions, $touching touching on screen, '
      'rule missed $missed, overshot $overshoot; '
      'the old rule missed $oldMissed',
    );
    expect(touching, greaterThan(1000));
    expect(missed, 0);
    expect(overshoot, 0);
    expect(oldMissed, greaterThan(0), reason: 'the sweep finds the old bug');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
