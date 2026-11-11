import 'package:mediapipe_decision/mediapipe_decision.dart';

Future<void> triage(List<String> messages) async {
  final capabilities = await queryDecisionMakerCapabilities();
  final task = await DecisionMaker.create(
    DecisionMakerOptions(
      model: DecisionModels.layaS256,
      // The CPU natively, the GPU in browsers.
      delegate: capabilities.supportedDelegates.first,
    ),
  );
  try {
    const prefix = 'A message to our support team:';
    const rubric = ['very unhappy', 'unhappy', 'neutral', 'happy'];
    final refunds = await task.evaluateBooleanBatch(
      messages,
      BooleanQuestion('The customer wants a refund.'),
      sharedPrefix: prefix,
    );
    final topics = await task.evaluateChoiceBatch(
      messages,
      ChoiceQuestion(
        {
          'shipping': 'A problem with delivery or a damaged package',
          'billing': 'A question about a charge or a refund',
          'other': 'Anything else',
        },
        instructions: 'Choose the team that should answer the message.',
        scoringMode: ChoiceScoringMode.fullOption,
      ),
      sharedPrefix: prefix,
    );
    final moods = await task.evaluateScoreBatch(
      messages,
      ScoreQuestion(
        rubric,
        instructions: 'Rate how the customer feels.',
        temperature: 0.5,
      ),
      sharedPrefix: prefix,
    );
    for (var i = 0; i < messages.length; i++) {
      // A score's selectedKey is the index of its level, as text.
      final mood = rubric[int.parse(moods[i].selectedKey)];
      print(
        '"${messages[i]}" refund: ${refunds[i].value}, '
        'topic: ${topics[i].selectedKey}, mood: $mood',
      );
    }
  } finally {
    await task.dispose();
  }
}
