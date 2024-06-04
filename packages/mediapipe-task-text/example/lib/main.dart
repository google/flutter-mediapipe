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

  @override
  void initState() {
    controller.addListener(() {
      final newIndex = controller.page?.toInt();
      if (newIndex != null && newIndex != titleIndex) {
        setState(() {
          titleIndex = newIndex;
        });
      }
    });
    super.initState();
  }

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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: titleIndex,
        onTap: switchToPage,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            activeIcon: Icon(Icons.search, color: Colors.blue),
            label: 'Classify',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.arrow_downward),
            activeIcon: Icon(Icons.arrow_downward, color: Colors.blue),
            label: 'Embed',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.flag),
            activeIcon: Icon(Icons.flag, color: Colors.blue),
            label: 'Detect Languages',
          ),
        ],
      ),
    );
  }
}
