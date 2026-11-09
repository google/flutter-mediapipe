/// Browsers never call Google's C API; these exist so the family packages'
/// conditional imports resolve everywhere.
library;

/// Browsers have no host system value; the native runtime is never loaded.
int get mpHostSystem =>
    throw UnsupportedError('Google\'s C API runs on native platforms only.');

/// Browsers have no host version value: Google's JavaScript runtime reports
/// its own.
String get mpHostVersion =>
    throw UnsupportedError('Google\'s C API runs on native platforms only.');

/// Browsers run no C API, so no app ID goes through it.
String? get mpAppId =>
    throw UnsupportedError('Google\'s C API runs on native platforms only.');

/// Browsers run no C API, so no app version goes through it.
String? get mpAppVersion =>
    throw UnsupportedError('Google\'s C API runs on native platforms only.');

/// Browsers load no native library, so no loader error names one.
StateError? missingLinuxGraphicsLibraries(String loaderError) => null;

/// Model paths pass through unchanged off `dart:io` platforms.
String nativeModelPath(String path) => path;

/// Browsers load no Android library, so there is no `JNI_OnLoad` to run.
void runJniOnLoad(Object symbol) {}
