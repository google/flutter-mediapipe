import 'package:example/llm_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'model_location_provider.dart';
import 'llm_inference_demo.dart';
import 'logging.dart';

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
  Widget build(BuildContext context) => const MaterialApp(home: GenAiPages());
}

class GenAiPages extends StatefulWidget {
  const GenAiPages({super.key});

  @override
  State<GenAiPages> createState() => GenAiPagesState();
}

class GenAiPagesState extends State<GenAiPages> {
  final PageController controller = PageController();
  final ModelLocationProvider provider = ModelLocationProvider.fromEnvironment(
    LlmModel.gemma4bCpu,
  );

  final titles = <String>['Inference'];
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
      body: PageView(
        controller: controller,
        children: <Widget>[
          ChangeNotifierProvider<ModelLocationProvider>.value(
            value: provider,
            child: const LlmInferenceDemo(),
          ),
        ],
      ),
      bottomNavigationBar: SizedBox(
        height: 50 + MediaQuery.of(context).viewPadding.bottom / 2,
        child: ColoredBox(
          color: Colors.blueGrey,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  TextButton(
                    onPressed: () => switchToPage(0),
                    child: Text(
                      'Inference',
                      style:
                          titleIndex == 0 ? activeTextStyle : inactiveTextStyle,
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: MediaQuery.of(context).viewPadding.bottom / 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
