/* Copyright 2023 The MediaPipe Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
==============================================================================*/

// AUTO GENERATED FILE, DO NOT EDIT.
//
// Generated by `package:ffigen`.
// ignore_for_file: type=lint
import 'dart:ffi' as ffi;

@ffi.Native<ffi.Void Function(ffi.Pointer<LlmResponseContext>)>(
    symbol: 'LlmInferenceEngine_CloseResponseContext')
external void LlmInferenceEngine_CloseResponseContext(
  ffi.Pointer<LlmResponseContext> response_context,
);

@ffi.Native<
        ffi.Pointer<LlmInferenceEngine_Session> Function(
            ffi.Pointer<LlmSessionConfig>)>(
    symbol: 'LlmInferenceEngine_CreateSession')
external ffi.Pointer<LlmInferenceEngine_Session>
    LlmInferenceEngine_CreateSession(
  ffi.Pointer<LlmSessionConfig> session_config,
);

@ffi.Native<ffi.Void Function(ffi.Pointer<LlmInferenceEngine_Session>)>(
    symbol: 'LlmInferenceEngine_Session_Delete')
external void LlmInferenceEngine_Session_Delete(
  ffi.Pointer<LlmInferenceEngine_Session> session,
);

@ffi.Native<
        LlmResponseContext Function(
            ffi.Pointer<LlmInferenceEngine_Session>, ffi.Pointer<ffi.Char>)>(
    symbol: 'LlmInferenceEngine_Session_PredictSync')
external LlmResponseContext LlmInferenceEngine_Session_PredictSync(
  ffi.Pointer<LlmInferenceEngine_Session> session,
  ffi.Pointer<ffi.Char> input,
);

@ffi.Native<
        ffi.Void Function(
            ffi.Pointer<LlmInferenceEngine_Session>,
            ffi.Pointer<ffi.Void>,
            ffi.Pointer<ffi.Char>,
            ffi.Pointer<
                ffi.NativeFunction<
                    ffi.Void Function(ffi.Pointer<ffi.Void> callback_context,
                        LlmResponseContext response_context)>>)>(
    symbol: 'LlmInferenceEngine_Session_PredictAsync')
external void LlmInferenceEngine_Session_PredictAsync(
  ffi.Pointer<LlmInferenceEngine_Session> session,
  ffi.Pointer<ffi.Void> callback_context,
  ffi.Pointer<ffi.Char> input,
  ffi.Pointer<
          ffi.NativeFunction<
              ffi.Void Function(ffi.Pointer<ffi.Void> callback_context,
                  LlmResponseContext response_context)>>
      callback,
);

@ffi.Native<
        ffi.Int Function(ffi.Pointer<LlmInferenceEngine_Session>,
            ffi.Pointer<ffi.Char>, ffi.Pointer<ffi.Pointer<ffi.Char>>)>(
    symbol: 'LlmInferenceEngine_Session_SizeInTokens')
external int LlmInferenceEngine_Session_SizeInTokens(
  ffi.Pointer<LlmInferenceEngine_Session> session,
  ffi.Pointer<ffi.Char> input,
  ffi.Pointer<ffi.Pointer<ffi.Char>> error_msg,
);

final class __mbstate_t extends ffi.Union {
  @ffi.Array.multi([128])
  external ffi.Array<ffi.Char> __mbstate8;

  @ffi.LongLong()
  external int _mbstateL;
}

final class __darwin_pthread_handler_rec extends ffi.Struct {
  external ffi
      .Pointer<ffi.NativeFunction<ffi.Void Function(ffi.Pointer<ffi.Void>)>>
      __routine;

  external ffi.Pointer<ffi.Void> __arg;

  external ffi.Pointer<__darwin_pthread_handler_rec> __next;
}

final class _opaque_pthread_attr_t extends ffi.Struct {
  @ffi.Long()
  external int __sig;

  @ffi.Array.multi([56])
  external ffi.Array<ffi.Char> __opaque;
}

final class _opaque_pthread_cond_t extends ffi.Struct {
  @ffi.Long()
  external int __sig;

  @ffi.Array.multi([40])
  external ffi.Array<ffi.Char> __opaque;
}

final class _opaque_pthread_condattr_t extends ffi.Struct {
  @ffi.Long()
  external int __sig;

  @ffi.Array.multi([8])
  external ffi.Array<ffi.Char> __opaque;
}

final class _opaque_pthread_mutex_t extends ffi.Struct {
  @ffi.Long()
  external int __sig;

  @ffi.Array.multi([56])
  external ffi.Array<ffi.Char> __opaque;
}

final class _opaque_pthread_mutexattr_t extends ffi.Struct {
  @ffi.Long()
  external int __sig;

  @ffi.Array.multi([8])
  external ffi.Array<ffi.Char> __opaque;
}

final class _opaque_pthread_once_t extends ffi.Struct {
  @ffi.Long()
  external int __sig;

  @ffi.Array.multi([8])
  external ffi.Array<ffi.Char> __opaque;
}

final class _opaque_pthread_rwlock_t extends ffi.Struct {
  @ffi.Long()
  external int __sig;

  @ffi.Array.multi([192])
  external ffi.Array<ffi.Char> __opaque;
}

final class _opaque_pthread_rwlockattr_t extends ffi.Struct {
  @ffi.Long()
  external int __sig;

  @ffi.Array.multi([16])
  external ffi.Array<ffi.Char> __opaque;
}

final class _opaque_pthread_t extends ffi.Struct {
  @ffi.Long()
  external int __sig;

  external ffi.Pointer<__darwin_pthread_handler_rec> __cleanup_stack;

  @ffi.Array.multi([8176])
  external ffi.Array<ffi.Char> __opaque;
}

final class LlmSessionConfig extends ffi.Struct {
  external ffi.Pointer<ffi.Char> model_path;

  external ffi.Pointer<ffi.Char> cache_dir;

  @ffi.Size()
  external int sequence_batch_size;

  @ffi.Size()
  external int num_decode_steps_per_sync;

  @ffi.Size()
  external int max_tokens;

  @ffi.Size()
  external int topk;

  @ffi.Float()
  external double topp;

  @ffi.Float()
  external double temperature;

  @ffi.Size()
  external int random_seed;
}

final class LlmResponseContext extends ffi.Struct {
  external ffi.Pointer<ffi.Pointer<ffi.Char>> response_array;

  @ffi.Int()
  external int response_count;

  @ffi.Bool()
  external bool done;
}

typedef LlmInferenceEngine_Session = ffi.Void;

const int true1 = 1;

const int false1 = 0;
