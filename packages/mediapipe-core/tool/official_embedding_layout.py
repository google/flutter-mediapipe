"""Google's Python reads MpEmbeddingResult with the wrong layout; fix that.

Shared by the text and vision reference generators, which run inside the
official wheel.
"""
import ctypes
import importlib

# Each family's embedder module, rebuilt once the struct is right.
_EMBEDDERS = {'text': 'text.text_embedder', 'vision': 'vision.image_embedder'}


def use_header_embedding_layout(family):
    """Makes Google's Python read embedding results with the C header's layout
    for `family` (`text` or `vision`).

    The wheel's ctypes declare MpEmbeddingResult as 24 bytes with the timestamp
    flag first. The library writes the header's 32 bytes (timestamp, then the
    flag), so Python overruns its allocation (under glibc this surfaced as
    "corrupted size vs. prev_size" on the GPU) and reads the flag from padding,
    reporting no timestamp.
    """
    from mediapipe.tasks.python.components.containers import embedding_result_c as module
    old = module.MpEmbeddingResultC
    # A future wheel that fixes its ctypes makes this unnecessary; fail loudly.
    assert [name for name, _ in old._fields_] == [
        'embeddings', 'embeddings_count', 'has_timestamp_ms', 'timestamp_ms'], old._fields_

    class MpEmbeddingResultC(ctypes.Structure):
        _fields_ = [('embeddings', ctypes.POINTER(module.MpEmbeddingC)),
                    ('embeddings_count', ctypes.c_uint32),
                    ('timestamp_ms', ctypes.c_int64),
                    ('has_timestamp_ms', ctypes.c_bool)]
    module.MpEmbeddingResultC = MpEmbeddingResultC
    # `import mediapipe` already bound the old struct into the embedder's C
    # signatures; rebuild them, and the family namespace that re-exports them.
    embedder = importlib.reload(importlib.import_module(
        'mediapipe.tasks.python.' + _EMBEDDERS[family]))
    namespace = importlib.import_module('mediapipe.tasks.python.' + family)
    for name in ('TextEmbedder', 'TextEmbedderOptions', 'ImageEmbedder', 'ImageEmbedderOptions'):
        if hasattr(embedder, name) and hasattr(namespace, name):
            setattr(namespace, name, getattr(embedder, name))
