// Copyright 2026. Licensed under Apache-2.0 (see the repository LICENSE).
#ifndef MEDIAPIPE_FLUTTER_AUDIO_STREAM_BRIDGE_H_
#define MEDIAPIPE_FLUTTER_AUDIO_STREAM_BRIDGE_H_

#include <stdbool.h>
#include <stdint.h>

// The bridge is a shared library the Dart bindings resolve by name; a Windows
// DLL exports nothing unless told to, while clang and gcc export by default.
#if defined(_WIN32)
#define MP_FLUTTER_EXPORT __declspec(dllexport)
#else
#define MP_FLUTTER_EXPORT __attribute__((visibility("default")))
#endif

// How many audio streams may be open at once. Google's result callback carries
// no user data, so each open stream needs a callback function of its own, and
// the bridge compiles this many.
#define MP_FLUTTER_AUDIO_STREAM_SLOTS 64

// Google's mediapipe==1.0.1 C API layouts (audio_classifier.h,
// classification_result.h, category.h). Google's headers are C++, so this C
// file declares its own views. They are valid only during Google's callback.
typedef struct {
  int index;
  float score;
  const char* category_name;
  const char* display_name;
} MpFlutterCategoryView;

typedef struct {
  const MpFlutterCategoryView* categories;
  uint32_t categories_count;
  int head_index;
  const char* head_name;
} MpFlutterClassificationsView;

typedef struct {
  const MpFlutterClassificationsView* classifications;
  uint32_t classifications_count;
  int64_t timestamp_ms;
  bool has_timestamp_ms;
} MpFlutterClassificationResultView;

typedef struct {
  const MpFlutterClassificationResultView* results;
  int results_count;
} MpFlutterAudioResultView;

// Google's MpAudioClassifierOptions.result_callback.
typedef void (*MpFlutterAudioCallback)(int status, const MpFlutterAudioResultView* result);

// A deep copy of one category, head or callback, owned by the Dart receiver and
// freed with MpFlutterAudioEventFree.
typedef struct {
  int index;
  float score;
  char* category_name;
  char* display_name;
} MpFlutterAudioCategory;

typedef struct {
  MpFlutterAudioCategory* categories;
  int categories_count;
  int head_index;
  char* head_name;
} MpFlutterAudioHead;

typedef struct {
  int status;      // Google's MpStatus: 0 with a result, its code without.
  int copy_error;  // 0: success, 1: allocation failure, 2: invalid native payload.
  int64_t timestamp_ms;
  bool has_timestamp_ms;
  MpFlutterAudioHead* heads;
  int heads_count;
} MpFlutterAudioEvent;

// The layout of the Dart VM's Dart_CObject (dart_native_api.h), for the two
// kinds of message the bridge posts: a copy's address as an integer, and
// null for the end.
enum { kMpFlutterDartNull = 0, kMpFlutterDartInt64 = 3 };
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

// Takes a free slot whose results [post] sends to the Dart [port], and returns
// its index, with the slot's callback for Google's options in [callback]; -1
// when every slot is taken.
MP_FLUTTER_EXPORT int MpFlutterAudioStreamAcquire(MpFlutterPost post, int64_t port,
                                                  MpFlutterAudioCallback* callback);

// Posts the end to the slot's port, after every result.
MP_FLUTTER_EXPORT void MpFlutterAudioStreamEnd(int slot);

// Frees the slot. When this returns no callback is posting to its port, and
// later callbacks on the slot are ignored until it is taken again.
MP_FLUTTER_EXPORT void MpFlutterAudioStreamRelease(int slot);

MP_FLUTTER_EXPORT void MpFlutterAudioEventFree(MpFlutterAudioEvent* event);

#endif
