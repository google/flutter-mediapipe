import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Future<String?> platformVersion;

  @override
  void initState() {
    platformVersion = _initPlatformVersion();
    super.initState();
  }

  Future<String?> _initPlatformVersion() async {
    try {
      return _mediaPipeTaskTextPlugin.getPlatformVersion() ??
          'UnknownPlatformVersion';
    } on PlatformException {
      return 'Failed to get platform version';
    }
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
              Text('Running on $_platformVersion'),
            ],
          ),
        ),
      ),
    );
  }
}
