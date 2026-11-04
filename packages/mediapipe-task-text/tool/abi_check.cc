// The C ABI the Proofreader and Summarizer bindings and the stream bridge
// assume, checked against the vendored headers in
// mediapipe_core/native/include. `make test_text_stream_bridge` compiles it.
#include <cstddef>

#include "../native/text_stream_bridge.h"
#include "text/text_proofreader/text_proofreader.h"
#include "text/text_summarizer/text_summarizer.h"

static_assert(sizeof(MpStatus) == 4);
static_assert(sizeof(MpCorrectionType) == 4);
static_assert(sizeof(MpTextSummarizerMode) == 4);
static_assert(sizeof(MpBaseOptions) == 72);
static_assert(sizeof(MpTextProofreaderOptions) == 96);
static_assert(sizeof(MpTextProofreaderResult) == 24);
static_assert(sizeof(MpTextSummarizerOptions) == 96);
static_assert(sizeof(MpTextSummarizerResult) == 8);

// The bridge reads Google's callback results through its own views.
#define SAME_FIELD(view, google, view_field, google_field)        \
  static_assert(offsetof(view, view_field) ==                     \
                offsetof(google, google_field));                  \
  static_assert(sizeof(view::view_field) == sizeof(google::google_field))

static_assert(sizeof(MpFlutterCorrectionView) == sizeof(MpCorrection));
SAME_FIELD(MpFlutterCorrectionView, MpCorrection, type, type);
SAME_FIELD(MpFlutterCorrectionView, MpCorrection, text, text);

static_assert(sizeof(MpFlutterProofreaderStreamView) ==
              sizeof(MpTextProofreaderStreamResult));
SAME_FIELD(MpFlutterProofreaderStreamView, MpTextProofreaderStreamResult,
           chunk, chunk);
SAME_FIELD(MpFlutterProofreaderStreamView, MpTextProofreaderStreamResult,
           corrections_count, corrections_count);
SAME_FIELD(MpFlutterProofreaderStreamView, MpTextProofreaderStreamResult,
           corrections, corrections);
SAME_FIELD(MpFlutterProofreaderStreamView, MpTextProofreaderStreamResult,
           done, done);

static_assert(sizeof(MpFlutterSummarizerStreamView) ==
              sizeof(MpTextSummarizerStreamResult));
SAME_FIELD(MpFlutterSummarizerStreamView, MpTextSummarizerStreamResult, chunk,
           chunk);
SAME_FIELD(MpFlutterSummarizerStreamView, MpTextSummarizerStreamResult, done,
           done);
