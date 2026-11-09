// Exercise the Text to Speech guard's cancels, and its handles across
// threads, under AddressSanitizer.
#include "text_to_speech_guard.h"

#include <assert.h>
#include <pthread.h>
#include <stdatomic.h>
#include <stdint.h>
#include <stdlib.h>

// Stand-ins for Google's cancels: each writes to its handle, which
// AddressSanitizer reports if the handle has been freed.
static atomic_int cancels;
static atomic_int stream_cancels;

static void cancel(void* tts) {
  *(volatile int*)tts = 1;
  atomic_fetch_add(&cancels, 1);
}

static void stream_cancel(void* stream) {
  *(volatile int*)stream = 1;
  atomic_fetch_add(&stream_cancels, 1);
}

static void test_cancels(void) {
  MpFlutterTtsGuard* guard = MpFlutterTtsGuardNew(cancel, stream_cancel);
  assert(guard);
  int tts = 0;
  int stream = 0;

  // Nothing running: nothing to cancel, and the next request runs.
  MpFlutterTtsGuardCancel(guard, 0);
  assert(atomic_load(&cancels) == 0);
  assert(MpFlutterTtsGuardBegin(guard, 1, &tts));
  MpFlutterTtsGuardCancel(guard, 1);
  assert(atomic_load(&cancels) == 1 && tts == 1);
  assert(MpFlutterTtsGuardEnd(guard));

  // A cancel covers a request still waiting, and not a later one.
  MpFlutterTtsGuardCancel(guard, 3);
  assert(!MpFlutterTtsGuardBegin(guard, 2, &tts));
  assert(!MpFlutterTtsGuardBegin(guard, 3, &tts));
  assert(MpFlutterTtsGuardBegin(guard, 4, &tts));
  assert(!MpFlutterTtsGuardEnd(guard));

  // A stream takes the stream's cancel, repeated if it came while starting.
  assert(MpFlutterTtsGuardBegin(guard, 5, &tts));
  MpFlutterTtsGuardCancel(guard, 5);
  assert(atomic_load(&cancels) == 2);
  MpFlutterTtsGuardSetStream(guard, &stream);
  assert(atomic_load(&stream_cancels) == 1 && stream == 1);
  MpFlutterTtsGuardCancel(guard, 5);
  assert(atomic_load(&stream_cancels) == 2 && atomic_load(&cancels) == 2);
  MpFlutterTtsGuardSetStream(guard, NULL);
  assert(MpFlutterTtsGuardEnd(guard));

  // One stream's cancel reaches only that stream, and only while it runs.
  assert(MpFlutterTtsGuardBegin(guard, 6, &tts));
  MpFlutterTtsGuardSetStream(guard, &stream);
  MpFlutterTtsGuardCancelStream(guard, 5);
  assert(atomic_load(&stream_cancels) == 2);
  MpFlutterTtsGuardCancelStream(guard, 6);
  assert(atomic_load(&stream_cancels) == 3);
  assert(!MpFlutterTtsGuardEnd(guard));
  MpFlutterTtsGuardCancelStream(guard, 6);
  MpFlutterTtsGuardCancel(guard, 6);
  assert(atomic_load(&stream_cancels) == 3 && atomic_load(&cancels) == 2);
  MpFlutterTtsGuardFree(guard);
}

// The worker opens and frees handles for each request while another thread
// cancels: no cancel may reach a freed one.
enum { kRequests = 20000 };
static MpFlutterTtsGuard* shared;
static atomic_int done;

static void* worker(void* unused) {
  (void)unused;
  for (int64_t request = 1; request <= kRequests; ++request) {
    int* tts = malloc(sizeof(int));
    if (MpFlutterTtsGuardBegin(shared, request, tts)) {
      if (request % 2 == 0) {
        int* stream = malloc(sizeof(int));
        MpFlutterTtsGuardSetStream(shared, stream);
        MpFlutterTtsGuardSetStream(shared, NULL);
        free(stream);
      }
      MpFlutterTtsGuardEnd(shared);
    }
    free(tts);
  }
  atomic_store(&done, 1);
  return NULL;
}

static void* canceller(void* unused) {
  (void)unused;
  for (int64_t i = 1; !atomic_load(&done); ++i) {
    if (i % 3 == 0) {
      MpFlutterTtsGuardCancelStream(shared, i % kRequests);
    } else {
      MpFlutterTtsGuardCancel(shared, i % kRequests);
    }
  }
  return NULL;
}

static void test_threads(void) {
  shared = MpFlutterTtsGuardNew(cancel, stream_cancel);
  assert(shared);
  pthread_t threads[3];
  assert(pthread_create(&threads[0], NULL, worker, NULL) == 0);
  assert(pthread_create(&threads[1], NULL, canceller, NULL) == 0);
  assert(pthread_create(&threads[2], NULL, canceller, NULL) == 0);
  for (int i = 0; i < 3; ++i) assert(pthread_join(threads[i], NULL) == 0);
  MpFlutterTtsGuardFree(shared);
}

int main(void) {
  test_cancels();
  test_threads();
  return 0;
}
