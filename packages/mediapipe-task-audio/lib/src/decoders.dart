/// One decoder from the browser adapter's results to the Dart types.
///
/// Google's browser runtime delivers Audio Classifier results as JSON in the
/// shape of its JavaScript API: one classification result per chunk. The
/// adapter only forwards them.
library;

import 'package:mediapipe_core/platform_interface.dart'
    show decodeClassifications;

import 'types.dart';

/// Decodes the per-chunk results of one clip.
List<AudioClassifierResult> decodeAudioClassifierResults(List<Object?> json) =>
    [
      for (final chunk in json.cast<Map>())
        AudioClassifierResult(
          timestampMilliseconds: (chunk['timestampMs'] as num?)?.toInt() ?? 0,
          classifications: [
            for (final head
                in (chunk['classifications'] as List? ?? const []).cast<Map>())
              decodeClassifications(head),
          ],
        ),
    ];
