import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final TextEditingController _controller = TextEditingController();
  final _mediaPipeTaskTextPlugin = MediapipeTaskText('assets/model.tflite');

  Future<void> classify() async {
    final result = await _mediaPipeTaskTextPlugin.classify(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: Center(
          child: Column(
            children: <Widget>[
              Text('Running on $classification'),
              TextField(controller: _controller),
              MaterialButton(
                onPressed: classify,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
