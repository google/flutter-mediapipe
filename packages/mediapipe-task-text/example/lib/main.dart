import 'dart:io' as io;
import 'dart:typed_data';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/material.dart';
import 'package:mediapipe_text/mediapipe_text.dart';
import 'package:path_provider/path_provider.dart';

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

  @override
  void initState() {
    super.initState();
    _controller.text = 'Hello, world!';
    _initClassifier();
  }

  Future<void> _initClassifier() async {
    // getApplicationDocumentsDirectory().then((dir) {
    //   print(dir.absolute.path);
    // });
    // final dir = await getApplicationSupportDirectory();
    // print('app support: ${dir.absolute.path}');

    // DefaultAssetBundle.of(context).

    // final ByteData classifierBytes = await DefaultAssetBundle.of(context)
    //     .load('assets/bert_classifier.tflite');

    final dir = io.Directory(path.current);
    final modelPath = path.joinAll(
      [dir.absolute.path, 'assets/bert_classifier.tflite'],
    );
    _log.finest('modelPath: $modelPath');
    if (io.File(modelPath).existsSync()) {
      _log.fine('Successfully found model.');
    } else {
      _log.severe('Invalid model path $modelPath. Model not found.');
      io.exit(1);
    }

    final sdkPath = path.joinAll(
      [dir.absolute.path, 'assets/libtext_classifier.dylib'],
    );
    _log.finest('sdkPath: $sdkPath');
    if (io.File(sdkPath).existsSync()) {
      _log.fine('Successfully found SDK.');
    } else {
      _log.severe('Invalid SDK path $sdkPath. SDK not found.');
      io.exit(1);
    }

    _classifier = TextClassifier(
      options: TextClassifierOptions.fromAssetPath(modelPath),
      // options: TextClassifierOptions.fromAssetBuffer(
      //     Uint8List.view(classifierBytes.buffer)),
      // sdkPath: sdkPath,
    );
  }

  void _classify() async {
    setState(() => results = null);
    _log.info('Classifying ${_controller.text}');
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
