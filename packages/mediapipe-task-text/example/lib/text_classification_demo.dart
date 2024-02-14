// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:mediapipe_text/mediapipe_text.dart';
import 'logging.dart';

class TextClassificationDemo extends StatefulWidget {
  const TextClassificationDemo({super.key, this.classifier});

  final BaseTextClassifier? classifier;

  @override
  State<TextClassificationDemo> createState() => _TextClassificationDemoState();
}

class _TextClassificationDemoState extends State<TextClassificationDemo> {
  final TextEditingController _controller = TextEditingController();
  List<Widget> results = [];
  String? _isProcessing;

  TextClassifier? _classifier;
  Completer<BaseTextClassifier>? _completer;

  @override
  void initState() {
    super.initState();
    _controller.text = 'Hello, world!';
    _initClassifier();
  }

  Future<BaseTextClassifier> get classifier {
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
      options: TextClassifierOptions.fromAssetBuffer(
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

  void _showClassificationResults(TextClassifierResult classification) {
    setState(() {
      final categoryName =
          classification.firstClassification?.firstCategory?.categoryName;
      final score = classification.firstClassification?.firstCategory?.score;
      // Replace "..." with the results
      final message = '"$_isProcessing" $categoryName :: $score';
      log.info(message);
      results.last = Card(
        key: Key('Classification::"$_isProcessing" ${results.length}'),
        margin: const EdgeInsets.all(10),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Text(message),
        ),
      );
      _isProcessing = null;
    });
  }

  Future<void> _classify() async {
    _prepareForClassification();
    final classification = await (await classifier).classify(_controller.text);
    _showClassificationResults(classification);
  }

  @override
  Widget build(BuildContext context) => //
      Scaffold(
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
          onPressed: _isProcessing != null && _controller.text != ''
              ? null
              : _classify,
          child: const Icon(Icons.search),
        ),
      );
}
