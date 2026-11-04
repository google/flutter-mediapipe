/// Decision Maker's options: core's model source and delegate plus Google's
/// token limit, validated the same way on every platform.
library;

import 'package:mediapipe_core/mediapipe_core.dart';

import '../../models.dart' show DecisionModels;

/// Options for Google's Decision Maker.
final class DecisionMakerOptions extends TaskOptions {
  /// [maxNumTokens] of 0, the default, keeps the model's own token budget.
  DecisionMakerOptions({
    super.model,
    super.modelPath,
    super.modelBytes,
    super.delegate,
    this.maxNumTokens = 0,
  }) : super(family: 'mediapipe_decision', registry: DecisionModels.byName) {
    if (maxNumTokens < 0) {
      throw ArgumentError.value(maxNumTokens, 'maxNumTokens', 'Must be >= 0.');
    }
  }

  /// The most tokens of input context Google's engine reads, or 0 for the
  /// model's own budget (512 for EmbeddingGemma 2).
  ///
  /// Google's engine reserves memory for the whole budget when the task is
  /// created, whatever each input's length, and cuts a longer input off
  /// without an error. The memory grows much faster than the budget: with
  /// EmbeddingGemma 2 on a Mac's CPU, about 0.6 GB at 512 tokens, 1 GB at
  /// 2048 and 6.7 GB at 4096, Google's Python default, where iOS stops an
  /// iPhone 15 Pro app at about 3.4 GB. Raise it only for longer inputs, on a
  /// device with the memory for them (upstream-issues.md UP-060).
  final int maxNumTokens;
}
