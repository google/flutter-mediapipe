import 'package:web/web.dart' as web;

/// Removes web/index.html's loading screen, which covers the page while
/// Flutter's engine and the app download. It goes in the frame that draws what
/// it covered, so a test or a visitor never meets the two at once.
void hideSplash() => web.document.getElementById('splash')?.remove();
