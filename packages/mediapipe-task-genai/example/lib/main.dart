import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'llm_inference_demo.dart';
import 'logging.dart';

/// {@template AppBlocObserver}
/// Logger of all things related to `pkg:flutter_bloc`.
/// {@endtemplate}
class AppBlocObserver extends BlocObserver {
  /// {@macro AppBlocObserver}
  const AppBlocObserver();

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);
    // print('onChange(${bloc.runtimeType}, $change)');
  }

  @override
  void onEvent(Bloc<dynamic, dynamic> bloc, Object? event) {
    // print('onEvent($event)');
    super.onEvent(bloc, event);
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    // print('onError(${bloc.runtimeType}, $error, $stackTrace)');
    super.onError(bloc, error, stackTrace);
  }
}

void main() {
  initLogging();
  Bloc.observer = const AppBlocObserver();
  runApp(
    const MaterialApp(
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate, // This is required
      ],
      home: MainApp(),
    ),
  );
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  final PageController controller = PageController();

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
        children: const <Widget>[
          LlmInferenceDemo(),
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
