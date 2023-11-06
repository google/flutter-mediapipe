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
  late final TextClassifier _classifier;
  final TextEditingController _controller = TextEditingController();
  List<Widget> results = [];
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _controller.text = 'Hello, world!';
    _initClassifier();
    Future.delayed(const Duration(milliseconds: 500)).then((_) => _classify());
  }

  Future<void> _initClassifier() async {
    ByteData? classifierBytes = await DefaultAssetBundle.of(context)
        .load('assets/bert_classifier.tflite');

    _classifier = TextClassifier(
      options: TextClassifierOptions.fromAssetBuffer(
        classifierBytes.buffer.asUint8List(),
      ),
    );
    classifierBytes = null;
  }

  void _prepareForClassification() {
    setState(() {
      _isProcessing = true;
      results.add(const CircularProgressIndicator.adaptive());
    });
  }

  void _showClassificationResults(TextClassifierResult classification) {
    setState(() {
      _isProcessing = false;
      final categoryName =
          classification.firstClassification?.firstCategory?.categoryName;
      final score = classification.firstClassification?.firstCategory?.score;
      // Replace "..." with the results
      results.last = Text('$categoryName :: $score');
    });
  }

  Future<void> _classify() async {
    _prepareForClassification();
    final classification = await _classifier.classify(_controller.text);
    _showClassificationResults(classification);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: <Widget>[
              TextField(controller: _controller),
              ...results,
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _isProcessing ? null : _classify,
          child: const Icon(Icons.search),
        ),
      ),
    );
  }
}
