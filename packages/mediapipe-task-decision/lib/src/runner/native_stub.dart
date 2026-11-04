/// Browsers have no native runtime: Decision Maker runs through the
/// registered browser plugin, so reaching this means it did not register.
library;

import 'package:mediapipe_core/platform_interface.dart'
    show pluginNotRegistered;

import '../decision_backend.dart';
import '../types/options.dart';

/// The native Decision Maker; browsers have none.
Future<DecisionBackend> openNativeDecisionMaker(
  DecisionMakerOptions options,
) async => throw pluginNotRegistered('mediapipe_decision');
