import 'dart:ffi';
import 'dart:io';

import 'package:mediapipe_core/mediapipe_core.dart';
import 'package:mediapipe_core/platform_interface.dart';
import 'package:mediapipe_core/native_structs.dart' show checkNativeStatus;
import 'package:mediapipe_core/task_worker.dart';

import 'third_party/mediapipe/classic_text_bindings.dart' as mp;

/// This process's target, named as core's [tasksRuntimeTargets] names the
/// targets where Google's text library serves the text tasks, the
/// Proofreader and Summarizer included.
final _target =
    '${Platform.operatingSystem}/${Abi.current().toString().split('_').last}';

/// Validate availability before starting a worker or resolving inference calls.
void requireTextTasksRuntime() {
  if (!tasksRuntimeTargets.containsKey(_target)) {
    throw const RuntimeUnavailableException(
      "Google's text runtime is unavailable on this platform.",
      fix:
          'Use Android (arm64 or x64), iOS arm64, macOS arm64, Linux x64 or '
          'Windows x64, or a browser.',
    );
  }
  try {
    Native.addressOf<
      NativeFunction<
        Int32 Function(
          Pointer<mp.MpTextClassifierOptions>,
          Pointer<Pointer<Void>>,
          Pointer<Pointer<Char>>,
        )
      >
    >(mp.classifierCreate);
  } catch (error) {
    if (missingLinuxGraphicsLibraries('$error') case final missing?) {
      throw missing;
    }
    throw RuntimeUnavailableException(
      "Google's text runtime is unavailable.",
      fix: tasksRuntimeUnavailable('this text task', Platform.operatingSystem),
    );
  }
}

/// Runs one of Google's text calls, as core's [checkNativeStatus] does with
/// this family's library.
void checkTextStatus(int Function(Pointer<Pointer<Char>>) call) =>
    checkNativeStatus(call, mp.errorFree);

/// Synchronous native owner. Only its worker exposes asynchronous requests.
abstract base class NativeClassicTextTask<I, R>
    extends WorkerTask<I, R, Never> {
  /// Native handle, owned exclusively by this executor.
  Pointer<Void> handle = nullptr;

  /// Reject reuse and embedded NUL before reaching a native API.
  void checkInput(String text) {
    if (handle == nullptr) throw StateError('Text task has been disposed.');
    if (text.contains('\u0000')) {
      throw ArgumentError('Text must not contain NUL.');
    }
  }
}
