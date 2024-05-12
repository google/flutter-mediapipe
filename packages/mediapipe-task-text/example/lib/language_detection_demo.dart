// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';
import 'package:mediapipe_text/mediapipe_text.dart';
import 'enumerate.dart';

class LanguageDetectionDemo extends StatefulWidget {
  const LanguageDetectionDemo({super.key, this.detector});

  final LanguageDetector? detector;

  @override
  State<LanguageDetectionDemo> createState() => _LanguageDetectionDemoState();
}

class _LanguageDetectionDemoState extends State<LanguageDetectionDemo>
    with AutomaticKeepAliveClientMixin<LanguageDetectionDemo> {
  final TextEditingController _controller = TextEditingController();
  final Completer<LanguageDetector> _completer = Completer<LanguageDetector>();
  final results = <Widget>[];
  String? _isProcessing;

  @override
  void initState() {
    super.initState();
    _controller.text = 'Quiero agua, por favor';
    _initDetector();
  }

  Future<void> _initDetector() async {
    if (widget.detector != null) {
      return _completer.complete(widget.detector!);
    }

    ByteData? bytes = await DefaultAssetBundle.of(context)
        .load('assets/language_detector.tflite');

    final detector = LanguageDetector(
      LanguageDetectorOptions.fromAssetBuffer(
        bytes.buffer.asUint8List(),
      ),
    );
    _completer.complete(detector);
    bytes = null;
  }

  void _prepareForDetection() {
    setState(() {
      _isProcessing = _controller.text;
      results.add(const CircularProgressIndicator.adaptive());
    });
  }

  Future<void> _detect() async {
    _prepareForDetection();
    _completer.future.then((detector) async {
      final result = await detector.detect(_controller.text);
      _showDetectionResults(result);
      result.dispose();
    });
  }

  void _showDetectionResults(LanguageDetectorResult result) {
    setState(
      () {
        results.last = Card(
          key: Key('prediction-"$_isProcessing" ${results.length}'),
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
                    ...result.predictions
                        .enumerate<Widget>(
                          (prediction, index) => _languagePrediction(
                            prediction,
                            predictionColors[index],
                          ),
                          // Take first 4 because the model spits out dozens of
                          // astronomically low probability language predictions
                          max: predictionColors.length,
                        )
                        .toList(),
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

  static final predictionColors = <Color>[
    Colors.blue[300]!,
    Colors.orange[300]!,
    Colors.green[300]!,
    Colors.red[300]!,
  ];

  Widget _languagePrediction(LanguagePrediction prediction, Color color) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GFButton(
        onPressed: null,
        text: '${prediction.languageCode} :: '
            '${prediction.probability.roundTo(8)}',
        shape: GFButtonShape.pills,
        color: color,
      ),
    );
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
                TextField(controller: _controller),
                ...results.reversed,
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed:
            _isProcessing != null && _controller.text != '' ? null : _detect,
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
