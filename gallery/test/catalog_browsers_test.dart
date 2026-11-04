import 'package:flutter_test/flutter_test.dart';
import 'package:mediapipe_decision/mediapipe_decision.dart';
import 'package:mediapipe_decision/platform_interface.dart'
    show decisionBackendFactory;
import 'package:mediapipe_gallery/catalog.dart';
import 'package:mediapipe_gallery/live/task_models.dart';
import 'package:mediapipe_retrieval/platform_interface.dart'
    show retrievalBackendFactory;

/// A browser on a hardware WebGPU adapter, as each plugin names it.
TaskPlatform _browser(BrowserEngine engine) => TaskPlatform(
  operatingSystem: 'web',
  architecture: 'unknown',
  gpu: 'WebGPU apple apple',
  browserEngine: engine,
);

const _bundled = {'decision_maker', 'universal_embedder', 'semantic_retriever'};

void main() {
  setUp(() {
    decisionBackendFactory = (_) => throw UnimplementedError();
    retrievalBackendFactory = (_) => throw UnimplementedError();
  });
  tearDown(() {
    decisionBackendFactory = null;
    retrievalBackendFactory = null;
  });

  Set<String> tiles(TaskPlatform platform) => {
    for (final task in supportedTasks(platform, _bundled)) task.title,
  };
  String reason(TaskPlatform platform, String title) => plannedReason(
    plannedTasks.firstWhere((task) => task.title == title),
    platform,
    _bundled,
  );

  test('WebKit keeps Decision Maker on Laya, and shows Hungry Fish and the '
      'retrieval tasks as cards with their reason (UP-054)', () {
    final webKit = _browser(BrowserEngine.webkit);
    expect(tiles(webKit), {'Decision Maker'});
    for (final title in [
      'Hungry Fish',
      'Universal Embedder',
      'Semantic Retriever',
    ]) {
      expect(reason(webKit, title), contains('UP-054'), reason: title);
    }
    expect(fishGameModel(webKit), isNull);
  });

  test('Chromium keeps every decision and retrieval tile, and Hungry Fish its '
      'text-only model', () {
    final chromium = _browser(BrowserEngine.blink);
    expect(tiles(chromium), {
      'Decision Maker',
      'Hungry Fish',
      'Universal Embedder',
      'Semantic Retriever',
    });
    expect(fishGameModel(chromium), same(DecisionModels.embeddingGemma2Text));
  });

  test('native platforms play Hungry Fish on the text-only model', () {
    expect(
      fishGameModel(
        const TaskPlatform(
          operatingSystem: 'macos',
          architecture: 'arm64',
          version: '15.0',
        ),
      ),
      same(DecisionModels.embeddingGemma2Text),
    );
  });

  test('browsers offer no GLiNER2.5-Decide model (UP-055)', () {
    for (final engine in BrowserEngine.values) {
      final offered = [
        for (final model in taskModels['decision_maker']!)
          if (decisionRunsModel(_browser(engine), model)) model.name,
      ];
      expect(offered, ['Laya (512 tokens)'], reason: '$engine');
    }
    final native = [
      for (final model in taskModels['decision_maker']!)
        if (decisionRunsModel(
          const TaskPlatform(
            operatingSystem: 'macos',
            architecture: 'arm64',
            version: '15.0',
          ),
          model,
        ))
          model.name,
    ];
    expect(native, hasLength(3));
  });
}
