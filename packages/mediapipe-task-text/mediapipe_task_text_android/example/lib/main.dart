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
  String? classification;
  String? lastClassified;
  final TextEditingController _controller = TextEditingController();
  final _mediaPipeTaskTextPlugin = MediaPipeTaskText('model.tflite');

  @override
  void initState() {
    _mediaPipeTaskTextPlugin.initClassifier();
    super.initState();
  }

  Future<void> classify() async {
    setState(() => lastClassified = _controller.text);
    final result = await _mediaPipeTaskTextPlugin.classify(_controller.text);
    setState(() => classification = result?.value);
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
                      classification == null
                          ? Container()
                          : Text('Result: $classification'),
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
