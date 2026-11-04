/// One decoder from the browser adapter's results to the Dart types.
///
/// Google's browser runtime delivers text results as JSON in the shape of its
/// JavaScript API; the adapter only forwards them, and every value is read
/// here.
library;

import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_core/platform_interface.dart'
    show decodeClassifications, decodeEmbedding;

import '../types/results.dart';

/// Decodes a Text Classifier result.
TextClassifierResult decodeTextClassifierResult(Map<String, dynamic> json) =>
    TextClassifierResult(
      classifications: _classifications(json),
      timestampMilliseconds: _timestamp(json),
    );

/// Decodes a Text Embedder result.
TextEmbedderResult decodeTextEmbedderResult(Map<String, dynamic> json) =>
    TextEmbedderResult(
      timestampMilliseconds: _timestamp(json),
      embeddings: [
        for (final head in (json['embeddings'] as List).cast<Map>())
          decodeEmbedding(head),
      ],
    );

/// Decodes a Language Detector result.
LanguageDetectorResult decodeLanguageDetectorResult(
  Map<String, dynamic> json,
) => LanguageDetectorResult(
  predictions: [
    for (final value in (json['languages'] as List).cast<Map>())
      LanguagePrediction(
        languageCode: value['languageCode'] as String,
        probability: (value['probability'] as num).toDouble(),
      ),
  ],
);

List<Classifications> _classifications(Map<String, dynamic> json) => [
  for (final head in (json['classifications'] as List).cast<Map>())
    decodeClassifications(head),
];

int? _timestamp(Map<String, dynamic> json) =>
    (json['timestampMs'] as num?)?.toInt();
