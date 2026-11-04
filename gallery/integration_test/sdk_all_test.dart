import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'sdk_face_landmarker_test.dart' as face;
import 'decision_maker_test.dart' as decision;
import 'gallery_journey_test.dart' as journey;
import 'retrieval_test.dart' as retrieval;
import 'runtime_test.dart' as runtime;
import 'sdk_detection_tasks_test.dart' as detection;
import 'sdk_embedder_test.dart' as embedder;
import 'sdk_hand_landmarker_test.dart' as hand;
import 'sdk_interactive_segmenter_test.dart' as interactive;
import 'sdk_landmark_tasks_test.dart' as landmarks;
import 'sdk_modern_text_test.dart' as modern_text;
import 'sdk_segmenter_test.dart' as segmenter;
import 'sdk_text_audio_test.dart' as text_audio;
import 'telemetry_probe_test.dart' as telemetry;

// Every phone suite in one app launch: on Firebase Test Lab, where each
// device run counts against a small daily quota, and on the CI emulator, where
// each extra install and launch risked losing the emulator. Build with
// SDK_GPU=required on a physical device so a GPU refusal fails its test instead
// of being recorded.
// The live tiles run after the suites: they open the camera, which is dark in a
// device rack. The gallery journey comes last and opens every page the way a
// user does, through the sidebar.
// EmbeddingGemma, Proofreader and Summarizer join with SDK_MODERN_TEXT, which
// the Test Lab build sets: one phone execution covers every suite, while the
// CI emulator runs them as a launch of their own, since the generative models
// take minutes on an emulated CPU. Decision Maker and the retrieval tasks run
// when the build bundles them, and skip otherwise. TELEMETRY_PROBE, also set
// by the Test Lab build, first watches the sockets Google's usage logger opens
// when tasks close, before any other suite has run.
void main() {
  // The binding reports the run as finished to Android from a tearDownAll it
  // registers when first created. Created inside a suite's group, it would end
  // the instrumentation after that group; created here, after every group.
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (const bool.fromEnvironment('TELEMETRY_PROBE')) {
    group('telemetry probe', telemetry.main);
  }
  group('face landmarker', face.main);
  group('hand', hand.main);
  group('landmark tasks', landmarks.main);
  group('detection and classification', detection.main);
  group('embedder', embedder.main);
  group('segmenter', segmenter.main);
  group('interactive segmenter', interactive.main);
  group('text and audio', text_audio.main);
  group('decision maker', decision.main);
  group('retrieval', retrieval.main);
  if (const bool.fromEnvironment('SDK_MODERN_TEXT')) {
    group('modern text', modern_text.main);
  }
  group('live tiles', runtime.main);
  group('gallery journey', journey.main);
}
