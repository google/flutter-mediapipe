// Exercise the bridge's copies, posts and slots across threads under
// AddressSanitizer.
#include "audio_stream_bridge.h"

#include <assert.h>
#include <pthread.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

// A stand-in for Dart_PostCObject: records each message, or refuses it as the
// VM does when the port's isolate has gone.
static MpFlutterAudioEvent* received;
static int deliveries;
static bool ended;
static bool refusing;
static int64_t last_port;

static bool post(int64_t port, MpFlutterDartMessage* message) {
  if (refusing) return false;
  last_port = port;
  if (message->type == kMpFlutterDartNull) {
    ended = true;
    return true;
  }
  assert(message->type == kMpFlutterDartInt64);
  assert(!received);
  received = (MpFlutterAudioEvent*)(intptr_t)message->value.as_int64;
  ++deliveries;
  return true;
}

static void release(void) {
  MpFlutterAudioEventFree(received);
  received = NULL;
}

typedef struct {
  MpFlutterAudioCallback callback;
} Delivery;

// Google calls back on its own threads and frees its result on return, so
// the source is scribbled over and freed as soon as the callback returns.
static void* deliver(void* argument) {
  const Delivery* delivery = argument;
  char* speech = strdup("Speech");
  char* music = strdup("Música");
  char* head = strdup("scores");
  MpFlutterCategoryView* categories = calloc(2, sizeof(*categories));
  categories[0] = (MpFlutterCategoryView){0, 0.91796875f, speech, NULL};
  categories[1] = (MpFlutterCategoryView){132, 0.0078125f, music, music};
  MpFlutterClassificationsView* heads = calloc(1, sizeof(*heads));
  *heads = (MpFlutterClassificationsView){categories, 2, 0, head};
  MpFlutterClassificationResultView* result = calloc(1, sizeof(*result));
  *result = (MpFlutterClassificationResultView){heads, 1, 9223372036854775LL, true};
  const MpFlutterAudioResultView view = {result, 1};
  delivery->callback(0, &view);
  memset(speech, 'x', strlen(speech));
  memset(music, 'x', strlen(music));
  memset(categories, 0xff, 2 * sizeof(*categories));
  free(speech);
  free(music);
  free(head);
  free(categories);
  free(heads);
  free(result);
  return NULL;
}

static int taken[MP_FLUTTER_AUDIO_STREAM_SLOTS];
static pthread_mutex_t taken_lock = PTHREAD_MUTEX_INITIALIZER;

static void* acquire_eight(void* unused) {
  (void)unused;
  for (int i = 0; i < 8; ++i) {
    MpFlutterAudioCallback callback = NULL;
    const int slot = MpFlutterAudioStreamAcquire(post, 7, &callback);
    assert(slot >= 0 && slot < MP_FLUTTER_AUDIO_STREAM_SLOTS && callback);
    pthread_mutex_lock(&taken_lock);
    ++taken[slot];
    pthread_mutex_unlock(&taken_lock);
  }
  return NULL;
}

static void* release_eight(void* first) {
  for (int slot = *(int*)first; slot < *(int*)first + 8; ++slot) {
    MpFlutterAudioStreamRelease(slot);
  }
  return NULL;
}

int main(void) {
  // The views and messages have the layouts of Google's and the Dart VM's
  // structs on 64-bit targets.
  assert(sizeof(MpFlutterCategoryView) == 24 && sizeof(MpFlutterClassificationsView) == 24);
  assert(sizeof(MpFlutterClassificationResultView) == 32 && sizeof(MpFlutterAudioResultView) == 16);
  assert(sizeof(MpFlutterDartMessage) == 48 && sizeof(MpFlutterAudioEvent) == 40);

  MpFlutterAudioCallback callback = (MpFlutterAudioCallback)1;
  assert(MpFlutterAudioStreamAcquire(NULL, 1, &callback) == -1 && !callback);
  assert(MpFlutterAudioStreamAcquire(post, 1, NULL) == -1);

  // A result copied on another thread, with every string and score kept,
  // posted to the slot's port.
  const int slot = MpFlutterAudioStreamAcquire(post, 42, &callback);
  assert(slot >= 0 && callback);
  Delivery delivery = {callback};
  pthread_t thread;
  assert(pthread_create(&thread, NULL, deliver, &delivery) == 0);
  assert(pthread_join(thread, NULL) == 0);
  assert(last_port == 42);
  assert(received && received->status == 0 && received->copy_error == 0);
  assert(received->timestamp_ms == 9223372036854775LL && received->has_timestamp_ms);
  assert(received->heads_count == 1 && received->heads[0].head_index == 0);
  assert(strcmp(received->heads[0].head_name, "scores") == 0);
  assert(received->heads[0].categories_count == 2);
  assert(received->heads[0].categories[0].index == 0);
  assert(received->heads[0].categories[0].score == 0.91796875f);
  assert(strcmp(received->heads[0].categories[0].category_name, "Speech") == 0);
  assert(!received->heads[0].categories[0].display_name);
  assert(received->heads[0].categories[1].index == 132);
  assert(strcmp(received->heads[0].categories[1].category_name, "Música") == 0);
  assert(strcmp(received->heads[0].categories[1].display_name, "Música") == 0);
  release();

  // A failure carries Google's status and no result.
  callback(3, NULL);
  assert(received && received->status == 3 && received->copy_error == 0 && !received->heads);
  release();
  // A success without exactly one result is an invalid payload.
  callback(0, NULL);
  assert(received && received->copy_error == 2);
  release();
  MpFlutterClassificationResultView empty = {NULL, 0, 975, true};
  const MpFlutterAudioResultView two = {&empty, 2};
  callback(0, &two);
  assert(received && received->copy_error == 2);
  release();
  // A result without heads is valid; heads or categories counted but absent
  // are not.
  const MpFlutterAudioResultView one = {&empty, 1};
  callback(0, &one);
  assert(received && received->copy_error == 0 && received->heads_count == 0);
  assert(received->timestamp_ms == 975);
  release();
  empty.classifications_count = 1;
  callback(0, &one);
  assert(received && received->copy_error == 2);
  release();
  const MpFlutterClassificationsView missing = {NULL, 3, 0, NULL};
  const MpFlutterClassificationResultView counted = {&missing, 1, 0, true};
  const MpFlutterAudioResultView invalid = {&counted, 1};
  callback(0, &invalid);
  assert(received && received->copy_error == 2);
  release();

  // A port that refuses, as a gone isolate's does: the copy is freed here,
  // which AddressSanitizer's leak check sees on Linux.
  refusing = true;
  assert(pthread_create(&thread, NULL, deliver, &delivery) == 0);
  assert(pthread_join(thread, NULL) == 0);
  MpFlutterAudioStreamEnd(slot);
  assert(!received && !ended);
  refusing = false;

  // The end follows the results to the same port.
  MpFlutterAudioStreamEnd(slot);
  assert(ended && !received);
  ended = false;

  // A freed slot ignores Google's callback and frees its copy.
  MpFlutterAudioStreamRelease(slot);
  assert(pthread_create(&thread, NULL, deliver, &delivery) == 0);
  assert(pthread_join(thread, NULL) == 0);
  MpFlutterAudioStreamEnd(slot);
  assert(!received && !ended);
  MpFlutterAudioStreamRelease(-1);
  MpFlutterAudioStreamEnd(MP_FLUTTER_AUDIO_STREAM_SLOTS);

  // Eight threads take all 64 slots at once, each exactly once; the 65th is
  // refused; slots freed from several threads can be taken again.
  pthread_t threads[8];
  for (int i = 0; i < 8; ++i) {
    assert(pthread_create(&threads[i], NULL, acquire_eight, NULL) == 0);
  }
  for (int i = 0; i < 8; ++i) assert(pthread_join(threads[i], NULL) == 0);
  for (int i = 0; i < MP_FLUTTER_AUDIO_STREAM_SLOTS; ++i) assert(taken[i] == 1);
  callback = (MpFlutterAudioCallback)1;
  assert(MpFlutterAudioStreamAcquire(post, 9, &callback) == -1 && !callback);
  int firsts[8];
  for (int i = 0; i < 8; ++i) {
    firsts[i] = 8 * i;
    assert(pthread_create(&threads[i], NULL, release_eight, &firsts[i]) == 0);
  }
  for (int i = 0; i < 8; ++i) assert(pthread_join(threads[i], NULL) == 0);
  for (int i = 0; i < MP_FLUTTER_AUDIO_STREAM_SLOTS; ++i) {
    assert(MpFlutterAudioStreamAcquire(post, 9, &callback) == i && callback);
  }
  for (int i = 0; i < MP_FLUTTER_AUDIO_STREAM_SLOTS; ++i) MpFlutterAudioStreamRelease(i);
  assert(deliveries == 7);
  MpFlutterAudioEventFree(NULL);
  return 0;
}
