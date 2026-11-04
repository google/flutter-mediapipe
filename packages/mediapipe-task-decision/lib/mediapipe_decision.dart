/// Google's MediaPipe Decision Maker: yes-or-no, choice and score questions
/// about a text, answered with calibrated probabilities on Android, iOS,
/// macOS, Linux, Windows and the web.
///
/// `DecisionMaker` has `static create(options)`, Google's verbs
/// (`evaluateBoolean`, `evaluateChoice`, `evaluateScore` and their batch
/// forms), a `delegate` getter and `dispose()`. What a platform's runtime
/// cannot do throws `RuntimeUnavailableException`, and
/// `queryDecisionMakerCapabilities()` reports it in advance.
library;

export 'package:mediapipe_core/mediapipe_core.dart';

export 'models.dart' show DecisionModels;
export 'src/capabilities.dart'
    show decisionMakerCapabilitiesForPlatform, queryDecisionMakerCapabilities;
export 'src/decision_maker.dart';
export 'src/types/options.dart';
export 'src/types/questions.dart';
export 'src/types/results.dart';
