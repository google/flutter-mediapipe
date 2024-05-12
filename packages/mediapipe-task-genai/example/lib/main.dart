import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:logging/logging.dart';
import 'llm_inference_demo.dart';
import 'logging.dart';

/// {@template AppBlocObserver}
/// Logger of all things related to `pkg:flutter_bloc`.
/// {@endtemplate}
class AppBlocObserver extends BlocObserver {
  /// {@macro AppBlocObserver}
  const AppBlocObserver();

  static final _log = Logger('AppBlocObserver');

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    _log.finest('onChange(${bloc.runtimeType}, $change)');
    super.onChange(bloc, change);
  }

  @override
  void onEvent(Bloc<dynamic, dynamic> bloc, Object? event) {
    _log.finest('onEvent($event)');
    super.onEvent(bloc, event);
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    _log.shout('onError(${bloc.runtimeType}, $error, $stackTrace)');
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
      body: PageView(
        controller: controller,
        children: const <Widget>[
          LlmInferenceDemo(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: titleIndex,
        onTap: switchToPage,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble),
            activeIcon: Icon(Icons.chat_bubble, color: Colors.blue),
            label: 'Inference',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.cancel),
            activeIcon: Icon(Icons.cancel, color: Colors.blue),
            label: 'Coming soon',
          ),
        ],
      ),
    );
  }
}
