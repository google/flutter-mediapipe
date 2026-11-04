"""Capture Google's Audio Classifier outputs for the test clips and streams.

Runs the official Python API from the checksum-pinned wheel for this host, so
the Dart suite on each desktop CI runner compares against Google's own library
on that runner. Never derive expected values from the Dart implementation.

One run writes two references: each clip in clips mode, and the clips fed as
blocks in audio stream mode.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import sys
import time
import wave

PACKAGE = Path(__file__).resolve().parents[1]
FIXTURES = PACKAGE / 'test/fixtures'
CLIPS = ['speech_16000_hz_mono.wav', 'speech_48000_hz_mono.wav', 'two_heads_16000_hz_mono.wav']
sys.path.insert(0, str(PACKAGE.parent / 'mediapipe-core/tool'))
from official_wheels import host_runtime  # noqa: E402
from model_pins import model_sha256  # noqa: E402
from tool_helpers import reference_json  # noqa: E402
MODEL_SHA256 = model_sha256('yamnet.tflite')
HOST_NAMES = {'Darwin': 'macOS arm64', 'Linux': 'Linux x64', 'Windows': 'Windows x64'}

# YAMNet's input, from its metadata: windows of 15,600 mono samples at 16 kHz.
MODEL_WINDOW, MODEL_RATE = 15600, 16000

# Each stream case: the clip, how many of its frames (None for all), how many
# channels the mono clip is copied to, the frames per block (None for one
# block) and the first block's timestamp. A block is stamped with its first
# frame's time, first_timestamp_ms + frames_sent * 1000 // rate, as the
# gallery's microphone mode stamps its blocks.
STREAM_CASES = {
    'speech-100ms': ('speech_16000_hz_mono.wav', None, 1, 1600, 0),
    'speech-odd': ('speech_16000_hz_mono.wav', None, 1, 777, 5000),
    'speech-one-block': ('speech_16000_hz_mono.wav', None, 1, None, 0),
    'speech-48k': ('speech_48000_hz_mono.wav', None, 1, 4801, 0),
    'speech-stereo': ('speech_16000_hz_mono.wav', None, 2, 1600, 0),
    'two-heads': ('two_heads_16000_hz_mono.wav', None, 1, 1600, 0),
    'lone-half-second': ('speech_16000_hz_mono.wav', 8000, 1, None, 0),
}


def read_clip(clip):
    """A fixture's samples, as floats in -1 to 1, and its rate."""
    import numpy as np
    with wave.open(str(FIXTURES / clip), 'rb') as source:
        assert source.getsampwidth() == 2 and source.getnchannels() == 1
        rate = source.getframerate()
        frames = source.readframes(source.getnframes())
    return np.frombuffer(frames, dtype='<i2').astype(np.float32) / 32768, rate


def top(result):
    """The first head's categories with their scores to six places."""
    return [[category.category_name, round(category.score, 6)]
            for category in result.classifications[0].categories]


def stream_case(model, case):
    """Google's results for one stream case, each marked with whether it
    arrived during the close, which flushes the tail, or before it.
    """
    import numpy as np
    import mediapipe as mp
    from mediapipe.tasks.python import audio
    from mediapipe.tasks.python.components.containers import audio_data

    clip, count, channels, block, first = case
    samples, rate = read_clip(clip)
    if count is not None:
        samples = samples[:count]
    frames = len(samples)
    if channels > 1:
        samples = np.repeat(samples[:, None], channels, axis=1)
    block = block or frames
    received = []
    options = audio.AudioClassifierOptions(
        base_options=mp.tasks.BaseOptions(model_asset_path=str(model)), max_results=3,
        running_mode=audio.RunningMode.AUDIO_STREAM,
        result_callback=lambda result, timestamp_ms: received.append(result))
    # Every full window has arrived before the close, so that what arrives
    # during the close is what the close flushed.
    full = frames * MODEL_RATE // rate // MODEL_WINDOW
    classifier = audio.AudioClassifier.create_from_options(options)
    try:
        for start in range(0, frames, block):
            classifier.classify_async(
                audio_data.AudioData.create_from_array(samples[start:start + block], rate),
                first + start * 1000 // rate)
        deadline = time.monotonic() + 60
        while len(received) < full and time.monotonic() < deadline:
            time.sleep(0.01)
        time.sleep(0.5)
        streaming = len(received)
    finally:
        # Closes Google's task, which flushes the tail and waits for the
        # graph, then joins the thread that delivers the results.
        classifier.close()
    return {
        'clip': clip,
        'frames': frames,
        'rate': rate,
        'channels': channels,
        'block_frames': block,
        'first_timestamp_ms': first,
        'results': [
            {'timestamp_ms': result.timestamp_ms, 'top': top(result),
             'during_close': i >= streaming}
            for i, result in enumerate(received)],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--python-package-root', type=Path, help='Extracted official wheel')
    parser.add_argument('--output', type=Path, default=FIXTURES / 'official_reference.json')
    parser.add_argument('--stream-output', type=Path,
                        default=FIXTURES / 'official_stream_reference.json')
    args = parser.parse_args()
    if args.python_package_root:
        sys.path.insert(0, str(args.python_package_root.resolve()))
    os.environ.setdefault('MPLCONFIGDIR', str(PACKAGE / 'build/matplotlib'))
    import mediapipe as mp
    from mediapipe.tasks.python import audio
    from mediapipe.tasks.python.components.containers import audio_data

    runtime = host_runtime()
    name, version = HOST_NAMES[platform.system()], runtime['version']
    assert mp.__version__ == version, mp.__version__
    library = Path(mp.__file__).parent / 'tasks/c' / runtime['library']
    assert hashlib.sha256(library.read_bytes()).hexdigest() == runtime['library_sha256']
    model = PACKAGE / 'models/yamnet.tflite'
    assert hashlib.sha256(model.read_bytes()).hexdigest() == MODEL_SHA256

    report = {
        'runtime': f'mediapipe=={version}',
        'source': f'official Python AudioClassifier, {name} wheel, max_results 3',
        'model': model.name,
        'model_sha256': MODEL_SHA256,
        'decode': '16-bit PCM WAV, samples / 32768',
        'clips': {},
    }
    options = audio.AudioClassifierOptions(
        base_options=mp.tasks.BaseOptions(model_asset_path=str(model)), max_results=3)
    with audio.AudioClassifier.create_from_options(options) as classifier:
        for clip in CLIPS:
            samples, rate = read_clip(clip)
            results = classifier.classify(audio_data.AudioData.create_from_array(samples, rate))
            report['clips'][clip] = [
                {'timestamp_ms': result.timestamp_ms, 'top': top(result)}
                for result in results]
            print(clip, len(results), flush=True)
    args.output.resolve().parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(reference_json(report) + '\n', encoding='utf-8')

    stream = {
        'runtime': f'mediapipe=={version}',
        'source': f'official Python AudioClassifier in AUDIO_STREAM mode, {name} wheel, '
                  'max_results 3',
        'model': model.name,
        'model_sha256': MODEL_SHA256,
        'decode': '16-bit PCM WAV, samples / 32768, copied to every channel',
        'timestamps': 'each block at first_timestamp_ms + frames_sent * 1000 // rate',
        'cases': {},
    }
    for case, spec in STREAM_CASES.items():
        stream['cases'][case] = stream_case(model, spec)
        results = stream['cases'][case]['results']
        print(case, len(results), 'results,',
              sum(result['during_close'] for result in results), 'during the close', flush=True)
    args.stream_output.resolve().parent.mkdir(parents=True, exist_ok=True)
    args.stream_output.write_text(reference_json(stream) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
