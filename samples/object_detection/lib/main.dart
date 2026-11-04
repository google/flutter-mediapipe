import 'package:flutter/material.dart';

import 'camera_page.dart';
import 'detector_helper.dart';
import 'gallery_page.dart';
import 'settings_panel.dart';

void main() => runApp(const ObjectDetectionApp());

class ObjectDetectionApp extends StatelessWidget {
  const ObjectDetectionApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'MediaPipe Object Detection',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F9D58)),
    ),
    darkTheme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0F9D58),
        brightness: Brightness.dark,
      ),
    ),
    home: const HomePage(),
  );
}

/// Camera and Gallery tabs over a shared settings panel, as in Google's
/// Android sample.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _settings = ValueNotifier(const DetectorSettings());
  final _inferenceMilliseconds = ValueNotifier<int?>(null);
  int _tab = 0;

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _settings.dispose();
    _inferenceMilliseconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('MediaPipe Object Detection')),
    body: Column(
      children: [
        Expanded(
          // Only the open tab runs, so leaving Camera closes the camera.
          child: _tab == 0
              ? CameraPage(
                  settings: _settings,
                  inferenceMilliseconds: _inferenceMilliseconds,
                  onError: _showError,
                )
              : GalleryPage(
                  settings: _settings,
                  inferenceMilliseconds: _inferenceMilliseconds,
                  onError: _showError,
                ),
        ),
        SettingsPanel(
          settings: _settings,
          inferenceMilliseconds: _inferenceMilliseconds,
        ),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _tab,
      onDestinationSelected: (tab) {
        _inferenceMilliseconds.value = null;
        setState(() => _tab = tab);
      },
      destinations: const [
        NavigationDestination(icon: Icon(Icons.camera_alt), label: 'Camera'),
        NavigationDestination(
          icon: Icon(Icons.photo_library),
          label: 'Gallery',
        ),
      ],
    ),
  );
}
