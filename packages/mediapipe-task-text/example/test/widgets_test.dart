import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_text/mediapipe_text.dart';
import 'package:example/language_detection_demo.dart';
import 'package:example/text_classification_demo.dart';

class FakeTextClassifier extends TextClassifier {
  FakeTextClassifier(TextClassifierOptions options) : super(options);

  @override
  Future<TextClassifierResult> classify(String text) {
    return Future.value(
      TextClassifierResult(
        classifications: <Classifications>[
          Classifications(
            categories: <Category>[
              Category(
                index: 0,
                score: 0.9,
                categoryName: 'happy-go-lucky',
                displayName: 'Happy go Lucky',
              ),
            ],
            headIndex: 0,
            headName: 'whatever',
          ),
        ],
      ),
    );
  }
}

class FakeLanguageDetector extends LanguageDetector {
  FakeLanguageDetector(LanguageDetectorOptions options) : super(options);

  @override
  Future<LanguageDetectorResult> detect(String text) {
    return Future.value(
      LanguageDetectorResult(
        predictions: <LanguagePrediction>[
          LanguagePrediction(
            languageCode: 'es',
            probability: 0.99,
          ),
          LanguagePrediction(
            languageCode: 'en',
            probability: 0.01,
          ),
        ],
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('TextClassificationResult should show results', (
    WidgetTester tester,
  ) async {
    final app = MaterialApp(
      home: TextClassificationDemo(
        classifier: FakeTextClassifier(
          TextClassifierOptions.fromAssetPath('fake'),
        ),
      ),
    );

    await tester.pumpWidget(app);
    await tester.tap(find.byType(Icon));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('Classification::"Hello, world!" 1')),
      findsOneWidget,
    );
    expect(find.text('Happy go Lucky :: 0.9'), findsOneWidget);
  });

  testWidgets('LanguageDetectorResult should show results', (
    WidgetTester tester,
  ) async {
    final app = MaterialApp(
      home: LanguageDetectionDemo(
        detector: FakeLanguageDetector(
          LanguageDetectorOptions.fromAssetPath('fake'),
        ),
      ),
    );

    await tester.pumpWidget(app);
    await tester.tap(find.byType(Icon));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('prediction-"Quiero agua, por favor" 1')),
      findsOneWidget,
    );
    expect(find.text('es :: 0.99'), findsOneWidget);
    expect(find.text('en :: 0.01'), findsOneWidget);
  });
}
