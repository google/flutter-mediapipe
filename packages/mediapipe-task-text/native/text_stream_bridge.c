// Copyright 2026. Licensed under Apache-2.0 (see the repository LICENSE).
#include "text_stream_bridge.h"

#include <stddef.h>
#include <stdlib.h>
#include <string.h>

struct MpFlutterTextStreamContext {
  MpFlutterPost post;
  int64_t port;
};

MpFlutterTextStreamContext* MpFlutterTextStreamCreate(MpFlutterPost post,
                                                      int64_t port) {
  if (!post) return NULL;
  MpFlutterTextStreamContext* context = malloc(sizeof(*context));
  if (context) {
    context->post = post;
    context->port = port;
  }
  return context;
}

void MpFlutterTextStreamFree(MpFlutterTextStreamContext* context) {
  free(context);
}

void MpFlutterTextEventFree(MpFlutterTextEvent* event) {
  if (!event) return;
  free(event->text);
  free(event->error);
  if (event->corrections) {
    for (int i = 0; i < event->corrections_count; ++i) {
      free((void*)event->corrections[i].text);
    }
  }
  free(event->corrections);
  free(event);
}

static char* copy_string(const char* value, MpFlutterTextEvent* event) {
  if (!value) return NULL;
  char* copy = strdup(value);
  if (!copy) event->copy_error = 1;
  return copy;
}

void MpFlutterProofreaderCallback(void* userdata,
                                 const MpFlutterProofreaderStreamView* result,
                                 const char* error) {
  // Read the context before posting. After a terminal post this callback
  // never touches context or event again: the worker may free them.
  const MpFlutterTextStreamContext* context = userdata;
  const MpFlutterPost post = context->post;
  const int64_t port = context->port;
  const bool terminal = error != NULL || result == NULL || result->done;
  MpFlutterTextEvent* event = calloc(1, sizeof(*event));
  if (event) {
    event->terminal = terminal;
    event->error = copy_string(error, event);
    if (!error && !result) event->copy_error = 2;
    if (result && !error) {
      event->text = copy_string(result->chunk, event);
      if (result->corrections_count < 0 ||
          (result->corrections_count > 0 && !result->corrections)) {
        event->copy_error = 2;
      } else if (result->corrections_count > 0) {
        event->corrections = calloc((size_t)result->corrections_count,
                                    sizeof(*event->corrections));
        if (!event->corrections) {
          event->copy_error = 1;
        } else {
          event->corrections_count = result->corrections_count;
          for (int i = 0; i < result->corrections_count; ++i) {
            event->corrections[i].type = result->corrections[i].type;
            event->corrections[i].text = copy_string(result->corrections[i].text, event);
          }
        }
      }
    }
  }
  // The worker's port takes the copy's address; even allocation failure
  // tells it whether this was the last event, so it can drain the native
  // request before freeing the context. A port is used rather than a Dart
  // callback because Google may call back after the worker isolate is gone,
  // after a hot restart for one: the closed port refuses the message, and the
  // copy is then this bridge's to free, where calling a deleted callback
  // would abort the VM.
  MpFlutterDartMessage message;
  memset(&message, 0, sizeof(message));
  message.type = kMpFlutterDartInt64;
  message.value.as_int64 =
      event ? (int64_t)(intptr_t)event
            : (terminal ? kMpFlutterTextLostTerminalEvent : kMpFlutterTextLostEvent);
  if (!post(port, &message)) MpFlutterTextEventFree(event);
}

void MpFlutterSummarizerCallback(void* userdata,
                                const MpFlutterSummarizerStreamView* result,
                                const char* error) {
  // Map Google's simpler callback view onto the same owned event protocol.
  // This stack view is copied synchronously before this function returns.
  if (result) {
    const MpFlutterProofreaderStreamView view = {
        result->chunk, 0, NULL, result->done};
    MpFlutterProofreaderCallback(userdata, &view, error);
  } else {
    MpFlutterProofreaderCallback(userdata, NULL, error);
  }
}
