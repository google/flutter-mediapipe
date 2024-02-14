import 'package:example/text_classification_demo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_text/mediapipe_text.dart';

class FakeTextClassifier extends TextClassifier {
  FakeTextClassifier({required super.options});

  @override
  Future<TextClassifierResult> classify(String text) => Future.value(
        const TextClassifierResult(
          classifications: <Classifications>[
            Classifications(
              categories: <Category>[
                Category(
                  index: 0,
                  score: 0.9,
                  categoryName: 'happy-go-lucky',
                  displayName: null,
                ),
              ],
              headIndex: 0,
              headName: 'whatever',
            ),
          ],
        ),
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('TextClassificationResults should show results',
      (WidgetTester tester) async {
    final app = MaterialApp(
      home: TextClassificationDemo(
        classifier: FakeTextClassifier(
          options: TextClassifierOptions.fromAssetPath('fake'),
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
    expect(
      find.text('"Hello, world!" happy-go-lucky :: 0.9'),
      findsOneWidget,
    );
  });
}
