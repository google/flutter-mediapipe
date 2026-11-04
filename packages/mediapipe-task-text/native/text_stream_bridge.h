// Copyright 2026. Licensed under Apache-2.0 (see the repository LICENSE).
#ifndef MEDIAPIPE_FLUTTER_TEXT_STREAM_BRIDGE_H_
#define MEDIAPIPE_FLUTTER_TEXT_STREAM_BRIDGE_H_

#include <stdbool.h>
#include <stdint.h>

// The bridge is a shared library the Dart bindings resolve by name; a Windows
// DLL exports nothing unless told to, while clang and gcc export by default.
#if defined(_WIN32)
#define MP_FLUTTER_EXPORT __declspec(dllexport)
#else
#define MP_FLUTTER_EXPORT __attribute__((visibility("default")))
#endif

// Views of Google's callback results (text_proofreader.h, text_summarizer.h),
// owned by Google and valid only during the callback. tool/abi_check.cc checks
// that their layouts match Google's.
typedef struct {
  int type;
  const char* text;
} MpFlutterCorrectionView;

typedef struct {
  const char* chunk;
  int corrections_count;
  const MpFlutterCorrectionView* corrections;
  bool done;
} MpFlutterProofreaderStreamView;

typedef struct {
  const char* chunk;
  bool done;
} MpFlutterSummarizerStreamView;

// A deep copy owned by the Dart receiver, freed with MpFlutterTextEventFree.
typedef struct {
  char* text;
  int corrections_count;
  MpFlutterCorrectionView* corrections;
  char* error;
  int copy_error;  // 0: success, 1: allocation failure, 2: invalid native payload.
  bool terminal;   // Google's last callback for the request.
} MpFlutterTextEvent;

// What the bridge posts instead of a copy's address when the copy itself
// could not be allocated, so the worker still learns which event was last.
// Only these two values are markers: an address can be negative as an
// int64_t, since Android tags heap pointers in their top byte.
enum { kMpFlutterTextLostEvent = -1, kMpFlutterTextLostTerminalEvent = -2 };

// The layout of the Dart VM's Dart_CObject (dart_native_api.h), for the one
// kind of message the bridge posts: an integer.
enum { kMpFlutterDartInt64 = 3 };
typedef struct {
  int type;
  union {
    int64_t as_int64;
    // The size of the VM's union, whose largest member is five words.
    unsigned char reserved[40];
  } value;
} MpFlutterDartMessage;

// Dart_PostCObject, which dart:ffi gives as NativeApi.postCObject: callable
// from any thread, and false, without taking the message, when the port is
// closed, as it is once its isolate has gone.
typedef bool (*MpFlutterPost)(int64_t port, MpFlutterDartMessage* message);
typedef struct MpFlutterTextStreamContext MpFlutterTextStreamContext;

// A context whose callbacks post each copy's address to the Dart [port].
MP_FLUTTER_EXPORT MpFlutterTextStreamContext* MpFlutterTextStreamCreate(
    MpFlutterPost post, int64_t port);
MP_FLUTTER_EXPORT void MpFlutterTextStreamFree(MpFlutterTextStreamContext* context);
MP_FLUTTER_EXPORT void MpFlutterTextEventFree(MpFlutterTextEvent* event);
MP_FLUTTER_EXPORT void MpFlutterProofreaderCallback(
    void* context, const MpFlutterProofreaderStreamView* result, const char* error);
MP_FLUTTER_EXPORT void MpFlutterSummarizerCallback(
    void* context, const MpFlutterSummarizerStreamView* result, const char* error);

#endif
