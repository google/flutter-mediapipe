// Copyright 2026. Licensed under Apache-2.0 (see the repository LICENSE).
#include "text_to_speech_guard.h"

#include <stddef.h>
#include <stdlib.h>

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

// Why this is race free: one lock guards every field, and the caller calls
// Google's cancels only while holding it, on handles it reads under it. The
// worker publishes a handle under the lock before a request uses it, and
// withdraws it under the lock before Google frees it, so a cancel either
// finishes before the withdrawal or sees no handle. Google's cancels are
// lock free, so holding the lock across them blocks nothing for long.
//
// Google resets a task's cancel when a synthesis begins, so a cancel landing
// between Begin and that reset is lost to Google; End still reports it, and
// the worker discards the result. A stream's cancel stays set, so SetStream
// repeats one that came while the stream was starting.
struct MpFlutterTtsGuard {
  MpFlutterTtsCancel cancel;
  MpFlutterTtsCancel stream_cancel;
  int64_t running;          // The request the worker runs; 0 between requests.
  int64_t cancelled_through;
  void* tts;                // Published while a request runs.
  void* stream;             // Published while the running request's stream is open.
};

static bool Covered(const MpFlutterTtsGuard* guard) {
  return guard->running != 0 && guard->running <= guard->cancelled_through;
}

MpFlutterTtsGuard* MpFlutterTtsGuardNew(MpFlutterTtsCancel cancel,
                                        MpFlutterTtsCancel stream_cancel) {
  MpFlutterTtsGuard* guard = calloc(1, sizeof(*guard));
  if (!guard) return NULL;
  guard->cancel = cancel;
  guard->stream_cancel = stream_cancel;
  return guard;
}

void MpFlutterTtsGuardFree(MpFlutterTtsGuard* guard) { free(guard); }

bool MpFlutterTtsGuardBegin(MpFlutterTtsGuard* guard, int64_t request, void* tts) {
  Lock();
  const bool start = request > guard->cancelled_through;
  if (start) {
    guard->running = request;
    guard->tts = tts;
  }
  Unlock();
  return start;
}

void MpFlutterTtsGuardSetStream(MpFlutterTtsGuard* guard, void* stream) {
  Lock();
  guard->stream = stream;
  if (stream && Covered(guard)) guard->stream_cancel(stream);
  Unlock();
}

bool MpFlutterTtsGuardEnd(MpFlutterTtsGuard* guard) {
  Lock();
  const bool cancelled = Covered(guard);
  guard->running = 0;
  guard->tts = NULL;
  guard->stream = NULL;
  Unlock();
  return cancelled;
}

void MpFlutterTtsGuardCancel(MpFlutterTtsGuard* guard, int64_t through) {
  Lock();
  if (through > guard->cancelled_through) guard->cancelled_through = through;
  if (Covered(guard)) {
    if (guard->stream) {
      guard->stream_cancel(guard->stream);
    } else if (guard->tts) {
      guard->cancel(guard->tts);
    }
  }
  Unlock();
}

void MpFlutterTtsGuardCancelStream(MpFlutterTtsGuard* guard, int64_t request) {
  Lock();
  if (guard->running == request && guard->stream) guard->stream_cancel(guard->stream);
  Unlock();
}
