// Copyright 2026. Licensed under Apache-2.0 (see the repository LICENSE).
#include "audio_stream_bridge.h"

#include <limits.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>

#if defined(_WIN32)
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
static SRWLOCK lock = SRWLOCK_INIT;
static void Lock(void) { AcquireSRWLockExclusive(&lock); }
static void Unlock(void) { ReleaseSRWLockExclusive(&lock); }
#else
#include <pthread.h>
static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
static void Lock(void) { pthread_mutex_lock(&lock); }
static void Unlock(void) { pthread_mutex_unlock(&lock); }
#endif

// Each open stream's Dart port, by slot. A message to a port whose isolate has
// gone is refused, not delivered, so a graph that outlives its isolate, as at
// a hot restart, cannot reach Dart; a NativeCallable deleted with its isolate
// would abort the process instead. One lock guards the table, and a callback
// holds it while it posts, so that once MpFlutterAudioStreamRelease returns
// nothing posts for the old stream. Streams take and free slots from their
// own worker isolates, on different threads, and the lock settles who gets a
// free slot too.
typedef struct {
  MpFlutterPost post;
  int64_t port;
} Slot;
static Slot slots[MP_FLUTTER_AUDIO_STREAM_SLOTS];

// Posts [value] to the slot's port, as an integer or, with [end], as null.
// False when the slot is free or its port refused it. Called with the lock.
static bool Post(int slot, bool end, int64_t value) {
  if (!slots[slot].post) return false;
  MpFlutterDartMessage message;
  memset(&message, 0, sizeof(message));
  message.type = end ? kMpFlutterDartNull : kMpFlutterDartInt64;
  message.value.as_int64 = value;
  return slots[slot].post(slots[slot].port, &message);
}

static char* CopyString(const char* value, MpFlutterAudioEvent* event) {
  if (!value) return NULL;
  const size_t size = strlen(value) + 1;
  char* copy = malloc(size);
  if (!copy) {
    event->copy_error = 1;
    return NULL;
  }
  memcpy(copy, value, size);
  return copy;
}

static void CopyHead(const MpFlutterClassificationsView* source, MpFlutterAudioHead* head,
                     MpFlutterAudioEvent* event) {
  head->head_index = source->head_index;
  head->head_name = CopyString(source->head_name, event);
  if (source->categories_count == 0) return;
  if (!source->categories || source->categories_count > INT_MAX) {
    event->copy_error = 2;
    return;
  }
  head->categories = calloc(source->categories_count, sizeof(*head->categories));
  if (!head->categories) {
    event->copy_error = 1;
    return;
  }
  head->categories_count = (int)source->categories_count;
  for (uint32_t i = 0; i < source->categories_count; ++i) {
    const MpFlutterCategoryView* category = &source->categories[i];
    head->categories[i].index = category->index;
    head->categories[i].score = category->score;
    head->categories[i].category_name = CopyString(category->category_name, event);
    head->categories[i].display_name = CopyString(category->display_name, event);
  }
}

// Copies Google's arguments, valid only during its callback, into memory the
// Dart receiver owns. Null when even the event could not be allocated.
static MpFlutterAudioEvent* Copy(int status, const MpFlutterAudioResultView* result) {
  MpFlutterAudioEvent* event = calloc(1, sizeof(*event));
  if (!event) return NULL;
  event->status = status;
  if (status != 0) return event;
  // Google's stream calls back with exactly one result, one window's.
  if (!result || result->results_count != 1 || !result->results) {
    event->copy_error = 2;
    return event;
  }
  const MpFlutterClassificationResultView* source = &result->results[0];
  event->timestamp_ms = source->timestamp_ms;
  event->has_timestamp_ms = source->has_timestamp_ms;
  if (source->classifications_count == 0) return event;
  if (!source->classifications || source->classifications_count > INT_MAX) {
    event->copy_error = 2;
    return event;
  }
  event->heads = calloc(source->classifications_count, sizeof(*event->heads));
  if (!event->heads) {
    event->copy_error = 1;
    return event;
  }
  event->heads_count = (int)source->classifications_count;
  for (uint32_t i = 0; i < source->classifications_count; ++i) {
    CopyHead(&source->classifications[i], &event->heads[i], event);
  }
  return event;
}

// Copies first, outside the lock, then posts the copy's address to the slot's
// port; address 0 tells the worker that the copy could not be allocated.
// Google frees its result when the callback returns, and the copy belongs to
// the worker once posted; a refused post leaves it here to free.
static void Deliver(int slot, int status, const MpFlutterAudioResultView* result) {
  MpFlutterAudioEvent* event = Copy(status, result);
  Lock();
  const bool posted = Post(slot, false, (int64_t)(intptr_t)event);
  Unlock();
  if (!posted) MpFlutterAudioEventFree(event);
}

// One callback per slot, since Google's callback has no user data to tell
// the streams apart.
#define MP_FLUTTER_SLOT(n)                                                        \
  static void Callback##n(int status, const MpFlutterAudioResultView* result) { \
    Deliver(n, status, result);                                                   \
  }
MP_FLUTTER_SLOT(0) MP_FLUTTER_SLOT(1) MP_FLUTTER_SLOT(2) MP_FLUTTER_SLOT(3)
MP_FLUTTER_SLOT(4) MP_FLUTTER_SLOT(5) MP_FLUTTER_SLOT(6) MP_FLUTTER_SLOT(7)
MP_FLUTTER_SLOT(8) MP_FLUTTER_SLOT(9) MP_FLUTTER_SLOT(10) MP_FLUTTER_SLOT(11)
MP_FLUTTER_SLOT(12) MP_FLUTTER_SLOT(13) MP_FLUTTER_SLOT(14) MP_FLUTTER_SLOT(15)
MP_FLUTTER_SLOT(16) MP_FLUTTER_SLOT(17) MP_FLUTTER_SLOT(18) MP_FLUTTER_SLOT(19)
MP_FLUTTER_SLOT(20) MP_FLUTTER_SLOT(21) MP_FLUTTER_SLOT(22) MP_FLUTTER_SLOT(23)
MP_FLUTTER_SLOT(24) MP_FLUTTER_SLOT(25) MP_FLUTTER_SLOT(26) MP_FLUTTER_SLOT(27)
MP_FLUTTER_SLOT(28) MP_FLUTTER_SLOT(29) MP_FLUTTER_SLOT(30) MP_FLUTTER_SLOT(31)
MP_FLUTTER_SLOT(32) MP_FLUTTER_SLOT(33) MP_FLUTTER_SLOT(34) MP_FLUTTER_SLOT(35)
MP_FLUTTER_SLOT(36) MP_FLUTTER_SLOT(37) MP_FLUTTER_SLOT(38) MP_FLUTTER_SLOT(39)
MP_FLUTTER_SLOT(40) MP_FLUTTER_SLOT(41) MP_FLUTTER_SLOT(42) MP_FLUTTER_SLOT(43)
MP_FLUTTER_SLOT(44) MP_FLUTTER_SLOT(45) MP_FLUTTER_SLOT(46) MP_FLUTTER_SLOT(47)
MP_FLUTTER_SLOT(48) MP_FLUTTER_SLOT(49) MP_FLUTTER_SLOT(50) MP_FLUTTER_SLOT(51)
MP_FLUTTER_SLOT(52) MP_FLUTTER_SLOT(53) MP_FLUTTER_SLOT(54) MP_FLUTTER_SLOT(55)
MP_FLUTTER_SLOT(56) MP_FLUTTER_SLOT(57) MP_FLUTTER_SLOT(58) MP_FLUTTER_SLOT(59)
MP_FLUTTER_SLOT(60) MP_FLUTTER_SLOT(61) MP_FLUTTER_SLOT(62) MP_FLUTTER_SLOT(63)

static const MpFlutterAudioCallback callbacks[MP_FLUTTER_AUDIO_STREAM_SLOTS] = {
    Callback0,  Callback1,  Callback2,  Callback3,  Callback4,  Callback5,  Callback6,
    Callback7,  Callback8,  Callback9,  Callback10, Callback11, Callback12, Callback13,
    Callback14, Callback15, Callback16, Callback17, Callback18, Callback19, Callback20,
    Callback21, Callback22, Callback23, Callback24, Callback25, Callback26, Callback27,
    Callback28, Callback29, Callback30, Callback31, Callback32, Callback33, Callback34,
    Callback35, Callback36, Callback37, Callback38, Callback39, Callback40, Callback41,
    Callback42, Callback43, Callback44, Callback45, Callback46, Callback47, Callback48,
    Callback49, Callback50, Callback51, Callback52, Callback53, Callback54, Callback55,
    Callback56, Callback57, Callback58, Callback59, Callback60, Callback61, Callback62,
    Callback63,
};

int MpFlutterAudioStreamAcquire(MpFlutterPost post, int64_t port,
                                MpFlutterAudioCallback* callback) {
  if (!callback) return -1;
  *callback = NULL;
  if (!post) return -1;
  int slot = -1;
  Lock();
  for (int i = 0; i < MP_FLUTTER_AUDIO_STREAM_SLOTS; ++i) {
    if (!slots[i].post) {
      slots[i].post = post;
      slots[i].port = port;
      slot = i;
      break;
    }
  }
  Unlock();
  if (slot >= 0) *callback = callbacks[slot];
  return slot;
}

void MpFlutterAudioStreamEnd(int slot) {
  if (slot < 0 || slot >= MP_FLUTTER_AUDIO_STREAM_SLOTS) return;
  Lock();
  // To the same port as the results, so it arrives after all of them.
  Post(slot, true, 0);
  Unlock();
}

void MpFlutterAudioStreamRelease(int slot) {
  if (slot < 0 || slot >= MP_FLUTTER_AUDIO_STREAM_SLOTS) return;
  Lock();
  slots[slot].post = NULL;
  slots[slot].port = 0;
  Unlock();
}

void MpFlutterAudioEventFree(MpFlutterAudioEvent* event) {
  if (!event) return;
  if (event->heads) {
    for (int i = 0; i < event->heads_count; ++i) {
      MpFlutterAudioHead* head = &event->heads[i];
      if (head->categories) {
        for (int j = 0; j < head->categories_count; ++j) {
          free(head->categories[j].category_name);
          free(head->categories[j].display_name);
        }
      }
      free(head->categories);
      free(head->head_name);
    }
  }
  free(event->heads);
  free(event);
}
