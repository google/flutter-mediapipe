/// Google's native runtime where the compiler has `dart:io`, and stubs that
/// explain what browsers lack elsewhere. Each pair exports the same names.
library;

export 'native_stub.dart'
    if (dart.library.io) 'io/native_audio_classifier.dart';
export 'speech_stub.dart' if (dart.library.io) 'io/native_speech.dart';
