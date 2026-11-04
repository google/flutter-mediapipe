@Tags(['native-assets'])
library;

import 'dart:convert';

import 'package:test/test.dart';

import 'support/classic_text_reference.dart';
import 'support/classic_text_validation.dart';

void main() {
  test(
    'all three tasks match the pinned official outputs from paths and bytes',
    () async {
      final report = await validateClassicText({
        'classifier': 'models/bert_classifier.tflite',
        'embedder': 'models/universal_sentence_encoder.tflite',
        'language': 'models/language_detector.tflite',
      }, loadClassicTextReference());
      expect(report['reference_cases'], 26);
      expect(report['inference_comparisons'], 52);
      print(jsonEncode(report));
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
