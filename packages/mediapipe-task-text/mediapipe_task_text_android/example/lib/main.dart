import 'package:flutter/material.dart';
import 'package:mediapipe_task_text/mediapipe_task_text.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? classificationName;
  double? classificationScore;
  String? lastClassified;
  final TextEditingController _controller = TextEditingController();
  final _mediaPipeTaskTextPlugin = MediaPipeTaskText('model.tflite');

  @override
  void initState() {
    _mediaPipeTaskTextPlugin.initClassifier();
    super.initState();
  }

  Future<void> classify() async {
    setState(() {
      lastClassified = _controller.text;
      classificationName = null;
      classificationScore = null;
    });
    final result = await _mediaPipeTaskTextPlugin.classify(_controller.text);
    Category? category =
        result?.classificationResult.classifications.first?.categories.first;
    setState(() {
      classificationName = category?.displayName ?? category?.categoryName;
      classificationScore = category?.score;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: SafeArea(
        child: Scaffold(
          body: Center(
            child: Stack(
              children: <Widget>[
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      lastClassified == null
                          ? const Text('Awaiting first classification...')
                          : Text('Running on "$lastClassified"'),
                      classificationName == null
                          ? Container()
                          : Text('Classification: $classificationName'),
                      classificationScore == null
                          ? Container()
                          : Text('Score: $classificationScore'),
                    ],
                  ),
                ),
                Column(
                  children: <Widget>[
                    TextField(controller: _controller),
                    MaterialButton(
                      onPressed: classify,
                      color: Colors.blue,
                      child: const Text(
                        'Classify',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
