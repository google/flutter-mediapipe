// Exercise the foreign-thread ownership boundary under AddressSanitizer.
#include "text_stream_bridge.h"
#include <assert.h>
#include <pthread.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

static MpFlutterTextEvent* received;
// Whether the port takes messages; a closed one, as after a hot restart,
// refuses them without taking the copy.
static bool open_port = true;
static int posts;

static bool post(int64_t port, MpFlutterDartMessage* message) {
  assert(port == 42 && message->type == kMpFlutterDartInt64);
  ++posts;
  if (!open_port) return false;
  assert(!received && message->value.as_int64 > 0);
  received = (MpFlutterTextEvent*)(intptr_t)message->value.as_int64;
  return true;
}

static void* deliver(void* context) {
  char* text = strdup("café ☕");
  char* edit = strdup("received");
  MpFlutterCorrectionView corrections[] = {{1, edit}, {0, NULL}};
  MpFlutterProofreaderStreamView view = {text, 2, corrections, false};
  MpFlutterProofreaderCallback(context, &view, NULL);
  // Google may reuse/free these immediately on return. The receiver runs later.
  memset(text, 'x', strlen(text));
  memset(edit, 'x', strlen(edit));
  free(text);
  free(edit);
  memset(corrections, 0, sizeof(corrections));
  return NULL;
}

static void release(void) {
  MpFlutterTextEventFree(received);
  received = NULL;
}

static void* deliver_summary(void* context) {
  char* text = strdup("* María opened a café.\n");
  const MpFlutterSummarizerStreamView result = {text, false};
  MpFlutterSummarizerCallback(context, &result, NULL);
  memset(text, 'x', strlen(text));
  free(text);
  return NULL;
}

int main(void) {
  // Dart_CObject's size on the 64-bit targets the bridge is built for.
  assert(sizeof(MpFlutterDartMessage) == 48);
  assert(!MpFlutterTextStreamCreate(NULL, 42));
  MpFlutterTextStreamContext* context = MpFlutterTextStreamCreate(post, 42);
  assert(context);
  pthread_t thread;
  assert(pthread_create(&thread, NULL, deliver, context) == 0);
  assert(pthread_join(thread, NULL) == 0);
  assert(received && !received->terminal && received->copy_error == 0);
  assert(strcmp(received->text, "café ☕") == 0);
  assert(received->corrections_count == 2);
  assert(received->corrections[0].type == 1);
  assert(strcmp(received->corrections[0].text, "received") == 0);
  assert(received->corrections[1].text == NULL);
  release();

  MpFlutterProofreaderStreamView terminal = {NULL, 0, NULL, true};
  MpFlutterProofreaderCallback(context, &terminal, NULL);
  assert(received->terminal && received->copy_error == 0 && !received->text);
  release();
  char error[] = "native failure";
  MpFlutterProofreaderCallback(context, NULL, error);
  memset(error, 'x', sizeof(error));
  assert(received->terminal && strcmp(received->error, "native failure") == 0);
  release();
  MpFlutterProofreaderCallback(context, NULL, NULL);
  assert(received->terminal && received->copy_error == 2);
  release();
  terminal.corrections_count = 1;
  MpFlutterProofreaderCallback(context, &terminal, NULL);
  assert(received->terminal && received->copy_error == 2);
  release();
  terminal.corrections_count = -1;
  MpFlutterProofreaderCallback(context, &terminal, NULL);
  assert(received->terminal && received->copy_error == 2);
  release();
  assert(pthread_create(&thread, NULL, deliver_summary, context) == 0);
  assert(pthread_join(thread, NULL) == 0);
  assert(received && !received->terminal && received->copy_error == 0);
  assert(strcmp(received->text, "* María opened a café.\n") == 0);
  assert(received->corrections_count == 0 && !received->corrections);
  release();
  const MpFlutterSummarizerStreamView summary_done = {NULL, true};
  MpFlutterSummarizerCallback(context, &summary_done, NULL);
  assert(received->terminal && received->copy_error == 0 && !received->text);
  release();
  MpFlutterSummarizerCallback(context, NULL, "summary error");
  assert(received->terminal && strcmp(received->error, "summary error") == 0);
  release();
  MpFlutterSummarizerCallback(context, NULL, NULL);
  assert(received->terminal && received->copy_error == 2);
  release();
  // A closed port: every callback still copies and posts, and the refused
  // copy is the bridge's to free, which AddressSanitizer checks.
  open_port = false;
  posts = 0;
  assert(pthread_create(&thread, NULL, deliver, context) == 0);
  assert(pthread_join(thread, NULL) == 0);
  MpFlutterSummarizerCallback(context, &summary_done, NULL);
  MpFlutterProofreaderCallback(context, NULL, "late failure");
  assert(posts == 3 && !received);
  MpFlutterTextStreamFree(context);
  MpFlutterTextEventFree(NULL);
  return 0;
}
