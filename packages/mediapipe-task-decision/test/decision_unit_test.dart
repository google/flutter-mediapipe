import 'package:mediapipe_decision/mediapipe_decision.dart';
import 'package:mediapipe_decision/platform_interface.dart';
import 'package:mediapipe_decision/src/results/decoders.dart';
import 'package:test/test.dart';
import 'package:mediapipe_core/platform_interface.dart'
    show largeModelNeeds64Bit;

TaskPlatform _platform(String os, String arch, [String? version]) =>
    TaskPlatform(operatingSystem: os, architecture: arch, version: version);

const _arm32 = TaskPlatform(operatingSystem: 'android', architecture: 'arm');

void main() {
  test('32-bit Android refuses Decision Maker, its models need 64-bit', () {
    final capabilities = decisionMakerCapabilitiesForPlatform(_arm32);
    expect(capabilities.supportedDelegates, isEmpty);
    expect(capabilities.unavailableReasons[Delegate.cpu], largeModelNeeds64Bit);
    expect(capabilities.unavailableReasons[Delegate.gpu], largeModelNeeds64Bit);
  });

  group('questions are checked the same way everywhere', () {
    test(
      'a boolean needs a threshold in [0, 1] and a positive temperature',
      () {
        expect(() => BooleanQuestion('x', threshold: 1.5), throwsArgumentError);
        expect(() => BooleanQuestion('x', temperature: 0), throwsArgumentError);
        expect(() => BooleanQuestion(''), throwsArgumentError);
        expect(() => BooleanQuestion('a\u0000b'), throwsArgumentError);
        expect(BooleanQuestion('x').toJson(), {
          'condition': 'x',
          'threshold': 0.5,
          'temperature': null,
          'normalizePrior': false,
        });
      },
    );

    test('a choice needs two options and a rubric two levels', () {
      expect(() => ChoiceQuestion({'only': 'one'}), throwsArgumentError);
      expect(() => ChoiceQuestion({'': 'a', 'b': 'b'}), throwsArgumentError);
      expect(() => ScoreQuestion(['low']), throwsArgumentError);
      expect(
        ChoiceQuestion({
          'a': 'A',
          'b': '',
        }, scoringMode: ChoiceScoringMode.fullOption).toJson()['scoringMode'],
        2,
      );
    });

    test('options keep the model\'s token budget unless one is set', () {
      expect(DecisionMakerOptions(modelPath: 'm.task').maxNumTokens, 0);
      expect(
        DecisionMakerOptions(
          modelPath: 'm.task',
          maxNumTokens: 1024,
        ).maxNumTokens,
        1024,
      );
      expect(
        () => DecisionMakerOptions(modelPath: 'm.task', maxNumTokens: -1),
        throwsArgumentError,
      );
    });

    // Natively 0 reaches Google's C options, which read it as the model's
    // budget; the browser runtime gets no value instead.
    test('browsers get a token limit only when the app sets one', () async {
      final sent = <Object?>[];
      decisionBackendFactory = (options) async {
        sent.add(options['maxNumTokens']);
        return _IdleBackend();
      };
      addTearDown(() => decisionBackendFactory = null);
      for (final tokens in [0, 1024]) {
        final task = await DecisionMaker.create(
          DecisionMakerOptions(modelPath: 'm.task', maxNumTokens: tokens),
        );
        await task.dispose();
      }
      expect(sent, [null, 1024]);
    });
  });

  // The native and browser runtimes both receive toJson's scoringMode, which
  // must be Google's ScoringMode number: SCORING_AUTO 0, SCORING_SINGLE_TOKEN
  // 1 and SCORING_FULL_OPTION 2 in its Python decision_maker.py (1.1.0).
  test(
    'a choice sends every option, its scoring mode as Google numbers it',
    () {
      final criteria = {'yes': 'agrees', 'no': ''};
      for (final (mode, number) in [
        (ChoiceScoringMode.auto, 0),
        (ChoiceScoringMode.singleToken, 1),
        (ChoiceScoringMode.fullOption, 2),
      ]) {
        expect(
          ChoiceQuestion(
            criteria,
            instructions: 'Answer briefly.',
            temperature: .7,
            scoringMode: mode,
            normalizePrior: true,
          ).toJson(),
          {
            'criteria': criteria,
            'instructions': 'Answer briefly.',
            'temperature': .7,
            'scoringMode': number,
            'normalizePrior': true,
          },
          reason: '$mode',
        );
      }
      expect(ChoiceScoringMode.values, hasLength(3));
    },
  );

  group('results decode the same way from either runtime', () {
    final question = ChoiceQuestion({
      'shipping': 'Delivery',
      'billing': 'Charges',
      'other': 'Anything else',
    });

    test('choice probabilities follow the question, not the runtime', () {
      final result = decodeChoiceResult({
        'selectedKey': 'shipping',
        'probabilities': {'other': 0.01, 'shipping': 0.98, 'billing': 0.01},
        'confidence': 0.92,
      }, question);
      expect(result.probabilities.keys, ['shipping', 'billing', 'other']);
      expect(result.predictionSet, ['shipping']);
    });

    test('the prediction set covers 90% of the probability', () {
      final result = decodeChoiceResult({
        'selectedKey': 'billing',
        'probabilities': {'shipping': 0.3, 'billing': 0.65, 'other': 0.05},
        'confidence': 0.2,
      }, question);
      expect(result.predictionSet, ['billing', 'shipping']);
    });

    test('scores and booleans keep Google\'s numbers', () {
      final score = decodeScoreResult({
        'expectedScore': 1.25,
        'probabilities': [0.5, 0.25, 0.25],
        'confidence': 0.1,
        'selectedKey': '0',
      });
      expect(score.probabilities, [0.5, 0.25, 0.25]);
      expect(score.selectedKey, '0');
      final boolean = decodeBooleanResult({
        'value': true,
        'probabilityTrue': 1,
        'confidence': 1,
      });
      expect(boolean.probabilityTrue, 1.0);
    });
  });

  group('capabilities', () {
    test('the CPU on every native target', () {
      for (final (os, arch, version) in [
        ('macos', 'arm64', '15.0'),
        ('linux', 'x64', null),
        ('windows', 'x64', null),
        ('android', 'arm64', '14'),
        ('android', 'x64', '14'),
        ('ios', 'arm64', '17.0'),
      ]) {
        final capabilities = decisionMakerCapabilitiesForPlatform(
          _platform(os, arch, version),
        );
        expect(capabilities.supportedDelegates, {Delegate.cpu}, reason: os);
        expect(capabilities.runtimeVersion, '1.2.0', reason: os);
      }
      expect(
        decisionMakerCapabilitiesForPlatform(
          _platform('macos', 'arm64', '13.0'),
        ).isSupported,
        isFalse,
      );
    });

    test('every pinned native model runs wherever the task runs', () {
      for (final (os, arch, version) in [
        ('macos', 'arm64', '15.0'),
        ('linux', 'x64', null),
        ('windows', 'x64', null),
        ('android', 'arm64', '14'),
        ('android', 'x64', '14'),
        ('ios', 'arm64', '17.0'),
      ]) {
        final platform = _platform(os, arch, version);
        for (final model in [null, ...DecisionModels.byName.values]) {
          expect(
            decisionMakerCapabilitiesForPlatform(
              platform,
              model: model,
            ).supportedDelegates,
            {Delegate.cpu},
            reason: '$os $model',
          );
        }
      }
    });

    test('every pinned model has a bundling name', () {
      expect(DecisionModels.byName, hasLength(6));
      expect(
        DecisionModels.byName['embedding_gemma_2_text_vision'],
        same(DecisionModels.embeddingGemma2TextVision),
      );
      expect(
        DecisionModels.embeddingGemma2TextVision.sha256,
        isNot(DecisionModels.embeddingGemma2Text.sha256),
      );
    });

    test('browsers get the GPU on a hardware WebGPU adapter (UP-049)', () {
      TaskPlatform web(String? gpu) => TaskPlatform(
        operatingSystem: 'web',
        architecture: 'unknown',
        gpu: gpu,
      );
      const metal = 'WebGPU apple metal-3';
      expect(
        decisionMakerCapabilitiesForPlatform(web(metal)).isSupported,
        isFalse,
        reason: 'no plugin',
      );
      decisionBackendFactory = (_) => throw UnimplementedError();
      addTearDown(() => decisionBackendFactory = null);
      final capabilities = decisionMakerCapabilitiesForPlatform(web(metal));
      expect(capabilities.supportedDelegates, {Delegate.gpu});
      expect(capabilities.unavailableReasons[Delegate.cpu], contains('UP-049'));
      for (final gpu in [
        null,
        'WebGPU google swiftshader',
        'WebGPU apple metal-3 (fallback adapter)',
        'Mali-G715 (ARM)',
      ]) {
        final refused = decisionMakerCapabilitiesForPlatform(web(gpu));
        expect(refused.isSupported, isFalse, reason: '$gpu');
        expect(refused.unavailableReasons[Delegate.gpu], contains('UP-049'));
      }
    });

    test('browsers refuse the models Google\'s runtime fails with: '
        'EmbeddingGemma 2 in WebKit (UP-054), GLiNER2.5-Decide everywhere '
        '(UP-055)', () {
      TaskPlatform web(BrowserEngine? engine, [String? gpu]) => TaskPlatform(
        operatingSystem: 'web',
        architecture: 'unknown',
        gpu: gpu ?? 'WebGPU apple apple',
        browserEngine: engine,
      );
      decisionBackendFactory = (_) => throw UnimplementedError();
      addTearDown(() => decisionBackendFactory = null);
      const gemmas = [
        DecisionModels.embeddingGemma2Text,
        DecisionModels.embeddingGemma2TextVision,
      ];
      const gliners = [DecisionModels.glinerS256, DecisionModels.glinerS512];
      for (final model in gemmas) {
        final refused = decisionMakerCapabilitiesForPlatform(
          web(BrowserEngine.webkit),
          model: model,
        );
        expect(refused.isSupported, isFalse, reason: model.url);
        for (final delegate in Delegate.values) {
          expect(
            refused.unavailableReasons[delegate],
            allOf(contains('UP-054'), contains('layaS256')),
            reason: '$delegate ${model.url}',
          );
        }
        for (final engine in [BrowserEngine.blink, BrowserEngine.gecko, null]) {
          expect(
            decisionMakerCapabilitiesForPlatform(
              web(engine),
              model: model,
            ).supportedDelegates,
            {Delegate.gpu},
            reason: '$engine ${model.url}',
          );
        }
      }
      for (final engine in [BrowserEngine.webkit, BrowserEngine.blink]) {
        for (final model in gliners) {
          final refused = decisionMakerCapabilitiesForPlatform(
            web(engine),
            model: model,
          );
          expect(refused.isSupported, isFalse, reason: '$engine ${model.url}');
          expect(refused.unavailableReasons[Delegate.gpu], contains('UP-055'));
        }
        for (final model in [
          null,
          DecisionModels.layaS256,
          DecisionModels.layaS512,
        ]) {
          expect(
            decisionMakerCapabilitiesForPlatform(
              web(engine),
              model: model,
            ).supportedDelegates,
            {Delegate.gpu},
            reason: '$engine $model',
          );
        }
      }
      // Without a hardware adapter the browser's reason stays UP-049.
      expect(
        decisionMakerCapabilitiesForPlatform(
          web(BrowserEngine.webkit, 'WebGPU apple apple (fallback adapter)'),
          model: DecisionModels.embeddingGemma2Text,
        ).unavailableReasons[Delegate.gpu],
        contains('UP-049'),
      );
      // Native platforms are untouched by the browser's refusals.
      expect(
        decisionMakerCapabilitiesForPlatform(
          _platform('macos', 'arm64', '15.0'),
          model: DecisionModels.glinerS256,
        ).supportedDelegates,
        {Delegate.cpu},
      );
    });
  });
}

/// A browser backend that is never asked anything.
final class _IdleBackend implements DecisionBackend {
  @override
  Future<Object?> run(Map<String, Object?> request) =>
      throw UnimplementedError();

  @override
  Future<void> dispose() async {}
}
