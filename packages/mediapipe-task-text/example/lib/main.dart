import 'package:flutter/material.dart';
import 'language_detection_demo.dart';
import 'logging.dart';
import 'text_classification_demo.dart';
import 'text_embedding_demo.dart';

void main() {
  initLogging();
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  @override
  Widget build(BuildContext context) =>
      const MaterialApp(home: TextTaskPages());
}

class TextTaskPages extends StatefulWidget {
  const TextTaskPages({super.key});

  @override
  State<TextTaskPages> createState() => TextTaskPagesState();
}

class TextTaskPagesState extends State<TextTaskPages> {
  final PageController controller = PageController();

  final titles = <String>['Classify', 'Embed', 'Detect Languages'];
  int titleIndex = 0;

  void switchToPage(int index) {
    controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
    setState(() {
      titleIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    const activeTextStyle = TextStyle(
      fontWeight: FontWeight.bold,
      color: Colors.orange,
    );
    const inactiveTextStyle = TextStyle(
      color: Colors.white,
    );
    return Scaffold(
      appBar: AppBar(title: Text(titles[titleIndex])),
      body: PageView(
        controller: controller,
        children: const <Widget>[
          TextClassificationDemo(),
          TextEmbeddingDemo(),
          LanguageDetectionDemo(),
        ],
      ),
      bottomNavigationBar: SizedBox(
        height: 50,
        child: ColoredBox(
          color: Colors.blueGrey,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              TextButton(
                onPressed: () => switchToPage(0),
                child: Text(
                  'Classify',
                  style: titleIndex == 0 ? activeTextStyle : inactiveTextStyle,
                ),
              ),
              TextButton(
                onPressed: () => switchToPage(1),
                child: Text(
                  'Embed',
                  style: titleIndex == 1 ? activeTextStyle : inactiveTextStyle,
                ),
              ),
              TextButton(
                onPressed: () => switchToPage(2),
                child: Text(
                  'Detect Languages',
                  style: titleIndex == 2 ? activeTextStyle : inactiveTextStyle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
