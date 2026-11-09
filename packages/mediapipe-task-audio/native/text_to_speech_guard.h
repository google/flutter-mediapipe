// Copyright 2026. Licensed under Apache-2.0 (see the repository LICENSE).
#ifndef MEDIAPIPE_FLUTTER_TEXT_TO_SPEECH_GUARD_H_
#define MEDIAPIPE_FLUTTER_TEXT_TO_SPEECH_GUARD_H_

#include <stdbool.h>
#include <stdint.h>

#include "audio_stream_bridge.h"

// Lets the calling isolate cancel Google's Text to Speech while its worker
// isolate, which owns the handles, runs a request on them. The worker
// publishes a handle while a request uses it and withdraws it before Google
// frees it; the caller only reaches Google through the guard, with its lock,
// so it never touches a handle Google has closed.
//
// Requests carry increasing numbers from the caller. A cancel covers every
// request numbered up to the one it names, whether running or waiting.
typedef struct MpFlutterTtsGuard MpFlutterTtsGuard;

// MpTextToSpeechCancel and MpTextToSpeechStreamCancel, which live in Google's
// library rather than this one.
typedef void (*MpFlutterTtsCancel)(void* handle);

// Null when out of memory.
MP_FLUTTER_EXPORT MpFlutterTtsGuard* MpFlutterTtsGuardNew(
    MpFlutterTtsCancel cancel, MpFlutterTtsCancel stream_cancel);

// Once nothing calls the guard any more: after the worker has exited.
MP_FLUTTER_EXPORT void MpFlutterTtsGuardFree(MpFlutterTtsGuard* guard);

// The worker starts [request] on [tts]: false, publishing nothing, when a
// cancel already covers it.
MP_FLUTTER_EXPORT bool MpFlutterTtsGuardBegin(MpFlutterTtsGuard* guard, int64_t request,
                                             void* tts);

// The worker publishes the running request's stream, cancelling it at once if
// a cancel came while it was starting, or withdraws it with null before
// closing it.
MP_FLUTTER_EXPORT void MpFlutterTtsGuardSetStream(MpFlutterTtsGuard* guard, void* stream);

// The worker ends the running request, withdrawing its handles: true when a
// cancel covered it.
MP_FLUTTER_EXPORT bool MpFlutterTtsGuardEnd(MpFlutterTtsGuard* guard);

// The caller cancels every request numbered up to [through].
MP_FLUTTER_EXPORT void MpFlutterTtsGuardCancel(MpFlutterTtsGuard* guard, int64_t through);

// The caller cancels the stream of [request] if it is the one running.
MP_FLUTTER_EXPORT void MpFlutterTtsGuardCancelStream(MpFlutterTtsGuard* guard,
                                                     int64_t request);

#endif
