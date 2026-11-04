import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mediapipe_decision/mediapipe_decision.dart';
import 'package:mediapipe_gallery/catalog.dart' show preferredDelegate;
import 'package:mediapipe_gallery/main.dart' show GalleryAssets;

// Decision Maker inside the gallery app, beside the vision runtimes: Google's
// library must load and answer as Google's Python API does on Android, iOS,
// macOS arm64, Linux x64 and Windows x64. The package's native test covers
// every reference case; this checks the app build, its model download and
// the runtime together.
const _texts = [
  'My order arrived broken and I want my money back.',
  'Thanks, everything was perfect and it arrived early.',
];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Decision Maker answers as Google\'s Python API does', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final assets = await GalleryAssets.unpack();
      if (!assets.bundledTasks.contains('decision_maker')) {
        markTestSkipped('This build bundles no Decision Maker.');
        return;
      }
      final capabilities = await queryDecisionMakerCapabilities();
      if (!capabilities.isSupported) {
        await expectLater(
          DecisionMaker.create(
            DecisionMakerOptions(model: DecisionModels.layaS256),
          ),
          throwsA(isA<RuntimeUnavailableException>()),
        );
        markTestSkipped('Decision Maker: ${capabilities.unavailableReasons}');
        return;
      }
      // Google's 678 MB model, downloaded and verified once into the model
      // cache (natively), or fetched by Google's runtime (in browsers).
      final task = await DecisionMaker.create(
        DecisionMakerOptions(
          modelPath: await GalleryAssets.downloadedModelPath(
            DecisionModels.layaS256,
          ),
          delegate: preferredDelegate(capabilities.supportedDelegates),
        ),
      );
      try {
        // Another desktop's build of Google's library may differ slightly
        // from the macOS wheel the expectations came from.
        const tolerance = 0.02;
        final refund = BooleanQuestion('The customer wants a refund.');
        final yes = await task.evaluateBoolean(_texts[0], refund);
        expect(yes.value, isTrue);
        expect(yes.probabilityTrue, closeTo(0.7654309, tolerance));
        final batch = await task.evaluateBooleanBatch(_texts, refund);
        expect([for (final r in batch) r.value], [true, false]);
        expect(batch[1].probabilityTrue, closeTo(0.0639984, tolerance));

        final topic = ChoiceQuestion({
          'shipping': 'A problem with delivery or a damaged package',
          'billing': 'A question about a charge or a refund',
          'account': 'A question about the account or its settings',
          'other': 'Anything else',
        });
        final choice = await task.evaluateChoice(_texts[0], topic);
        expect(choice.selectedKey, 'shipping');
        expect(choice.probabilities.keys, topic.criteria.keys);
        expect(choice.probabilities['shipping'], closeTo(0.9902245, tolerance));
        expect(choice.confidence, closeTo(0.9531919, tolerance));
        expect(choice.predictionSet, ['shipping']);

        final mood = ScoreQuestion([
          'very unhappy',
          'unhappy',
          'neutral',
          'happy',
          'very happy',
        ]);
        final scores = await task.evaluateScoreBatch(_texts, mood);
        expect(scores[0].expectedScore, closeTo(1.2759472, tolerance));
        expect(scores[1].expectedScore, closeTo(2.0197949, tolerance));
        expect(scores[0].probabilities, hasLength(5));
        expect(scores[0].selectedKey, '1');
      } finally {
        await task.dispose();
      }
    });
  });
}
