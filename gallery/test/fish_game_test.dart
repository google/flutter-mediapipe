import 'package:flutter_test/flutter_test.dart';
import 'package:mediapipe_gallery/fish/fish_game.dart';

FishSpecies _species(String name) =>
    fishSpecies.firstWhere((species) => species.name == name);

void main() {
  test('the model reads names and relative size only', () {
    final world = FishWorld();
    final sardine = Fish(1, _species('sardine'), 0, 0, 11);
    final shark = Fish(2, _species('shark'), 0, 0, 76);
    expect(describeEncounter(null), 'No fish nearby.');
    expect(
      describeEncounter((fish: sardine, prey: true)),
      'Prey nearby: a sardine, smaller than you.',
    );
    expect(
      describeEncounter((fish: shark, prey: false)),
      'Predator nearby: a shark, bigger than you.',
    );
    expect(expectedIntent(null), FishIntent.explore);
    expect(expectedIntent((fish: sardine, prey: true)), FishIntent.chase);
    expect(expectedIntent((fish: shark, prey: false)), FishIntent.flee);
    // Every name takes "a", the article both models were checked with.
    for (final species in fishSpecies) {
      expect(species.name[0], isNot(isIn('aeiou'.split(''))));
    }
    final puffer = Fish(3, _species('pufferfish'), 0, 0, 15);
    expect(world.canEat(sardine), isTrue, reason: '14 is 10% over 11');
    expect(world.canEat(puffer), isFalse);
    world.player.size = 17;
    expect(world.canEat(puffer), isTrue);
  });

  test('eating grows the fish; a bigger one starts it over', () {
    final world = FishWorld()..others.clear();
    final start = world.player.size;
    final shrimp = Fish(
      1,
      _species('shrimp'),
      world.player.x,
      world.player.y,
      6,
    );
    world.others.add(shrimp);
    world.step(1 / 60, FishIntent.explore, null);
    expect(world.eaten, 1);
    expect(world.player.size, greaterThan(start));
    expect(world.others, isNot(contains(shrimp)));

    world.others
      ..clear()
      ..add(Fish(2, _species('shark'), world.player.x, world.player.y, 76));
    world.step(1 / 60, FishIntent.explore, null);
    expect(world.lost, 1);
    expect(world.player.size, FishWorld.startSize);
    expect(world.others, hasLength(FishWorld.population));
  });

  test('the game asks once per encounter and scores each answer', () async {
    final asked = <String>[];
    final game = FishGame(
      decide: (text) async {
        asked.add(text);
        final intent = text.startsWith('Prey')
            ? FishIntent.chase
            : text.startsWith('Predator')
            ? FishIntent.flee
            : FishIntent.explore;
        return (intent: intent, probabilities: {intent: 1.0});
      },
    );
    for (var i = 0; i < 600; i++) {
      game.tick(1 / 60);
      await Future<void>.delayed(Duration.zero);
    }
    expect(asked, isNotEmpty);
    expect(game.decisions, asked.length);
    expect(game.matched, game.decisions);
    // Consecutive questions are about different encounters.
    for (var i = 1; i < asked.length; i++) {
      expect(
        asked[i] == 'No fish nearby.' && asked[i - 1] == asked[i],
        isFalse,
      );
    }
  });

  test(
    'a wrong answer is scored as such, and a failure stops the game',
    () async {
      final game = FishGame(
        decide: (text) async =>
            (intent: FishIntent.flee, probabilities: {FishIntent.flee: 1.0}),
      );
      game.world.others.clear();
      game.tick(1 / 60);
      await Future<void>.delayed(Duration.zero);
      expect(game.last!.text, 'No fish nearby.');
      expect(game.last!.matched, isFalse);
      expect(game.matched, 0);

      game
        ..restart()
        ..decide = (_) async => throw StateError('model failed');
      game.tick(1 / 60);
      await Future<void>.delayed(Duration.zero);
      expect(game.error, isA<StateError>());
      final x = game.world.player.x;
      game.tick(1 / 60);
      expect(game.world.player.x, x, reason: 'the game stops on a failure');
    },
  );
}
