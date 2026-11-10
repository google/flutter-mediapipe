import 'package:mediapipe_decision/mediapipe_decision.dart';

Future<void> decide() async {
  final capabilities = await queryDecisionMakerCapabilities();
  final task = await DecisionMaker.create(
    DecisionMakerOptions(
      model: DecisionModels.layaS256,
      // The CPU natively, the GPU in browsers.
      delegate: capabilities.supportedDelegates.first,
    ),
  );
  try {
    const text = 'My order arrived broken and I want my money back.';
    final refund = await task.evaluateBoolean(
      text,
      BooleanQuestion('The customer wants a refund.'),
    );
    final topic = await task.evaluateChoice(
      text,
      ChoiceQuestion({
        'shipping': 'A problem with delivery or a damaged package',
        'billing': 'A question about a charge or a refund',
        'other': 'Anything else',
      }),
    );
    final mood = await task.evaluateScore(
      text,
      ScoreQuestion(['very unhappy', 'unhappy', 'neutral', 'happy']),
    );
    print('${refund.value} ${topic.selectedKey} ${mood.expectedScore}');
  } finally {
    await task.dispose();
  }
}
