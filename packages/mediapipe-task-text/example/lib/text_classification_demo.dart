// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';
import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_text/mediapipe_text.dart';
import 'enumerate.dart';

class TextClassificationDemo extends StatefulWidget {
  const TextClassificationDemo({super.key, this.classifier});

  final TextClassifier? classifier;

  @override
  State<TextClassificationDemo> createState() => _TextClassificationDemoState();
}

class _TextClassificationDemoState extends State<TextClassificationDemo>
    with AutomaticKeepAliveClientMixin<TextClassificationDemo> {
  final TextEditingController _controller = TextEditingController();
  final results = <Widget>[];
  String? _isProcessing;

  TextClassifier? _classifier;
  Completer<TextClassifier>? _completer;

  @override
  void initState() {
    super.initState();
    _controller.text = 'Hello, world!';
    _initClassifier();
  }

  Future<TextClassifier> get classifier {
    if (widget.classifier != null) {
      return Future.value(widget.classifier!);
    }
    if (_completer == null) {
      _initClassifier();
    }
    return _completer!.future;
  }

  Future<void> _initClassifier() async {
    _classifier?.dispose();
    _completer = Completer<TextClassifier>();
    ByteData? classifierBytes = await DefaultAssetBundle.of(context)
        .load('assets/bert_classifier.tflite');

    TextClassifier classifier = TextClassifier(
      TextClassifierOptions.fromAssetBuffer(
        classifierBytes.buffer.asUint8List(),
      ),
    );
    _completer!.complete(classifier);
    classifierBytes = null;
  }

  void _prepareForClassification() {
    setState(() {
      _isProcessing = _controller.text;
      results.add(const CircularProgressIndicator.adaptive());
    });
  }

  void _showClassificationResults(TextClassifierResult result) {
    final categoryWidgets = <Widget>[];
    for (final classifications in result.classifications) {
      categoryWidgets.addAll(_textClassifications(classifications));
    }

    setState(
      () {
        results.last = Card(
          key: Key('prediction-$_isProcessing-${results.length}'),
          margin: const EdgeInsets.all(10),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(_isProcessing!),
              ),
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: Wrap(
                  children: <Widget>[
                    ...categoryWidgets,
                  ],
                ),
              ),
            ],
          ),
        );
        _isProcessing = null;
      },
    );
  }

  static final categoryColors = <Color>[
    Colors.blue[300]!,
    Colors.orange[300]!,
    Colors.green[300]!,
    Colors.red[300]!,
  ];

  //   setState(() {
  //     final categoryName =
  //         classification.firstClassification?.firstCategory?.categoryName;
  //     final score = classification.firstClassification?.firstCategory?.score;
  //     // Replace "..." with the results
  //     final message = '"$_isProcessing" $categoryName :: $score';
  //     log.info(message);
  //     results.last = Card(
  //       key: Key('Classification::"$_isProcessing" ${results.length}'),
  //       margin: const EdgeInsets.all(10),
  //       child: Padding(
  //         padding: const EdgeInsets.all(10),
  //         child: Text(message),
  //       ),
  //     );
  //     _isProcessing = null;
  //   });
  // }

  List<Widget> _textClassifications(Classifications classifications) {
    return classifications.categories
        .enumerate<Widget>((category, index) =>
            _textClassification(category, categoryColors[index]))
        .toList();
  }

  Widget _textClassification(Category category, Color color) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GFButton(
        onPressed: null,
        text: '${category.displayName ?? category.categoryName} :: '
            '${category.score.roundTo(4)}',
        shape: GFButtonShape.pills,
        color: color,
      ),
    );
  }

  Future<void> _classify() async {
    _prepareForClassification();
    final classification = await (await classifier).classify(_controller.text);
    _showClassificationResults(classification);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: <Widget>[
              TextField(controller: _controller),
              ...results,
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed:
            _isProcessing != null && _controller.text != '' ? null : _classify,
        child: const Icon(Icons.search),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

extension on double {
  double roundTo(int decimalPlaces) =>
      double.parse(toStringAsFixed(decimalPlaces));
}
