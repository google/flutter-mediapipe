# Runtime logs

Planned, not started: no package captures Google's runtime logs. Found on
2026-10-04, on `main` at `3e217ac`, with Google's runtimes as pinned then:
desktop 1.0.0 (macOS, Windows) and 1.0.1 (Linux), iOS SDK 1.0.1, Android AARs
1.0.0, web 1.0.1. References to files that have since moved or gone were
rechecked on 2026-10-06 at `bbf198c`, and [Google's log
callback](#googles-log-callback) was added on 2026-10-12 for Google's
October 9 build. Paths are from the repository root. Check a finding again
before building on it.

## Goal

Every line Google's runtimes log (MediaPipe's and TensorFlow Lite's) readable
through one API exported from `packages/mediapipe-core/lib/mediapipe_core.dart`,
identical on Android, iOS, macOS, Linux, Windows and the web. `tool/api_parity`
checks that parity and snapshots the API, so its snapshots change with this.
The API's shape is undecided.

## Today

No package captures runtime logs, and none has a log stream, callback or level
option. The only runtime text that reaches Dart is the message of a failed
call, as `TaskException`:

- **Android, iOS and the desktop:** the C API's error string (`checkedCall`
  in `packages/mediapipe-task-vision/lib/src/io/native_vision_image.dart`).
- **Web:** the JS error's message, posted by each family's `assets/worker.js`.

Warnings and info lines never arrive.

## Google's log callback

Since Google's October 9, 2026 build (1.1.1), and in the 1.2.0 build the hooks pin, every
per-family library exports a C log callback, declared in `core/mp_logging.h`
under `packages/mediapipe-core/native/include`:

```c
typedef void (*MpLogCallback)(int severity, const char* message,
                              void* user_data);
MP_EXPORT void MpSetLoggingCallback(MpLogCallback callback, void* user_data);
MP_EXPORT void MpRemoveLoggingCallback(void);
```

Google's implementation (`mediapipe/tasks/c/core/mp_logging.cc`, public since
2026-10-09) registers one `absl::LogSink`; `severity` is absl's (0 INFO,
1 WARNING, 2 ERROR, 3 FATAL). It is the route to build on, with these limits:

- **One registration per library.** Each family's library has its own absl,
  so each family registers its own callback; registering again replaces the
  library's previous one.
- **Copy the text.** The message is a temporary `std::string`, valid only
  during the call, and Google calls from its own threads. A
  `NativeCallable.listener` runs later, on the isolate, so a small C shim
  (like the text and audio stream bridges) has to copy each message and pass
  the copy on.
- **absl only.** TensorFlow Lite's own lines probably bypass it, and adding a
  sink does not stop absl's stderr or logcat output. Not yet run.
- **Not everywhere.** Browsers need the `Module.print` route below.

## Where the lines go, and what could capture them

### macOS, Linux, Windows

The process's stderr, from two writers. MediaPipe logs through absl, and
TensorFlow Lite prints its own lines without absl's prefix. From a Linux
desktop run on 2026-09-18:

```
INFO: Created TensorFlow Lite XNNPACK delegate for CPU.
W0000 00:00:1789743014.362435    6993 face_landmarker_graph.cc:180] Sets FaceBlendshapesGraph acceleration to xnnpack by default.
```

The full Linux and Windows logs were removed in `9383185`. Read them with
`git show 9383185^:packages/mediapipe-task-vision/tool/validations/2026-09-18-desktop-cpu-gallery/linux/native/inference-release.log`
(or `windows/` in place of `linux/`).

Google's C API has no log function: none of the 128 `Mp*` exports of its
macOS library. That library does export C++ symbols, with no inline namespace
(`nm -gU | c++filt`): `absl::log_internal::AddLogSink` and `RemoveLogSink`,
`absl::SetMinLogLevel`, `absl::SetStderrThreshold` and
`tflite::LoggerOptions::SetMinimumLogSeverity`. A sink needs a C++ shim whose
`absl::LogSink` and `absl::LogEntry` match Google's build, which nothing
guarantees, and it would likely still miss TensorFlow Lite's lines. The Linux
and Windows libraries were not inspected; a Windows DLL exports only what it
declares.

That was Google's 1.0.0 single library. The per-family libraries the
packages bundle now export only the `Mp*` C API on macOS, Linux and iOS; the
Windows DLLs add TensorFlow Lite's and LiteRT's C functions
([UP-045](../../../upstream-issues.md#up-045-per-family-windows-libraries-export-tensorflow-lite-and-litert)),
not absl. 1.1.0 adds one level setting to the C API, `min_log_severity` in the
Proofreader and Summarizer options, which the packages set to Google's default
of 4.

Redirecting file descriptor 2 into a pipe needs no symbols and catches both
writers and every library, but it is process-wide, and a reader that falls
behind blocks the threads that log.

### iOS

stderr and the system log. Each family bundles Google's per-family C
library (`MediaPipeTasksVisionC` and so on), which exports only the `Mp*`
C API, so there is no absl or tflite symbol to register a sink with.

### Android

logcat. Google's per-family libraries (`libmediapipe_tasks_vision.so` and
the others) import `__android_log_print`, `__android_log_vprint` and
`__android_log_write`, and export only the C API, so there is no sink to
register. An app's stderr reaches
nothing. That leaves reading the app's own logcat from the plugin
(`logcat --pid`).

### Web

The worker's console. Google's Emscripten loader (`wasm/*_wasm_internal.js`)
sends stdout to `console.log` and stderr to `console.error` unless
`Module.print` and `Module.printErr` are set, and the bundle passes
`self.Module` to its module factory (read in the vision bundle only). Vision's
`assets/worker.js` already sets `self.Module` around `createFromOptions`, for
`instantiateWasm`; text's and audio's do not. The lines need a worker message
of their own: vision's `bridge.js` and core's `task_bridge.js` drop a message
whose id has no pending request. The bundle's few direct `console.warn` and
`console.error` calls bypass both hooks.

## Also

- The packages now bundle Google's per-family C libraries (see
  [PER_FAMILY_RUNTIMES.md](PER_FAMILY_RUNTIMES.md)), which export only `Mp*`
  functions, with no absl or tflite symbols (checked on the macOS and iOS
  vision libraries, 2026-10-06). The C++ sink route is closed; Google's
  October 9 build adds a C log function instead
  ([Google's log callback](#googles-log-callback)).
- Google logs from its own threads (the thread ids in the samples differ), and
  the FFI tasks run in worker isolates (`vision_task_worker.dart`,
  `text_task_worker.dart`). A native callback into Dart has to be callable from
  any thread (`NativeCallable.listener`) and own a copy of the text.
- The packages' own diagnostics bypass Dart too: one `console.warn` in
  vision's `worker.js`. No package uses `package:logging` any more. The
  MPTRACE stderr lines and the `src/legacy` and `mediapipe_genai` records the
  first write-up listed were removed in `bbf198c` and `d9fbdd3`.
- Google's "usage logging" is something else: the telemetry upload of
  `upstream-issues.md` UP-025 (`MpBaseOptions.ca_bundle_path`).

## Not tried

- Redirecting file descriptor 2 into a pipe on desktop.
- Reading the app's own logcat from the Android plugin (`logcat --pid`).
- Searching Google's Java API for a log callback.
- Inspecting the Linux and Windows libraries' exports.
