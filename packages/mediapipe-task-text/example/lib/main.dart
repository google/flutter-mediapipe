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
  String? results;
  ByteData? classifierBytes;

  @override
  void initState() {
    super.initState();
    _controller.text = 'Hello, world!';
    _initClassifier();
  }

  Future<void> _initClassifier() async {
    final model =
        io.File('/Users/craiglabenz/Downloads/bert_classifier.tflite');

    classifierBytes = await DefaultAssetBundle.of(context)
        .load('assets/bert_classifier.tflite');

    _classifier = TextClassifier(
      options: TextClassifierOptions.fromAssetBuffer(model.readAsBytesSync()),
    );
  }

  void _classify() async {
    setState(() => results = null);
    _log.info('Classifying ${_controller.text}');
    _log.info('ClassifierBytes.length ${classifierBytes!.lengthInBytes}');
    final classification = await _classifier.classify(_controller.text);
    setState(() {
      final categoryName =
          classification.firstClassification?.firstCategory?.categoryName;
      final score = classification.firstClassification?.firstCategory?.score;
      results = '$categoryName :: $score';
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: <Widget>[
              TextField(controller: _controller),
              if (results != null) Text(results!),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _classify,
          child: const Icon(Icons.search),
        ),
      ),
    );
  }
}
