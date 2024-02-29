import 'dart:io' as io;
import 'dart:typed_data';
import 'package:logging/logging.dart';
import 'package:flutter/material.dart';
import 'package:mediapipe_text/mediapipe_text.dart';

final _log = Logger('TextClassificationExample');

void main() {
  Logger.root.level = Level.FINEST;
  Logger.root.onRecord.listen((record) {
    io.stdout.writeln('${record.level.name} [${record.loggerName}]'
        '['
        '${record.time.hour.toString()}:'
        '${record.time.minute.toString().padLeft(2, "0")}:'
        '${record.time.second.toString().padLeft(2, "0")}.'
        '${record.time.millisecond.toString().padRight(3, "0")}'
        '] ${record.message}');
  });
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late Future<TextClassifier> _classifier;

  @override
  void initState() {
    super.initState();
    _classifier = _initClassifier();
  }

  Future<TextClassifier> _initClassifier() async {
    ByteData? classifierBytes = await DefaultAssetBundle.of(context)
        .load('assets/bert_classifier.tflite');

    TextClassifier classifier = TextClassifier(
      TextClassifierOptions.fromAssetBuffer(
        classifierBytes.buffer.asUint8List(),
      ),
    );
    classifierBytes = null;
    return classifier;
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: TextClassificationResults(
          classifier: _classifier,
        ),
      );
}

class TextClassificationResults extends StatefulWidget {
  const TextClassificationResults({super.key, required this.classifier});

  final Future<TextClassifier> classifier;

  @override
  State<TextClassificationResults> createState() =>
      _TextClassificationResultsState();
}

class _TextClassificationResultsState extends State<TextClassificationResults> {
  final TextEditingController _controller = TextEditingController();
  List<Widget> results = [];
  String? _isProcessing;

  @override
  void initState() {
    super.initState();
    _controller.text = 'Hello, world!';
  }

  void _prepareForClassification() {
    setState(() {
      _isProcessing = _controller.text;
      results.add(const CircularProgressIndicator.adaptive());
    });
  }

  void _showClassificationResults(TextClassifierResult result) {
    setState(() {
      final categoryName =
          result.firstClassification?.firstCategory?.categoryName;
      final score = result.firstClassification?.firstCategory?.score;
      // Replace "..." with the results
      final message = '"$_isProcessing" $categoryName :: $score';
      _log.info(message);
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
    TextClassifier classifier = await widget.classifier;
    final classification = await classifier.classify(_controller.text);
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
