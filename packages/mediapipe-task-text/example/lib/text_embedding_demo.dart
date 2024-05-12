// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';
import 'package:example/keyboard_hider.dart';
import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';
import 'package:logging/logging.dart';
import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_text/mediapipe_text.dart';
import 'enumerate.dart';

final _log = Logger('TextEmbeddingDemo');

class TextEmbeddingDemo extends StatefulWidget {
  const TextEmbeddingDemo({super.key, this.embedder});

  /// Overriding [BaseTextEmbedder] object. If supplied, the Embedder
  /// configuration controls cannot be used.
  final TextEmbedder? embedder;

  @override
  State<TextEmbeddingDemo> createState() => _TextEmbeddingDemoState();
}

class _TextEmbeddingDemoState extends State<TextEmbeddingDemo>
    with AutomaticKeepAliveClientMixin<TextEmbeddingDemo> {
  final TextEditingController _controller = TextEditingController();
  List<EmbeddingFeedItem> feed = [];
  EmbeddingType type = EmbeddingType.quantized;
  bool l2Normalize = true;

  TextEmbedder? _embedder;
  Completer<TextEmbedder>? _completer;

  @override
  void initState() {
    super.initState();
    _controller.text = 'Embed me';
    _initEmbedder();
  }

  @override
  void dispose() {
    final resultsIter = feed.where(
      (el) => el._type == _EmbeddingFeedItemType.result,
    );
    for (final feedItem in resultsIter) {
      feedItem.embeddingResult!.result?.dispose();
    }
    super.dispose();
  }

  Future<TextEmbedder> get embedder {
    if (widget.embedder != null) {
      return Future.value(widget.embedder!);
    }
    if (_completer == null) {
      _initEmbedder();
    }
    return _completer!.future;
  }

  void toggleMode() {
    assert(
      widget.embedder == null,
      'Changing embedder configuration not supported when an embedder is '
      'supplied to the widget.',
    );
    setState(() => type = type.opposite);
    _initEmbedder();
  }

  void toggleL2Normalize() {
    assert(
      widget.embedder == null,
      'Changing embedder configuration not supported when an embedder is '
      'supplied to the widget.',
    );
    setState(() => l2Normalize = !l2Normalize);
    _initEmbedder();
  }

  Future<void> _initEmbedder() async {
    _embedder?.dispose();
    _completer = Completer<TextEmbedder>();

    ByteData? embedderBytes = await DefaultAssetBundle.of(context)
        .load('assets/universal_sentence_encoder.tflite');

    _embedder = TextEmbedder(
      TextEmbedderOptions.fromAssetBuffer(
        embedderBytes.buffer.asUint8List(),
        embedderOptions: EmbedderOptions(
          l2Normalize: l2Normalize,
          quantize: type == EmbeddingType.quantized,
        ),
      ),
    );
    _completer!.complete(_embedder);
    embedderBytes = null;
  }

  void _prepareForEmbedding() {
    setState(() {
      feed.add(
        EmbeddingFeedItem.result(
          TextWithEmbedding(
            computedAt: DateTime.now(),
            l2Normalized: l2Normalize,
            value: _controller.text,
          ),
        ),
      );
    });
  }

  void _showEmbeddingResults(TextEmbedderResult result) {
    setState(() {
      if (result.embeddings.isEmpty) return;

      // Replace the incomplete record for the last embedded value with the
      // result of that embedding
      feed.last = feed.last.complete(result);

      if (canCompareLastTwo) {
        feed.insert(feed.length - 1, EmbeddingFeedItem.emptyComparison());
      } else if (lastTwoResultsIncomparable) {
        feed.insert(feed.length - 1, EmbeddingFeedItem.incomparable());
      }
    });
  }

  Future<void> _embed() async {
    _prepareForEmbedding();
    final embeddingResult = await (await embedder).embed(_controller.text);
    _showEmbeddingResults(embeddingResult);
  }

  /// True if there is an `embed(String)` request out and not yet fulfilled.
  bool get isProcessing =>
      (feed.isNotEmpty && feed.last.embeddingResult?.result == null);

  /// True if the last two feed items are both results and have the same
  /// metadata.
  bool get canCompareLastTwo =>
      feed.length >= 2 &&
      feed.last._type == _EmbeddingFeedItemType.result &&
      feed[feed.length - 2]._type == _EmbeddingFeedItemType.result &&
      feed.last.embeddingResult!
          .canComputeSimilarity(feed[feed.length - 2].embeddingResult!);

  /// True if the last two feed items are both results but have different
  /// metadata. This is different than two feed items which are NOT both results
  /// (aka, a comparison and a result side by side), which is a situation that
  /// does not require special handling in the UI.
  bool get lastTwoResultsIncomparable =>
      feed.length >= 2 &&
      feed.last._type == _EmbeddingFeedItemType.result &&
      feed[feed.length - 2]._type == _EmbeddingFeedItemType.result &&
      !feed.last.embeddingResult!
          .canComputeSimilarity(feed[feed.length - 2].embeddingResult!);

  Future<void> _compare(int index) async {
    int lowIndex = index - 1;
    int highIndex = index + 1;
    _log.info(
      'Comparing "${feed[lowIndex].embeddingResult!.value}" and '
      '"${feed[highIndex].embeddingResult!.value}"',
    );
    final similarity = await (await embedder).cosineSimilarity(
      feed[lowIndex].embeddingResult!.result!.embeddings.first,
      feed[highIndex].embeddingResult!.result!.embeddings.first,
    );
    setState(() {
      feed[index] = EmbeddingFeedItem.comparison(similarity);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            const Text('Float:'),
                            Checkbox(
                              value: type == EmbeddingType.float,
                              onChanged: (_) {
                                toggleMode();
                              },
                            ),
                          ],
                        ),
                        // Quantized checkbox
                        Row(
                          children: <Widget>[
                            const Text('Quantize:'),
                            Checkbox(
                              value: type == EmbeddingType.quantized,
                              onChanged: (bool? newValue) {
                                toggleMode();
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            const Text('L2 Normalize:'),
                            Checkbox(
                              value: l2Normalize,
                              onChanged: (_) {
                                toggleL2Normalize();
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                // Float checkbox
                TextField(controller: _controller),
                ...feed.reversed.toList().enumerate<Widget>(
                  (EmbeddingFeedItem feedItem, index) {
                    return KeyboardHider(
                      child: switch (feedItem._type) {
                        _EmbeddingFeedItemType.result =>
                          TextEmbedderResultDisplay(
                            embeddedText: feedItem.embeddingResult!,
                            index: index,
                          ),
                        _EmbeddingFeedItemType.emptyComparison => TextButton(
                            // Subtract `index` from `feed.length` because we
                            // are looping through the list in reverse order
                            onPressed: () => _compare(feed.length - index - 1),
                            style: ButtonStyle(
                              backgroundColor: WidgetStateProperty.all(
                                Colors.purple[100],
                              ),
                            ),
                            child: const Text('Compare'),
                          ),
                        _EmbeddingFeedItemType.comparison =>
                          ComparisonDisplay(similarity: feedItem.similarity!),
                        _EmbeddingFeedItemType.incomparable => const Text(
                            'Embeddings of different types cannot be compared'),
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: isProcessing || _controller.text == '' ? null : _embed,
        child: const Icon(Icons.search),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

/// Shows, in the activity feed, the results of invoking `cosineSimilarity`
/// between two [Embedding] objects (with identical metadata).
class ComparisonDisplay extends StatelessWidget {
  const ComparisonDisplay({super.key, required this.similarity});

  final double similarity;

  @override
  Widget build(BuildContext context) => Text('Similarity score: $similarity');
}

/// Shows, in the activity feed, a visualiation of an [Embedding] object.
class TextEmbedderResultDisplay extends StatelessWidget {
  const TextEmbedderResultDisplay({
    super.key,
    required this.embeddedText,
    required this.index,
  });

  final TextWithEmbedding embeddedText;
  final int index;

  @override
  Widget build(BuildContext context) {
    if (embeddedText.result == null) {
      return const CircularProgressIndicator.adaptive();
    }
    final embedding = embeddedText.result!.embeddings.last;
    String embeddingDisplay = switch (embedding.type) {
      EmbeddingType.float => '${embedding.floatEmbedding!}',
      EmbeddingType.quantized => '${embedding.quantizedEmbedding!}',
    };
    // Replace "..." with the results
    return Card(
      key: Key('Embedding::"${embeddedText.value}" $index'),
      margin: const EdgeInsets.all(10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('"${embeddedText.value}"',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(embeddingDisplay),
            Wrap(
              spacing: 4,
              children: <Widget>[
                if (embedding.type == EmbeddingType.float)
                  _embeddingAttribute('Float', Colors.blue[600]!),
                if (embedding.type == EmbeddingType.quantized)
                  _embeddingAttribute('Quantized', Colors.orange[600]!),
                if (embeddedText.l2Normalized)
                  _embeddingAttribute('L2 Normalized', Colors.green[600]!),
                _embeddingAttribute(embeddedText.computedAt.toIso8601String(),
                    Colors.grey[600]!),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _embeddingAttribute(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white)),
    );
  }
}

/// Bundled [TextEmbeddingResult], the original text, and whether
/// that value was embedded with L2 normalization.
///
/// See also:
///  * [TextEmbedderResultDisplay] - the widget which displays this information.
class TextWithEmbedding {
  const TextWithEmbedding._({
    required this.computedAt,
    required this.l2Normalized,
    required this.result,
    required this.value,
  });

  const TextWithEmbedding({
    required this.computedAt,
    required this.l2Normalized,
    required this.value,
  }) : result = null;

  final bool l2Normalized;
  final TextEmbedderResult? result;
  final String value;
  final DateTime computedAt;

  TextWithEmbedding complete(TextEmbedderResult result) => TextWithEmbedding._(
        computedAt: computedAt,
        l2Normalized: l2Normalized,
        result: result,
        value: value,
      );

  bool canComputeSimilarity(TextWithEmbedding other) =>
      result != null &&
      result!.embeddings.isNotEmpty &&
      other.result != null &&
      other.result!.embeddings.isNotEmpty &&
      l2Normalized == other.l2Normalized &&
      result!.embeddings.first.type == other.result!.embeddings.first.type;
}

/// Contains the various types of application state that can appear in the demo
/// app's activity feed.
///
/// Union type of all possible items that can appear on the feed.
///
/// See also:
///  * [_EmbeddingFeedItemType] - the enum which indicates the type of feed item.
class EmbeddingFeedItem {
  const EmbeddingFeedItem._({
    required this.similarity,
    required this.embeddingResult,
    required _EmbeddingFeedItemType type,
  }) : _type = type;

  factory EmbeddingFeedItem.comparison(double similarity) =>
      EmbeddingFeedItem._(
        similarity: similarity,
        embeddingResult: null,
        type: _EmbeddingFeedItemType.comparison,
      );

  factory EmbeddingFeedItem.result(TextWithEmbedding result) =>
      EmbeddingFeedItem._(
        similarity: null,
        embeddingResult: result,
        type: _EmbeddingFeedItemType.result,
      );

  factory EmbeddingFeedItem.emptyComparison() => const EmbeddingFeedItem._(
        similarity: null,
        embeddingResult: null,
        type: _EmbeddingFeedItemType.emptyComparison,
      );

  factory EmbeddingFeedItem.incomparable() => const EmbeddingFeedItem._(
        similarity: null,
        embeddingResult: null,
        type: _EmbeddingFeedItemType.incomparable,
      );

  EmbeddingFeedItem complete(TextEmbedderResult result) {
    assert(_type == _EmbeddingFeedItemType.result);
    return EmbeddingFeedItem.result(embeddingResult!.complete(result));
  }

  final TextWithEmbedding? embeddingResult;
  final double? similarity;
  final _EmbeddingFeedItemType _type;
}

enum _EmbeddingFeedItemType {
  result,
  comparison,
  emptyComparison,
  incomparable
}
